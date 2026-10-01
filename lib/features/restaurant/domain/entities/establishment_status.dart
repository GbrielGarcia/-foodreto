/// Estado administrativo de un establecimiento (`restaurants/{id}.status`).
enum EstablishmentStatus {
  pending,
  approved,
  rejected,
  suspended;

  static EstablishmentStatus fromId(Object? raw) {
    final s = raw is String ? raw : '';
    return EstablishmentStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => EstablishmentStatus.approved,
    );
  }

  /// Visible en mapa / busqueda / retos publicos.
  bool get isPubliclyDiscoverable => this == EstablishmentStatus.approved;

  String get label => switch (this) {
        pending => 'Pendiente',
        approved => 'Aprobado',
        rejected => 'Rechazado',
        suspended => 'Suspendido',
      };
}
