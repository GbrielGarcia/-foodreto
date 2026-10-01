enum ChallengeInvitationStatus {
  pending,
  accepted,
  rejected,
  expired,
}

/// Invitación interna a un reto (`challengeInvitations/{id}`).
class ChallengeInvitation {
  const ChallengeInvitation({
    required this.id,
    required this.challengeId,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    this.fromUsername = '',
    this.fromDisplayName = '',
    this.challengeTitle = '',
    this.createdAt,
    this.respondedAt,
  });

  final String id;
  final String challengeId;
  final String fromUserId;
  final String toUserId;
  final ChallengeInvitationStatus status;
  final String fromUsername;
  final String fromDisplayName;
  final String challengeTitle;
  final DateTime? createdAt;
  final DateTime? respondedAt;
}
