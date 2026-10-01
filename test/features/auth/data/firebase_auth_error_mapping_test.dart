import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/error/failure.dart';
import 'package:foodreto/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:foodreto/features/auth/domain/failures/auth_failure.dart';

void main() {
  test('credenciales inválidas agrupan varios códigos', () {
    for (final code in [
      'invalid-credential',
      'invalid-login-credentials',
      'wrong-password',
      'user-not-found',
    ]) {
      expect(mapFirebaseAuthCode(code).code, 'invalid-credential');
    }
  });

  test('errores de red se tratan como NetworkFailure', () {
    expect(
      mapFirebaseAuthCode('network-request-failed'),
      isA<NetworkFailure>(),
    );
  });

  test('cerrar el popup de Google equivale a cancelar', () {
    for (final code in [
      'popup-closed-by-user',
      'cancelled-popup-request',
      'web-context-canceled',
    ]) {
      final failure = mapFirebaseAuthCode(code);
      expect(failure, isA<AuthFailure>(), reason: code);
      expect((failure as AuthFailure).isCancelled, isTrue, reason: code);
    }
  });

  test('cuenta existente con otro proveedor tiene mensaje propio', () {
    final failure = mapFirebaseAuthCode(
      'account-exists-with-different-credential',
    );
    const expected = AuthFailure.accountExistsWithDifferentCredential();
    expect(failure.code, expected.code);
    expect(failure.message, expected.message);
  });

  test('códigos desconocidos conservan el código original', () {
    final failure = mapFirebaseAuthCode('quota-exceeded');
    expect(failure, isA<AuthFailure>());
    expect(failure.code, 'quota-exceeded');
  });
}
