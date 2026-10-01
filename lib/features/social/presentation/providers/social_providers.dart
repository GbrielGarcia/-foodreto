import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../leaderboard/domain/entities/ranking_entry.dart';
import '../../../leaderboard/domain/entities/ranking_scope.dart';
import '../../../leaderboard/domain/services/official_result_processor.dart';
import '../../../leaderboard/presentation/providers/leaderboard_providers.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/entities/user_statistics.dart';
import '../../data/repositories/firestore_social_repository.dart';
import '../../data/repositories/in_memory_social_repository.dart';
import '../../domain/entities/friendship.dart';
import '../../domain/entities/user_search_hit.dart';
import '../../domain/repositories/social_repository.dart';
import '../../domain/usecases/social_usecases.dart';

final inMemorySocialRepositoryProvider = Provider<InMemorySocialRepository>((ref) {
  return InMemorySocialRepository(
    notifications: ref.watch(inMemoryNotificationRepositoryProvider),
  );
});

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return switch (config.backendMode) {
    BackendMode.firebase => FirestoreSocialRepository(
        ref.watch(firestoreProvider),
        writeClientNotifications: !config.usesCloudFunctions,
      ),
    BackendMode.local => ref.watch(inMemorySocialRepositoryProvider),
  };
});

final searchUsersProvider = Provider(
  (ref) => SearchUsers(ref.watch(socialRepositoryProvider)),
);

final getPublicProfileProvider = Provider(
  (ref) => GetPublicProfile(ref.watch(socialRepositoryProvider)),
);

final sendFriendRequestProvider = Provider(
  (ref) => SendFriendRequest(ref.watch(socialRepositoryProvider)),
);

final acceptFriendRequestProvider = Provider(
  (ref) => AcceptFriendRequest(ref.watch(socialRepositoryProvider)),
);

final rejectFriendRequestProvider = Provider(
  (ref) => RejectFriendRequest(ref.watch(socialRepositoryProvider)),
);

final cancelFriendRequestProvider = Provider(
  (ref) => CancelFriendRequest(ref.watch(socialRepositoryProvider)),
);

final removeFriendProvider = Provider(
  (ref) => RemoveFriend(ref.watch(socialRepositoryProvider)),
);

final inviteFriendToChallengeProvider = Provider(
  (ref) => InviteFriendToChallenge(ref.watch(socialRepositoryProvider)),
);

final _uidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.id,
);

/// Búsqueda con debounce.
final userSearchProvider = FutureProvider.autoDispose
    .family<UserSearchPage, String>((ref, query) async {
  var cancelled = false;
  ref.onDispose(() => cancelled = true);
  await Future<void>.delayed(const Duration(milliseconds: 350));
  if (cancelled) throw const _Cancelled();
  return ref.watch(searchUsersProvider)(query);
});

class _Cancelled implements Exception {
  const _Cancelled();
}

final publicProfileProvider = FutureProvider.autoDispose
    .family<UserProfile, String>((ref, userId) async {
  final result = await ref.watch(getPublicProfileProvider)(userId);
  return result.fold(
    onSuccess: (p) => p,
    onFailure: (f) => throw f,
  );
});

final publicStatsProvider = FutureProvider.autoDispose
    .family<UserStatistics, String>((ref, userId) async {
  final result = await ref
      .watch(socialRepositoryProvider)
      .getPublicStatistics(userId);
  return result.fold(onSuccess: (s) => s, onFailure: (f) => throw f);
});

final friendshipRelationProvider = FutureProvider.autoDispose
    .family<FriendshipRelation, String>((ref, otherUid) async {
  final uid = ref.watch(_uidProvider);
  if (uid == null) return FriendshipRelation.none;
  return ref.watch(socialRepositoryProvider).getRelation(
        currentUid: uid,
        otherUid: otherUid,
      );
});

final friendsListProvider = FutureProvider.autoDispose<List<Friendship>>((ref) async {
  final uid = ref.watch(_uidProvider);
  if (uid == null) return const [];
  final page = await ref.watch(socialRepositoryProvider).listFriends(uid: uid);
  return page.items;
});

final incomingRequestsProvider =
    FutureProvider.autoDispose<List<Friendship>>((ref) async {
  final uid = ref.watch(_uidProvider);
  if (uid == null) return const [];
  final page =
      await ref.watch(socialRepositoryProvider).listIncomingRequests(uid: uid);
  return page.items;
});

final friendsCountProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  uid,
) {
  return ref.watch(socialRepositoryProvider).countFriends(uid);
});

/// Ranking entre amigos usando la métrica oficial de Fase 5.
final friendsRankingProvider = FutureProvider.autoDispose
    .family<List<RankingEntry>, String?>((ref, categoryId) async {
  final uid = ref.watch(_uidProvider);
  if (uid == null) return const [];
  final friends = await ref.watch(friendsListProvider.future);
  final ids = <String>{
    uid,
    for (final f in friends) f.otherUserId(uid),
  }.toList();
  final scope = categoryId == null || categoryId.isEmpty
      ? RankingScopes.global
      : RankingScopes.category(categoryId);
  final entries = await ref.watch(leaderboardRepositoryProvider).getEntriesByUserIds(
        scopeKey: scope,
        userIds: ids,
      );
  final states = [
    for (final e in entries)
      ScopeEntryState(
        userId: e.userId,
        username: e.username,
        displayName: e.displayName,
        avatar: e.avatar,
        bestScore: e.bestScore,
        wins: e.wins,
        achievedAt: e.achievedAt,
        challengeId: e.challengeId,
      ),
  ]..sort(OfficialResultProcessor.compareEntries);
  return [
    for (var i = 0; i < states.length; i++)
      states[i].toEntry(
        position: OfficialResultProcessor.positionOf(states, i),
      ),
  ];
});
