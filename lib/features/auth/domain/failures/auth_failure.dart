import '../../../../core/error/failure.dart';

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});

  const AuthFailure.invalidCredentials()
    : super('Correo o contraseña incorrectos.', code: 'invalid-credential');

  const AuthFailure.emailAlreadyInUse()
    : super(
        'Ya existe una cuenta con ese correo.',
        code: 'email-already-in-use',
      );

  const AuthFailure.weakPassword()
    : super('La contraseña es demasiado débil.', code: 'weak-password');

  const AuthFailure.invalidEmail()
    : super('Ese correo no parece válido.', code: 'invalid-email');

  const AuthFailure.userDisabled()
    : super('Esta cuenta está desactivada.', code: 'user-disabled');

  /// El usuario cerró el flujo de login; no se muestra como error.
  const AuthFailure.cancelled()
    : super('Inicio de sesión cancelado.', code: cancelledCode);

  static const cancelledCode = 'cancelled';

  bool get isCancelled => code == cancelledCode;

  const AuthFailure.accountExistsWithDifferentCredential()
    : super(
        'Ese correo ya está registrado con otro método. '
        'Entra con tu contraseña.',
        code: 'account-exists-with-different-credential',
      );

  const AuthFailure.googleUnavailable()
    : super(
        'El inicio con Google no está disponible en este dispositivo.',
        code: 'google-unavailable',
      );

  const AuthFailure.tooManyRequests()
    : super(
        'Demasiados intentos. Espera un momento y vuelve a probar.',
        code: 'too-many-requests',
      );
}
