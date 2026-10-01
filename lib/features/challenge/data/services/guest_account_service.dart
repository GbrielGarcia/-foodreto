import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/firebase/firestore_collections.dart';
import '../../../../firebase_options.dart';
import '../../../auth/data/repositories/firebase_auth_repository.dart';
import '../../../auth/domain/failures/auth_failure.dart';
import '../../../profile/data/models/user_profile_dto.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/failures/profile_failure.dart';
import '../../../profile/domain/value_objects/username.dart';

/// Crea cuenta + perfil de invitado sin cerrar la sesion del host.
///
/// Usa un [FirebaseApp] secundario: Auth/Firestore de ese app llevan el token
/// del invitado, mientras el app default sigue con el host.
class GuestAccountService {
  static const _appName = 'foodreto-guest';

  Future<Result<UserProfile>> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final name = displayName.trim();
    final mail = email.trim();
    if (name.isEmpty || mail.isEmpty || password.length < 6) {
      return const Result.failure(AuthFailure.invalidCredentials());
    }

    try {
      final app = await _guestApp();
      final auth = FirebaseAuth.instanceFor(app: app);
      final db = FirebaseFirestore.instanceFor(app: app);

      final credential = await auth.createUserWithEmailAndPassword(
        email: mail,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return const Result.failure(UnexpectedFailure());
      }
      await user.updateDisplayName(name);

      final username = await _uniqueUsername(
        db: db,
        preferred: Username.suggest(displayName: name, email: mail),
      );
      final profile = NewProfile(
        uid: user.uid,
        username: username,
        displayName: name,
        avatar: AvatarConfig.random(),
        email: mail,
      );

      await db.runTransaction((tx) async {
        final userRef =
            db.collection(FirestoreCollections.users).doc(profile.uid);
        final usernameRef =
            db.collection(FirestoreCollections.usernames).doc(username);
        final reservation = await tx.get(usernameRef);
        if (reservation.exists &&
            reservation.data()?['uid'] != profile.uid) {
          throw const _UsernameTaken();
        }
        if (!reservation.exists) {
          tx.set(usernameRef, {
            'uid': profile.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        tx.set(userRef, UserProfileDto.toCreateMap(profile));
        tx.set(
          userRef
              .collection(FirestoreCollections.userPrivate)
              .doc(FirestoreCollections.userPrivateAccountDoc),
          {
            'email': mail,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      });

      await auth.signOut();
      return Result.success(
        UserProfile(
          uid: profile.uid,
          username: profile.username,
          displayName: profile.displayName,
          avatar: profile.avatar,
        ),
      );
    } on FirebaseAuthException catch (e) {
      return Result.failure(mapFirebaseAuthCode(e.code));
    } on _UsernameTaken {
      return const Result.failure(ProfileFailure.usernameTaken());
    } catch (_) {
      return const Result.failure(UnexpectedFailure());
    }
  }

  Future<FirebaseApp> _guestApp() async {
    try {
      return Firebase.app(_appName);
    } on FirebaseException {
      return Firebase.initializeApp(
        name: _appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  Future<String> _uniqueUsername({
    required FirebaseFirestore db,
    required String preferred,
  }) async {
    var base = preferred;
    if (!Username.isValid(base)) {
      base = 'foodie${DateTime.now().millisecondsSinceEpoch % 100000}';
    }
    for (var i = 0; i < 12; i++) {
      final candidate = i == 0
          ? base
          : '${base.length > 14 ? base.substring(0, 14) : base}_$i';
      if (!Username.isValid(candidate)) continue;
      final snap = await db
          .collection(FirestoreCollections.usernames)
          .doc(candidate)
          .get();
      if (!snap.exists) return candidate;
    }
    return 'guest${DateTime.now().millisecondsSinceEpoch % 1000000}';
  }
}

class _UsernameTaken implements Exception {
  const _UsernameTaken();
}
