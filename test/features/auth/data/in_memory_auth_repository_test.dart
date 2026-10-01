import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/error/result.dart';
import 'package:foodreto/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:foodreto/features/auth/domain/failures/auth_failure.dart';

void main() {
  late InMemoryAuthRepository repository;

  setUp(() => repository = InMemoryAuthRepository());
  tearDown(() => repository.dispose());

  test('registro inicia sesión y emite el usuario', () async {
    final states = repository.authStateChanges().take(2).toList();

    final result = await repository.signUpWithEmail(
      email: 'gabriel@foodreto.app',
      password: 'secreto123',
      displayName: 'Gabriel',
    );

    expect(result, isA<Success<Object?>>());
    expect(repository.currentUser?.displayName, 'Gabriel');
    expect((await states).map((u) => u?.email), [null, 'gabriel@foodreto.app']);
  });

  test('no permite correos duplicados', () async {
    await repository.signUpWithEmail(
      email: 'a@b.co',
      password: 'secreto123',
      displayName: 'A',
    );
    final result = await repository.signUpWithEmail(
      email: 'a@b.co',
      password: 'otra12345',
      displayName: 'B',
    );

    expect(
      (result as Err).failure,
      isA<AuthFailure>().having((f) => f.code, 'code', 'email-already-in-use'),
    );
  });

  test('login con contraseña incorrecta falla', () async {
    await repository.signUpWithEmail(
      email: 'a@b.co',
      password: 'secreto123',
      displayName: 'A',
    );
    await repository.signOut();

    final wrong = await repository.signInWithEmail(
      email: 'a@b.co',
      password: 'incorrecta',
    );
    final ok = await repository.signInWithEmail(
      email: 'a@b.co',
      password: 'secreto123',
    );

    expect(wrong.isSuccess, isFalse);
    expect(ok.isSuccess, isTrue);
  });

  test('logout emite null', () async {
    await repository.signUpWithEmail(
      email: 'a@b.co',
      password: 'secreto123',
      displayName: 'A',
    );
    await repository.signOut();
    expect(repository.currentUser, isNull);
  });
}
