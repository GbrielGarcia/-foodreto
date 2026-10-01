import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/google_id_token_source.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, {this._google, this._isWeb = kIsWeb});

  final FirebaseAuth _auth;
  final GoogleIdTokenSource? _google;
  final bool _isWeb;

  @override
  Stream<AuthUser?> authStateChanges() =>
      // userChanges() también emite al actualizar displayName tras el registro.
      _auth.userChanges().map(_toDomain);

  @override
  AuthUser? get currentUser => _toDomain(_auth.currentUser);

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _toDomain(credential.user)!;
    });
  }

  @override
  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _guard(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(displayName);
      await user.reload();
      return _toDomain(_auth.currentUser ?? user)!;
    });
  }

  @override
  bool get supportsGoogleSignIn => _isWeb || (_google?.isSupported ?? false);

  @override
  Future<Result<AuthUser>> signInWithGoogle() async {
    if (!supportsGoogleSignIn) {
      return const Result.failure(AuthFailure.googleUnavailable());
    }
    return _guard(() async {
      final UserCredential credential;
      if (_isWeb) {
        credential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final idToken = await _google!.requestIdToken();
        if (idToken == null) throw const _Cancelled();
        credential = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }
      return _toDomain(credential.user)!;
    });
  }

  @override
  Future<Result<void>> signOut() => _guard(() async {
    if (!_isWeb && _google != null) {
      // Si falla, no debe impedir cerrar la sesión de Firebase.
      try {
        await _google.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on _Cancelled {
      return const Result.failure(AuthFailure.cancelled());
    } on FirebaseAuthException catch (e) {
      return Result.failure(mapFirebaseAuthCode(e.code));
    } on GoogleSignInException catch (e) {
      debugPrint('Google Sign-In: ${e.code} ${e.description}');
      return const Result.failure(AuthFailure.googleUnavailable());
    } catch (e) {
      debugPrint('Auth: error inesperado $e');
      return const Result.failure(UnexpectedFailure());
    }
  }

  static AuthUser? _toDomain(User? user) {
    if (user == null) return null;
    return AuthUser(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
    );
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Traduce los códigos de `FirebaseAuthException` a fallos de dominio.
Failure mapFirebaseAuthCode(String code) {
  return switch (code) {
    'invalid-credential' ||
    'invalid-login-credentials' ||
    'wrong-password' ||
    'user-not-found' => const AuthFailure.invalidCredentials(),
    'email-already-in-use' => const AuthFailure.emailAlreadyInUse(),
    'weak-password' => const AuthFailure.weakPassword(),
    'invalid-email' => const AuthFailure.invalidEmail(),
    'user-disabled' => const AuthFailure.userDisabled(),
    'too-many-requests' => const AuthFailure.tooManyRequests(),
    'network-request-failed' => const NetworkFailure(),
    'popup-closed-by-user' ||
    'cancelled-popup-request' ||
    'web-context-canceled' => const AuthFailure.cancelled(),
    'account-exists-with-different-credential' =>
      const AuthFailure.accountExistsWithDifferentCredential(),
    'popup-blocked' => const AuthFailure(
      'El navegador bloqueó la ventana de Google. Permite los popups.',
      code: 'popup-blocked',
    ),
    _ => AuthFailure('No pudimos completar la operación ($code).', code: code),
  };
}
