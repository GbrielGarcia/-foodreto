/// Tipos de actividad social del feed (Fase 7).
enum SocialActivityType {
  challengeCompleted,
  challengeWon,
  recordCreated,
  recordBroken,
  friendJoinedChallenge;

  static SocialActivityType? tryParse(Object? raw) {
    if (raw is! String) return null;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  /// Actividades derivadas del pipeline oficial (solo backend).
  bool get isOfficial => switch (this) {
        challengeCompleted ||
        challengeWon ||
        recordCreated ||
        recordBroken =>
          true,
        friendJoinedChallenge => false,
      };
}
