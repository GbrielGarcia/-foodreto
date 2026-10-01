import '../../../../core/avatar/avatar_config.dart';
import 'notification_type.dart';

/// Notificacion in-app privada del destinatario.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.type,
    required this.actorUserId,
    required this.actorUsername,
    required this.actorDisplayName,
    required this.actorAvatar,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.challengeId,
    this.activityId,
    this.recordId,
    this.targetRoute,
    this.categoryId,
    this.categoryName,
  });

  final String id;
  final String recipientUserId;
  final NotificationType type;
  final String actorUserId;
  final String actorUsername;
  final String actorDisplayName;
  final AvatarConfig actorAvatar;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String? challengeId;
  final String? activityId;
  final String? recordId;
  final String? targetRoute;
  final String? categoryId;
  final String? categoryName;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        recipientUserId: recipientUserId,
        type: type,
        actorUserId: actorUserId,
        actorUsername: actorUsername,
        actorDisplayName: actorDisplayName,
        actorAvatar: actorAvatar,
        title: title,
        body: body,
        read: read ?? this.read,
        createdAt: createdAt,
        challengeId: challengeId,
        activityId: activityId,
        recordId: recordId,
        targetRoute: targetRoute,
        categoryId: categoryId,
        categoryName: categoryName,
      );
}

class NotificationPage {
  const NotificationPage({required this.items, this.nextCursor});

  final List<AppNotification> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
