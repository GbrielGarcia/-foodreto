import '../../../../core/error/failure.dart';

sealed class NotificationFailure extends Failure {
  const NotificationFailure(super.message);

  const factory NotificationFailure.notFound() = NotificationNotFound;
  const factory NotificationFailure.notAllowed() = NotificationNotAllowed;
  const factory NotificationFailure.unknown([String? detail]) =
      NotificationUnknown;
}

final class NotificationNotFound extends NotificationFailure {
  const NotificationNotFound() : super('Notificacion no encontrada.');
}

final class NotificationNotAllowed extends NotificationFailure {
  const NotificationNotAllowed() : super('No puedes modificar esta notificacion.');
}

final class NotificationUnknown extends NotificationFailure {
  const NotificationUnknown([String? detail])
      : super(detail ?? 'Error al cargar notificaciones.');
}
