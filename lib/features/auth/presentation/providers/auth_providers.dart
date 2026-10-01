import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/result.dart';
import '../../../../firebase_options.dart';
import '../../data/datasources/google_id_token_source.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../data/repositories/in_memory_auth_repository.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  switch (config.backendMode) {
    case BackendMode.firebase:
      return FirebaseAuthRepository(
        FirebaseAuth.instance,
        google: NativeGoogleIdTokenSource(
          iosClientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
        ),
      );
    case BackendMode.local:
      final repository = InMemoryAuthRepository();
      ref.onDispose(repository.dispose);
      return repository;
  }
});

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return WatchAuthState(ref.watch(authRepositoryProvider))();
});

/// Usuario autenticado actual, o `null` si no hay sesión (o aún carga).
final currentUserProvider = Provider<AuthUser?>(
  (ref) => ref.watch(authStateProvider).value,
);

final signInWithEmailProvider = Provider(
  (ref) => SignInWithEmail(ref.watch(authRepositoryProvider)),
);

final signUpWithEmailProvider = Provider(
  (ref) => SignUpWithEmail(ref.watch(authRepositoryProvider)),
);

final signInWithGoogleProvider = Provider(
  (ref) => SignInWithGoogle(ref.watch(authRepositoryProvider)),
);

final signOutProvider = Provider(
  (ref) => SignOut(ref.watch(authRepositoryProvider)),
);

/// Estado de las acciones de autenticación (login, registro, logout).
///
/// `AsyncError` contiene un `Failure` con el mensaje a mostrar.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> signIn({required String email, required String password}) {
    return _run(
      () => ref.read(signInWithEmailProvider)(email: email, password: password),
    );
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _run(
      () => ref.read(signUpWithEmailProvider)(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  Future<bool> signInWithGoogle() =>
      _run(() => ref.read(signInWithGoogleProvider)());

  Future<bool> signOut() => _run(() => ref.read(signOutProvider)());

  Future<bool> _run(Future<Result<Object?>> Function() action) async {
    state = const AsyncLoading();
    final result = await action();
    if (!ref.mounted) return result.isSuccess;
    state = result.fold(
      onSuccess: (_) => const AsyncData(null),
      onFailure: (failure) => failure is AuthFailure && failure.isCancelled
          ? const AsyncData(null)
          : AsyncError(failure, StackTrace.current),
    );
    return result.isSuccess;
  }
}

final authControllerProvider =
    AsyncNotifierProvider.autoDispose<AuthController, void>(AuthController.new);
