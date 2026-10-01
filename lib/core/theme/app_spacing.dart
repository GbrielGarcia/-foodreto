/// Escala de espaciado y tamaños táctiles.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  static const radiusMd = 16.0;
  static const radiusLg = 24.0;

  /// Altura mínima de los botones principales (uso con una mano).
  static const primaryButtonHeight = 56.0;

  /// Ancho máximo del contenido en pantallas grandes.
  static const maxContentWidth = 720.0;
}

/// Puntos de corte de la navegación adaptativa.
abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 1200.0;
}
