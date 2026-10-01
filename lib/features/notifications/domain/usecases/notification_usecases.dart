import '../../../../core/error/result.dart';
import '../entities/app_notification.dart';
import '../repositories/notification_repository.dart';

class GetNotifications {
  const GetNotifications(this._repo);
  final NotificationRepository _repo;

  Future<NotificationPage> call({
    required String recipientUserId,
    int limit = 20,
    String? cursor,
  }) =>
      _repo.getNotifications(
        recipientUserId: recipientUserId,
        limit: limit,
        cursor: cursor,
      );
}

class MarkNotificationRead {
  const MarkNotificationRead(this._repo);
  final NotificationRepository _repo;

  Future<Result<void>> call({
    required String notificationId,
    required String recipientUserId,
  }) =>
      _repo.markAsRead(
        notificationId: notificationId,
        recipientUserId: recipientUserId,
      );
}

class MarkAllNotificationsRead {
  const MarkAllNotificationsRead(this._repo);
  final NotificationRepository _repo;

  Future<Result<int>> call(String recipientUserId) =>
      _repo.markAllAsRead(recipientUserId);
}
