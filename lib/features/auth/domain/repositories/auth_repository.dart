import '../../../../core/error/result.dart';
import '../entities/auth_user.dart';

abstract interface class AuthRepository {
  /// Emite el usuario actual inmediatamente y en cada cambio de sesión.
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  /// Si esta implementación ofrece "Continuar con Google".
  bool get supportsGoogleSignIn;

  /// Si el usuario cierra el selector devuelve `AuthFailure.cancelled()`.
  Future<Result<AuthUser>> signInWithGoogle();

  Future<Result<void>> signOut();
}
