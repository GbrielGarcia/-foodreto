import '../entities/app_notification.dart';
import '../entities/notification_type.dart';

/// Resuelve deep link interno a partir del tipo y campos.
abstract final class NotificationDeepLink {
  static String? resolve(AppNotification n) {
    if (n.targetRoute != null && n.targetRoute!.isNotEmpty) {
      return n.targetRoute;
    }
    return switch (n.type) {
      NotificationType.friendRequest => '/friends/requests',
      NotificationType.friendRequestAccepted =>
        n.actorUserId.isEmpty ? '/friends' : '/u/${n.actorUserId}',
      NotificationType.challengeInvitation ||
      NotificationType.friendJoinedChallenge ||
      NotificationType.challengeCompleted ||
      NotificationType.challengeWon =>
        n.challengeId != null && n.challengeId!.isNotEmpty
            ? '/challenges/${n.challengeId}'
            : null,
      NotificationType.recordCreated || NotificationType.recordBroken =>
        n.challengeId != null && n.challengeId!.isNotEmpty
            ? '/challenges/${n.challengeId}'
            : (n.categoryId != null && n.categoryId!.isNotEmpty
                ? '/category/${n.categoryId}'
                : '/rankings'),
      NotificationType.establishmentApproved ||
      NotificationType.establishmentRejected =>
        '/establishments/mine',
      NotificationType.establishmentTransferred =>
        n.targetRoute ?? '/establishments/mine',
    };
  }
}

abstract final class NotificationCursor {
  static String encode(DateTime createdAt, String id) =>
      '${createdAt.toUtc().millisecondsSinceEpoch}_$id';

  static ({DateTime createdAt, String id})? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final sep = raw.indexOf('_');
    if (sep <= 0) return null;
    final ms = int.tryParse(raw.substring(0, sep));
    final id = raw.substring(sep + 1);
    if (ms == null || id.isEmpty) return null;
    return (
      createdAt: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      id: id,
    );
  }
}
