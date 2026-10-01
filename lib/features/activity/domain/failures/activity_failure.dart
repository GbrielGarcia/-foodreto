import '../../../../core/error/failure.dart';

sealed class ActivityFailure extends Failure {
  const ActivityFailure(super.message);

  const factory ActivityFailure.notAllowed() = ActivityNotAllowed;
  const factory ActivityFailure.notFound() = ActivityNotFound;
  const factory ActivityFailure.unknown([String? detail]) = ActivityUnknown;
}

final class ActivityNotAllowed extends ActivityFailure {
  const ActivityNotAllowed() : super('No puedes crear esta actividad.');
}

final class ActivityNotFound extends ActivityFailure {
  const ActivityNotFound() : super('Actividad no encontrada.');
}

final class ActivityUnknown extends ActivityFailure {
  const ActivityUnknown([String? detail])
      : super(detail ?? 'Error al cargar la actividad.');
}
