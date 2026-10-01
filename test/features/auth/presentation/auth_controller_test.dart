import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/config/app_config.dart';
import 'package:foodreto/core/error/result.dart';
import 'package:foodreto/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:foodreto/features/auth/domain/entities/auth_user.dart';
import 'package:foodreto/features/auth/domain/failures/auth_failure.dart';
import 'package:foodreto/features/auth/presentation/providers/auth_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer.test(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(backendMode: BackendMode.local),
        ),
      ],
    );
    // Mantiene vivo el provider autoDispose durante el test.
    container.listen(authControllerProvider, (_, _) {});
  });

  test('signUp exitoso deja AsyncData y actualiza la sesión', () async {
    final ok = await container
        .read(authControllerProvider.notifier)
        .signUp(
          email: ' Gabriel@FoodReto.app ',
          password: 'secreto123',
          displayName: ' Gabriel ',
        );

    expect(ok, isTrue);
    expect(container.read(authControllerProvider), isA<AsyncData<void>>());
    final user = container.read(authRepositoryProvider).currentUser;
    expect(user?.email, 'gabriel@foodreto.app', reason: 'email normalizado');
    expect(user?.displayName, 'Gabriel');
  });

  test('signIn fallido expone el Failure', () async {
    final ok = await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'nadie@foodreto.app', password: 'secreto123');

    expect(ok, isFalse);
    final state = container.read(authControllerProvider);
    expect(state.error, isA<AuthFailure>());
  });

  test('cancelar Google no muestra error', () async {
    final google = ProviderContainer.test(
      overrides: [
        authRepositoryProvider.overrideWithValue(_CancellingGoogleRepository()),
      ],
    )..listen(authControllerProvider, (_, _) {});

    final ok = await google
        .read(authControllerProvider.notifier)
        .signInWithGoogle();

    expect(ok, isFalse);
    expect(google.read(authControllerProvider), isA<AsyncData<void>>());
  });
}

class _CancellingGoogleRepository extends InMemoryAuthRepository {
  @override
  bool get supportsGoogleSignIn => true;

  @override
  Future<Result<AuthUser>> signInWithGoogle() async =>
      const Err(AuthFailure.cancelled());
}
