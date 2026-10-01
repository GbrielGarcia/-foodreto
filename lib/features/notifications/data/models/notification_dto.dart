import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/notification_type.dart';
import '../../domain/services/notification_deep_link.dart';

abstract final class NotificationDto {
  static AppNotification? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final type = NotificationType.tryParse(data['type']);
    final recipient = data['recipientUserId'] as String?;
    final createdAt = readTimestamp(data['createdAt']);
    if (type == null ||
        recipient == null ||
        recipient.isEmpty ||
        createdAt == null) {
      return null;
    }
    return AppNotification(
      id: id,
      recipientUserId: recipient,
      type: type,
      actorUserId: data['actorUserId'] as String? ?? '',
      actorUsername: data['actorUsername'] as String? ?? '',
      actorDisplayName: data['actorDisplayName'] as String? ?? '',
      actorAvatar: AvatarConfig.fromData(
        style: data['actorAvatarStyle'],
        seed: data['actorAvatarSeed'],
        options: data['actorAvatarOptions'],
      ),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      read: data['read'] == true,
      createdAt: createdAt,
      challengeId: data['challengeId'] as String?,
      activityId: data['activityId'] as String?,
      recordId: data['recordId'] as String?,
      targetRoute: data['targetRoute'] as String?,
      categoryId: data['categoryId'] as String?,
      categoryName: data['categoryName'] as String?,
    );
  }

  static Map<String, Object?> toMap(AppNotification n) => {
        'recipientUserId': n.recipientUserId,
        'type': n.type.name,
        'actorUserId': n.actorUserId,
        'actorUsername': n.actorUsername,
        'actorDisplayName': n.actorDisplayName,
        'actorAvatarStyle': n.actorAvatar.style,
        'actorAvatarSeed': n.actorAvatar.seed,
        'actorAvatarOptions': n.actorAvatar.options,
        'title': n.title,
        'body': n.body,
        'read': n.read,
        'createdAt': Timestamp.fromDate(n.createdAt.toUtc()),
        'challengeId': n.challengeId,
        'activityId': n.activityId,
        'recordId': n.recordId,
        'targetRoute': n.targetRoute,
        'categoryId': n.categoryId,
        'categoryName': n.categoryName,
      };

  static String? encodeCursor(AppNotification last) =>
      NotificationCursor.encode(last.createdAt, last.id);

  static ({DateTime createdAt, String id})? decodeCursor(String? cursor) =>
      NotificationCursor.decode(cursor);
}
