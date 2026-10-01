import 'dart:async';

import '../../../../core/error/result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Implementación en memoria para el modo local (sin Firebase) y para tests.
///
/// Las cuentas se pierden al cerrar la app. No usar en producción.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({AuthUser? initialUser}) : _current = initialUser;

  final _accounts = <String, ({String password, AuthUser user})>{};
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;
  int _nextId = 1;

  @override
  Stream<AuthUser?> authStateChanges() {
    // Suscripción síncrona en onListen: no se pierden cambios que ocurran
    // justo después de escuchar (un generador async* arrancaría tarde).
    StreamSubscription<AuthUser?>? subscription;
    late final StreamController<AuthUser?> output;
    output = StreamController<AuthUser?>(
      onListen: () {
        output.add(_current);
        subscription = _controller.stream.listen(output.add);
      },
      onCancel: () => subscription?.cancel(),
    );
    return output.stream;
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final account = _accounts[email];
    if (account == null || account.password != password) {
      return const Result.failure(AuthFailure.invalidCredentials());
    }
    _emit(account.user);
    return Result.success(account.user);
  }

  @override
  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_accounts.containsKey(email)) {
      return const Result.failure(AuthFailure.emailAlreadyInUse());
    }
    final user = AuthUser(
      id: 'local-${_nextId++}',
      email: email,
      displayName: displayName,
    );
    _accounts[email] = (password: password, user: user);
    _emit(user);
    return Result.success(user);
  }

  @override
  bool get supportsGoogleSignIn => false;

  @override
  Future<Result<AuthUser>> signInWithGoogle() async =>
      const Result.failure(AuthFailure.googleUnavailable());

  @override
  Future<Result<void>> signOut() async {
    _emit(null);
    return const Result.success(null);
  }

  void _emit(AuthUser? user) {
    _current = user;
    _controller.add(user);
  }

  Future<void> dispose() => _controller.close();
}
