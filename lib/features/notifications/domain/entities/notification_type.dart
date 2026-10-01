/// Tipos de notificacion in-app (Fase 8).
enum NotificationType {
  friendRequest,
  friendRequestAccepted,
  challengeInvitation,
  friendJoinedChallenge,
  challengeCompleted,
  challengeWon,
  recordCreated,
  recordBroken,
  establishmentApproved,
  establishmentRejected,
  establishmentTransferred;

  static NotificationType? tryParse(Object? raw) {
    if (raw is! String) return null;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  /// Oficiales: solo backend / Admin SDK.
  bool get isOfficial => switch (this) {
        challengeCompleted ||
        challengeWon ||
        recordCreated ||
        recordBroken ||
        establishmentApproved ||
        establishmentRejected ||
        establishmentTransferred =>
          true,
        friendRequest ||
        friendRequestAccepted ||
        challengeInvitation ||
        friendJoinedChallenge =>
          false,
      };
}
