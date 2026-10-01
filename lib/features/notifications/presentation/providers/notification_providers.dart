import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_notification_repository.dart';
import '../../data/repositories/in_memory_notification_repository.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/notification_usecases.dart';

final inMemoryNotificationRepositoryProvider =
    Provider<InMemoryNotificationRepository>((ref) {
  final repo = InMemoryNotificationRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return switch (ref.watch(appConfigProvider).backendMode) {
    BackendMode.firebase =>
      FirestoreNotificationRepository(ref.watch(firestoreProvider)),
    BackendMode.local => ref.watch(inMemoryNotificationRepositoryProvider),
  };
});

final getNotificationsProvider = Provider(
  (ref) => GetNotifications(ref.watch(notificationRepositoryProvider)),
);

final markNotificationReadProvider = Provider(
  (ref) => MarkNotificationRead(ref.watch(notificationRepositoryProvider)),
);

final markAllNotificationsReadProvider = Provider(
  (ref) => MarkAllNotificationsRead(ref.watch(notificationRepositoryProvider)),
);

/// Contador realtime de no leidas.
final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = ref.watch(authStateProvider).value?.id;
  if (uid == null) return Stream.value(0);
  return ref.watch(notificationRepositoryProvider).watchUnreadCount(uid);
});

class NotificationsViewState {
  const NotificationsViewState({
    required this.items,
    this.nextCursor,
    this.loadingMore = false,
  });

  final List<AppNotification> items;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  NotificationsViewState copyWith({
    List<AppNotification>? items,
    String? nextCursor,
    bool? loadingMore,
  }) =>
      NotificationsViewState(
        items: items ?? this.items,
        nextCursor: nextCursor ?? this.nextCursor,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class NotificationsController extends AsyncNotifier<NotificationsViewState> {
  static const _pageSize = 20;

  @override
  Future<NotificationsViewState> build() => _load();

  Future<NotificationsViewState> _load({String? cursor}) async {
    final uid = ref.read(authStateProvider).value?.id;
    if (uid == null) return const NotificationsViewState(items: []);
    final page = await ref.read(getNotificationsProvider)(
      recipientUserId: uid,
      limit: _pageSize,
      cursor: cursor,
    );
    return NotificationsViewState(
      items: page.items,
      nextCursor: page.nextCursor,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final uid = ref.read(authStateProvider).value?.id;
      if (uid == null) return;
      final page = await ref.read(getNotificationsProvider)(
        recipientUserId: uid,
        limit: _pageSize,
        cursor: current.nextCursor,
      );
      final seen = {for (final n in current.items) n.id};
      state = AsyncData(
        NotificationsViewState(
          items: [
            ...current.items,
            for (final n in page.items)
              if (!seen.contains(n.id)) n,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> markRead(String notificationId) async {
    final uid = ref.read(authStateProvider).value?.id;
    if (uid == null) return;
    await ref.read(markNotificationReadProvider)(
      notificationId: notificationId,
      recipientUserId: uid,
    );
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final n in current.items)
            if (n.id == notificationId) n.copyWith(read: true) else n,
        ],
      ),
    );
  }

  Future<void> markAllRead() async {
    final uid = ref.read(authStateProvider).value?.id;
    if (uid == null) return;
    await ref.read(markAllNotificationsReadProvider)(uid);
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [for (final n in current.items) n.copyWith(read: true)],
      ),
    );
  }
}

final notificationsControllerProvider = AsyncNotifierProvider.autoDispose<
    NotificationsController, NotificationsViewState>(
  NotificationsController.new,
);
