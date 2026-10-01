import '../../../../core/error/result.dart';
import '../entities/app_notification.dart';

abstract class NotificationRepository {
  Future<NotificationPage> getNotifications({
    required String recipientUserId,
    int limit = 20,
    String? cursor,
  });

  Future<AppNotification?> getNotification(String id);

  /// Contador (una vez). Preferir [watchUnreadCount] en UI.
  Future<int> getUnreadCount(String recipientUserId);

  Stream<int> watchUnreadCount(String recipientUserId);

  Future<Result<void>> markAsRead({
    required String notificationId,
    required String recipientUserId,
  });

  /// Batch de no leidas (paginado interno, max 500 por lote Firestore).
  Future<Result<int>> markAllAsRead(String recipientUserId);

  /// Solo modo local / tests. Firebase: Admin SDK.
  Future<void> upsert(AppNotification notification);
}
