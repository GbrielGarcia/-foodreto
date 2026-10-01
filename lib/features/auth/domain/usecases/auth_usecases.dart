import '../../../../core/error/result.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class WatchAuthState {
  const WatchAuthState(this._repository);
  final AuthRepository _repository;

  Stream<AuthUser?> call() => _repository.authStateChanges();
}

class SignInWithEmail {
  const SignInWithEmail(this._repository);
  final AuthRepository _repository;

  Future<Result<AuthUser>> call({
    required String email,
    required String password,
  }) {
    return _repository.signInWithEmail(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }
}

class SignUpWithEmail {
  const SignUpWithEmail(this._repository);
  final AuthRepository _repository;

  Future<Result<AuthUser>> call({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _repository.signUpWithEmail(
      email: email.trim().toLowerCase(),
      password: password,
      displayName: displayName.trim(),
    );
  }
}

class SignInWithGoogle {
  const SignInWithGoogle(this._repository);
  final AuthRepository _repository;

  Future<Result<AuthUser>> call() => _repository.signInWithGoogle();
}

class SignOut {
  const SignOut(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.signOut();
}
