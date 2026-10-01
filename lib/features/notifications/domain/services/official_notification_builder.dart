import '../../../../core/avatar/avatar_config.dart';
import '../../../challenge/domain/entities/challenge_result.dart';
import '../../../leaderboard/domain/services/official_result_processor.dart';
import '../entities/app_notification.dart';
import '../entities/notification_type.dart';
import 'notification_ids.dart';

/// Construye notificaciones oficiales (modo local / tests).
abstract final class OfficialNotificationBuilder {
  static List<AppNotification> fromResult({
    required ChallengeResult result,
    required OfficialResultDiff diff,
    String? categoryName,
  }) {
    if (diff.skipped) return const [];
    final at = result.finishedAt ?? DateTime.now().toUtc();
    final winners = {...diff.winnerIds};
    final out = <AppNotification>[];
    final cat = categoryName != null ? ' de $categoryName' : '';

    for (final e in result.entries) {
      out.add(
        _self(
          id: NotificationIds.challengeCompleted(result.challengeId, e.userId),
          type: NotificationType.challengeCompleted,
          entry: e,
          title: 'Reto finalizado',
          body: 'Tu reto$cat ha terminado',
          result: result,
          at: at,
          categoryName: categoryName,
        ),
      );
      if (winners.contains(e.userId)) {
        out.add(
          _self(
            id: NotificationIds.challengeWon(result.challengeId, e.userId),
            type: NotificationType.challengeWon,
            entry: e,
            title: '\u00a1Victoria!',
            body: 'Ganaste el reto$cat',
            result: result,
            at: at,
            categoryName: categoryName,
          ),
        );
      }
    }

    final seen = <String>{};
    for (final h in diff.historyEvents) {
      if (!h.scopeKey.startsWith('global:cat:')) continue;
      final type = h.eventType == 'broken'
          ? NotificationType.recordBroken
          : NotificationType.recordCreated;
      final id = type == NotificationType.recordBroken
          ? NotificationIds.recordBroken(h.challengeId, h.userId)
          : NotificationIds.recordCreated(h.challengeId, h.userId);
      if (!seen.add(id)) continue;
      out.add(
        AppNotification(
          id: id,
          recipientUserId: h.userId,
          type: type,
          actorUserId: h.userId,
          actorUsername: h.username,
          actorDisplayName: h.displayName,
          actorAvatar: h.avatar,
          title: type == NotificationType.recordBroken
              ? 'R\u00e9cord superado'
              : 'Nuevo r\u00e9cord',
          body: type == NotificationType.recordBroken
              ? 'Superaste el r\u00e9cord$cat'
              : 'Conseguiste un nuevo r\u00e9cord$cat',
          read: false,
          createdAt: h.achievedAt,
          challengeId: h.challengeId,
          recordId: id,
          categoryId: result.categoryId,
          categoryName: categoryName,
          targetRoute: '/challenges/${h.challengeId}',
        ),
      );
    }
    return out;
  }

  static AppNotification _self({
    required String id,
    required NotificationType type,
    required ResultEntry entry,
    required String title,
    required String body,
    required ChallengeResult result,
    required DateTime at,
    String? categoryName,
  }) =>
      AppNotification(
        id: id,
        recipientUserId: entry.userId,
        type: type,
        actorUserId: entry.userId,
        actorUsername: entry.username,
        actorDisplayName: entry.displayName,
        actorAvatar: entry.avatar,
        title: title,
        body: body,
        read: false,
        createdAt: at,
        challengeId: result.challengeId,
        categoryId: result.categoryId,
        categoryName: categoryName,
        targetRoute: '/challenges/${result.challengeId}',
      );

  static AppNotification friendRequest({
    required String friendshipId,
    required String recipientUserId,
    required String actorUserId,
    required String actorUsername,
    required String actorDisplayName,
    required AvatarConfig actorAvatar,
    DateTime? at,
  }) =>
      AppNotification(
        id: NotificationIds.friendRequest(friendshipId),
        recipientUserId: recipientUserId,
        type: NotificationType.friendRequest,
        actorUserId: actorUserId,
        actorUsername: actorUsername,
        actorDisplayName: actorDisplayName,
        actorAvatar: actorAvatar,
        title: 'Nueva solicitud',
        body: '@$actorUsername te envi\u00f3 una solicitud de amistad',
        read: false,
        createdAt: at ?? DateTime.now().toUtc(),
        targetRoute: '/friends/requests',
      );
}
