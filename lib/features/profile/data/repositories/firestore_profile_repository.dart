import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/firebase/firestore_collections.dart';
import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_statistics.dart';
import '../../domain/entities/username_availability.dart';
import '../../domain/failures/profile_failure.dart';
import '../../domain/repositories/profile_repository.dart';
import '../models/user_profile_dto.dart';

/// Perfil en `users/{uid}` + índice de unicidad `usernames/{username}`.
///
/// La unicidad no depende de "consultar y luego escribir": ambas escrituras
/// van en la misma transacción y `firestore.rules` exige que
/// `usernames/{username}.uid` y `users/{uid}.username` coincidan. Si dos
/// usuarios reservan el mismo nombre a la vez, Firestore reintenta la
/// transacción perdedora, que entonces ve el documento ya creado.
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection(FirestoreCollections.usernames);

  DocumentReference<Map<String, dynamic>> _account(String uid) => _users
      .doc(uid)
      .collection(FirestoreCollections.userPrivate)
      .doc(FirestoreCollections.userPrivateAccountDoc);

  @override
  Stream<UserProfile?> watchProfile(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((snapshot) => UserProfileDto.fromMap(uid, snapshot.data()));

  @override
  Future<Result<UsernameAvailability>> checkUsernameAvailability(
    String username, {
    String? currentUid,
  }) async {
    try {
      final snapshot = await _usernames.doc(username).get();
      if (!snapshot.exists) return const Result.success(UsernameAvailable());
      final owner = snapshot.data()?['uid'];
      return Result.success(
        owner != null && owner == currentUid
            ? const UsernameOwned()
            : const UsernameTaken(),
      );
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<UserProfile>> createProfile(NewProfile profile) async {
    final userRef = _users.doc(profile.uid);
    final usernameRef = _usernames.doc(profile.username);
    try {
      await _db.runTransaction((tx) async {
        final existing = await tx.get(userRef);
        if (UserProfileDto.fromMap(profile.uid, existing.data()) != null) {
          throw const _ProfileAlreadyExists();
        }
        final reservation = await tx.get(usernameRef);
        final owner = reservation.data()?['uid'];
        if (reservation.exists && owner != profile.uid) {
          throw const _UsernameTaken();
        }
        if (!reservation.exists) {
          tx.set(usernameRef, {
            'uid': profile.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        tx.set(userRef, UserProfileDto.toCreateMap(profile));
        if (profile.email != null) {
          tx.set(_account(profile.uid), {
            'email': profile.email!,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      return Result.success(
        UserProfile(
          uid: profile.uid,
          username: profile.username,
          displayName: profile.displayName,
          avatar: profile.avatar,
          bio: profile.bio,
        ),
      );
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<void>> updateProfile(String uid, ProfileChanges changes) async {
    final userRef = _users.doc(uid);
    try {
      await _db.runTransaction((tx) async {
        final snapshot = await tx.get(userRef);
        final current = UserProfileDto.fromMap(uid, snapshot.data());
        if (current == null) throw const _ProfileNotFound();

        final newUsername = changes.username;
        final usernameChanges =
            newUsername != null && newUsername != current.username;

        if (usernameChanges) {
          final newRef = _usernames.doc(newUsername);
          final reservation = await tx.get(newRef);
          if (reservation.exists && reservation.data()?['uid'] != uid) {
            throw const _UsernameTaken();
          }
          if (!reservation.exists) {
            tx.set(newRef, {
              'uid': uid,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          tx.delete(_usernames.doc(current.username));
        }

        final patch = UserProfileDto.toUpdateMap(
          ProfileChanges(
            username: usernameChanges ? newUsername : null,
            displayName: changes.displayName,
            bio: changes.bio,
            avatar: changes.avatar,
            visibility: changes.visibility,
          ),
        );
        patch['displayNameLower'] =
            (changes.displayName ?? current.displayName).toLowerCase();
        tx.update(userRef, patch);
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  static Failure _mapError(Object error) => switch (error) {
    _UsernameTaken() => const ProfileFailure.usernameTaken(),
    _ProfileAlreadyExists() => const ProfileFailure.alreadyExists(),
    _ProfileNotFound() => const ProfileFailure.notFound(),
    _ => mapFirestoreError(error),
  };
}

class FirestoreUserStatisticsRepository implements UserStatisticsRepository {
  FirestoreUserStatisticsRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<UserStatistics> watchStatistics(String uid) => _db
      .collection(FirestoreCollections.userStatistics)
      .doc(uid)
      .snapshots()
      .map((snapshot) => UserStatisticsDto.fromMap(snapshot.data()));
}

class _UsernameTaken implements Exception {
  const _UsernameTaken();
}

class _ProfileAlreadyExists implements Exception {
  const _ProfileAlreadyExists();
}

class _ProfileNotFound implements Exception {
  const _ProfileNotFound();
}
