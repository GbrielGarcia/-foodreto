import '../entities/notification_type.dart';

/// IDs deterministas para idempotencia.
abstract final class NotificationIds {
  static String friendRequest(String friendshipId) =>
      'friendRequest_$friendshipId';

  static String friendAccepted(String friendshipId) =>
      'friendAccepted_$friendshipId';

  static String challengeInvitation(String challengeId, String recipientUserId) =>
      'challengeInvitation_${challengeId}_$recipientUserId';

  static String friendJoined({
    required String challengeId,
    required String actorUserId,
    required String recipientUserId,
  }) =>
      'friendJoined_${challengeId}_${actorUserId}_$recipientUserId';

  static String challengeWon(String challengeId, String userId) =>
      'challengeWon_${challengeId}_$userId';

  static String challengeCompleted(String challengeId, String userId) =>
      'challengeCompleted_${challengeId}_$userId';

  /// Confirmacion de resultado tras jugar en el mismo celular.
  static String sameDeviceConfirm(String challengeId, String userId) =>
      'sameDeviceConfirm_${challengeId}_$userId';

  static String recordCreated(String challengeId, String userId) =>
      'recordCreated_${challengeId}_$userId';

  static String recordBroken(String challengeId, String userId) =>
      'recordBroken_${challengeId}_$userId';

  static String forType({
    required NotificationType type,
    required String primaryId,
    String? secondaryId,
  }) {
    return switch (type) {
      NotificationType.friendRequest => friendRequest(primaryId),
      NotificationType.friendRequestAccepted => friendAccepted(primaryId),
      NotificationType.challengeInvitation =>
        challengeInvitation(primaryId, secondaryId ?? ''),
      NotificationType.friendJoinedChallenge => friendJoined(
          challengeId: primaryId,
          actorUserId: secondaryId ?? '',
          recipientUserId: '',
        ),
      NotificationType.challengeWon => challengeWon(primaryId, secondaryId ?? ''),
      NotificationType.challengeCompleted =>
        challengeCompleted(primaryId, secondaryId ?? ''),
      NotificationType.recordCreated =>
        recordCreated(primaryId, secondaryId ?? ''),
      NotificationType.recordBroken =>
        recordBroken(primaryId, secondaryId ?? ''),
      NotificationType.establishmentApproved ||
      NotificationType.establishmentRejected ||
      NotificationType.establishmentTransferred =>
        '${type.name}_$primaryId${secondaryId != null ? '_$secondaryId' : ''}',
    };
  }
}
