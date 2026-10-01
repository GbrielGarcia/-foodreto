/// Error de dominio con un mensaje apto para mostrar al usuario.
///
/// Las capas `data` traducen las excepciones de infraestructura (Firebase,
/// red, etc.) a subclases de [Failure]; los widgets nunca ven excepciones crudas.
abstract class Failure {
  const Failure(this.message, {this.code});

  final String message;

  /// Código técnico original, útil para logs y analítica.
  final String? code;

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    super.message = 'Algo salió mal. Inténtalo de nuevo.',
  ]) : super(code: 'unexpected');
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Sin conexión. Revisa tu Internet e inténtalo de nuevo.',
  ]) : super(code: 'network');
}
