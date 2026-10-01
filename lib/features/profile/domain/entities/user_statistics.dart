/// Agregados del usuario (`userStatistics/{uid}`), mantenidos por el backend.
class UserStatistics {
  const UserStatistics({
    this.challengeCount = 0,
    this.winCount = 0,
    this.recordCount = 0,
    this.totalUnits = 0,
    this.bestScore = 0,
    this.restaurantCount = 0,
    this.categoryCount = 0,
    this.updatedAt,
  });

  /// Usuario sin actividad todavía (el documento aún no existe).
  static const empty = UserStatistics();

  /// Retos oficiales completados.
  final int challengeCount;

  /// Retos en los que quedó en posición 1 (empates cuentan como victoria).
  final int winCount;

  final int recordCount;
  final int totalUnits;

  /// Mejor score en un único reto oficial.
  final int bestScore;

  final int restaurantCount;
  final int categoryCount;
  final DateTime? updatedAt;

  bool get hasActivity => challengeCount > 0;
}
