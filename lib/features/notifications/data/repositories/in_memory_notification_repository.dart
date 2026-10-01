import 'dart:async';

import '../../../../core/error/result.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/failures/notification_failure.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/services/notification_deep_link.dart';

class InMemoryNotificationRepository implements NotificationRepository {
  InMemoryNotificationRepository();

  final _items = <String, AppNotification>{};
  final _unreadCtrl = StreamController<void>.broadcast();

  void seed(AppNotification n) {
    _items[n.id] = n;
    _unreadCtrl.add(null);
  }

  List<AppNotification> get all => _items.values.toList();

  @override
  Future<AppNotification?> getNotification(String id) async => _items[id];

  @override
  Future<NotificationPage> getNotifications({
    required String recipientUserId,
    int limit = 20,
    String? cursor,
  }) async {
    final decoded = NotificationCursor.decode(cursor);
    var list = _items.values
        .where((n) => n.recipientUserId == recipientUserId)
        .toList()
      ..sort((a, b) {
        final t = b.createdAt.compareTo(a.createdAt);
        if (t != 0) return t;
        return a.id.compareTo(b.id);
      });
    if (decoded != null) {
      list = [
        for (final n in list)
          if (_after(n, decoded.createdAt, decoded.id)) n,
      ];
    }
    final hasMore = list.length > limit;
    final page = hasMore ? list.sublist(0, limit) : list;
    return NotificationPage(
      items: page,
      nextCursor: hasMore && page.isNotEmpty
          ? NotificationCursor.encode(page.last.createdAt, page.last.id)
          : null,
    );
  }

  static bool _after(AppNotification n, DateTime at, String id) {
    final t = n.createdAt.compareTo(at);
    if (t < 0) return true;
    if (t > 0) return false;
    return n.id.compareTo(id) > 0;
  }

  @override
  Future<int> getUnreadCount(String recipientUserId) async => _items.values
      .where((n) => n.recipientUserId == recipientUserId && !n.read)
      .length;

  @override
  Stream<int> watchUnreadCount(String recipientUserId) async* {
    yield await getUnreadCount(recipientUserId);
    await for (final _ in _unreadCtrl.stream) {
      yield await getUnreadCount(recipientUserId);
    }
  }

  @override
  Future<Result<void>> markAsRead({
    required String notificationId,
    required String recipientUserId,
  }) async {
    final n = _items[notificationId];
    if (n == null) return const Result.failure(NotificationFailure.notFound());
    if (n.recipientUserId != recipientUserId) {
      return const Result.failure(NotificationFailure.notAllowed());
    }
    _items[notificationId] = n.copyWith(read: true);
    _unreadCtrl.add(null);
    return const Result.success(null);
  }

  @override
  Future<Result<int>> markAllAsRead(String recipientUserId) async {
    var count = 0;
    for (final e in _items.entries.toList()) {
      if (e.value.recipientUserId != recipientUserId || e.value.read) continue;
      _items[e.key] = e.value.copyWith(read: true);
      count++;
    }
    _unreadCtrl.add(null);
    return Result.success(count);
  }

  @override
  Future<void> upsert(AppNotification notification) async {
    _items.putIfAbsent(notification.id, () => notification);
    _unreadCtrl.add(null);
  }

  void dispose() => _unreadCtrl.close();
}
