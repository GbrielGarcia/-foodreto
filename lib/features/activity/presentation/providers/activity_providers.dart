import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../social/domain/entities/friendship.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../data/repositories/firestore_activity_repository.dart';
import '../../data/repositories/in_memory_activity_repository.dart';
import '../../domain/entities/social_activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/usecases/activity_usecases.dart';

final inMemoryActivityRepositoryProvider =
    Provider<InMemoryActivityRepository>((ref) {
  return InMemoryActivityRepository();
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return switch (ref.watch(appConfigProvider).backendMode) {
    BackendMode.firebase =>
      FirestoreActivityRepository(ref.watch(firestoreProvider)),
    BackendMode.local => ref.watch(inMemoryActivityRepositoryProvider),
  };
});

final getFeedProvider = Provider(
  (ref) => GetFeed(ref.watch(activityRepositoryProvider)),
);

final getUserActivitiesProvider = Provider(
  (ref) => GetUserActivities(ref.watch(activityRepositoryProvider)),
);

final recordJoinActivityProvider = Provider(
  (ref) => RecordJoinActivity(ref.watch(activityRepositoryProvider)),
);

/// Estado del feed con paginacion.
class FeedViewState {
  const FeedViewState({
    required this.items,
    this.nextCursor,
    this.loadingMore = false,
  });

  final List<SocialActivity> items;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  FeedViewState copyWith({
    List<SocialActivity>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
  }) =>
      FeedViewState(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class FeedController extends AsyncNotifier<FeedViewState> {
  static const _pageSize = 20;

  @override
  Future<FeedViewState> build() => _load();

  Future<FeedViewState> _load({String? cursor}) async {
    final uid = ref.read(authStateProvider).value?.id;
    if (uid == null) {
      return const FeedViewState(items: []);
    }
    final friendsPage = await ref.read(socialRepositoryProvider).listFriends(
          uid: uid,
          limit: InMemoryActivityRepository.maxFeedFriends,
        );
    final friendIds = [
      for (final f in friendsPage.items)
        if (f.status == FriendshipStatus.accepted) f.otherUserId(uid),
    ];
    final page = await ref.read(getFeedProvider)(
      viewerUserId: uid,
      friendUserIds: friendIds,
      limit: _pageSize,
      cursor: cursor,
    );
    return FeedViewState(items: page.items, nextCursor: page.nextCursor);
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
      final friendsPage = await ref.read(socialRepositoryProvider).listFriends(
            uid: uid,
            limit: InMemoryActivityRepository.maxFeedFriends,
          );
      final friendIds = [
        for (final f in friendsPage.items)
          if (f.status == FriendshipStatus.accepted) f.otherUserId(uid),
      ];
      final page = await ref.read(getFeedProvider)(
        viewerUserId: uid,
        friendUserIds: friendIds,
        limit: _pageSize,
        cursor: current.nextCursor,
      );
      final seen = {for (final a in current.items) a.id};
      final merged = [
        ...current.items,
        for (final a in page.items)
          if (!seen.contains(a.id)) a,
      ];
      state = AsyncData(
        FeedViewState(
          items: merged,
          nextCursor: page.nextCursor,
        ),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final feedControllerProvider =
    AsyncNotifierProvider.autoDispose<FeedController, FeedViewState>(
  FeedController.new,
);

/// Preview corta para Home (sin paginacion).
final feedPreviewProvider =
    FutureProvider.autoDispose<List<SocialActivity>>((ref) async {
  final uid = ref.watch(authStateProvider).value?.id;
  if (uid == null) return const [];
  final friendsPage = await ref.watch(socialRepositoryProvider).listFriends(
        uid: uid,
        limit: InMemoryActivityRepository.maxFeedFriends,
      );
  final friendIds = [
    for (final f in friendsPage.items)
      if (f.status == FriendshipStatus.accepted) f.otherUserId(uid),
  ];
  final page = await ref.watch(getFeedProvider)(
    viewerUserId: uid,
    friendUserIds: friendIds,
    limit: 5,
  );
  return page.items;
});
