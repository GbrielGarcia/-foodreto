import '../../../../core/error/failure.dart';

class ProfileFailure extends Failure {
  const ProfileFailure(super.message, {super.code});

  const ProfileFailure.usernameTaken()
    : super('Ese @username ya está en uso.', code: 'username-taken');

  const ProfileFailure.invalidData(super.message) : super(code: 'invalid-data');

  const ProfileFailure.notFound()
    : super('No encontramos tu perfil.', code: 'not-found');

  const ProfileFailure.alreadyExists()
    : super('Tu perfil ya existe.', code: 'already-exists');

  const ProfileFailure.permissionDenied()
    : super(
        'No tienes permiso para hacer este cambio.',
        code: 'permission-denied',
      );
}
