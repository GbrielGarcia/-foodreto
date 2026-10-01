import '../../../../core/error/failure.dart';

sealed class SocialFailure extends Failure {
  const SocialFailure(super.message, {super.code});
}

final class SocialNotFound extends SocialFailure {
  const SocialNotFound() : super('No encontrado', code: 'not-found');
}

final class SocialSelfAction extends SocialFailure {
  const SocialSelfAction()
    : super('No puedes hacerlo contigo mismo', code: 'self');
}

final class SocialDuplicate extends SocialFailure {
  const SocialDuplicate()
    : super('Ya existe una solicitud o amistad', code: 'duplicate');
}

final class SocialInvalidState extends SocialFailure {
  const SocialInvalidState()
    : super('Estado de amistad inválido', code: 'invalid-state');
}

final class SocialForbidden extends SocialFailure {
  const SocialForbidden()
    : super('No tienes permiso', code: 'permission-denied');
}

final class SocialPrivateProfile extends SocialFailure {
  const SocialPrivateProfile()
    : super('Este perfil es privado', code: 'private-profile');
}
