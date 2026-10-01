import '../../../../core/avatar/avatar_config.dart';

enum ParticipantRole {
  host,
  participant;

  static ParticipantRole fromId(Object? id) =>
      id == host.name ? host : participant;
}

/// Participante (`challenges/{id}/participants/{uid}`).
///
/// Guarda una copia del perfil público (username, nombre, avatar) para pintar
/// la sala sin leer N perfiles. Nunca incluye el correo.
class ChallengeParticipant {
  const ChallengeParticipant({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatar,
    this.role = ParticipantRole.participant,
    this.currentCount = 0,
    this.lastEventId,
    this.joinedAt,
  });

  final String userId;
  final String username;
  final String displayName;
  final AvatarConfig avatar;
  final ParticipantRole role;

  /// Proyección en vivo de la suma de sus eventos (las reglas garantizan que
  /// cada cambio va acompañado de exactamente un evento nuevo).
  final int currentCount;
  final String? lastEventId;
  final DateTime? joinedAt;

  bool get isHost => role == ParticipantRole.host;

  ChallengeParticipant copyWith({int? currentCount, String? lastEventId}) =>
      ChallengeParticipant(
        userId: userId,
        username: username,
        displayName: displayName,
        avatar: avatar,
        role: role,
        currentCount: currentCount ?? this.currentCount,
        lastEventId: lastEventId ?? this.lastEventId,
        joinedAt: joinedAt,
      );
}
