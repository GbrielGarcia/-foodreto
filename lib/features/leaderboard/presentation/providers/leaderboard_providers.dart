import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_leaderboard_repository.dart';
import '../../data/repositories/in_memory_leaderboard_repository.dart';
import '../../data/services/firestore_official_result_applier.dart';
import '../../domain/entities/food_record.dart';
import '../../domain/entities/ranking_entry.dart';
import '../../domain/entities/ranking_scope.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../../domain/usecases/leaderboard_usecases.dart';

/// Store local compartido (modo `local` / tests).
final inMemoryLeaderboardStoreProvider =
    Provider<InMemoryLeaderboardRepository>((ref) {
  return InMemoryLeaderboardRepository();
});

/// Spark: materializa rankings en el cliente (sin Cloud Functions).
final officialResultApplierProvider =
    Provider<FirestoreOfficialResultApplier>((ref) {
  return FirestoreOfficialResultApplier(ref.watch(firestoreProvider));
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return switch (ref.watch(appConfigProvider).backendMode) {
    BackendMode.firebase =>
      FirestoreLeaderboardRepository(ref.watch(firestoreProvider)),
    BackendMode.local => ref.watch(inMemoryLeaderboardStoreProvider),
  };
});

final getGlobalRankingProvider = Provider(
  (ref) => GetGlobalRanking(ref.watch(leaderboardRepositoryProvider)),
);

final getCategoryRankingProvider = Provider(
  (ref) => GetCategoryRanking(ref.watch(leaderboardRepositoryProvider)),
);

final getRestaurantCategoryRankingProvider = Provider(
  (ref) =>
      GetRestaurantCategoryRanking(ref.watch(leaderboardRepositoryProvider)),
);

final getUserRankingProvider = Provider(
  (ref) => GetUserRanking(ref.watch(leaderboardRepositoryProvider)),
);

final getRecentRecordsProvider = Provider(
  (ref) => GetRecentRecords(ref.watch(leaderboardRepositoryProvider)),
);

final getRecordProvider = Provider(
  (ref) => GetRecord(ref.watch(leaderboardRepositoryProvider)),
);

/// Invalida caches de ranking tras materializar un resultado oficial.
class LeaderboardEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final leaderboardEpochProvider =
    NotifierProvider<LeaderboardEpoch, int>(LeaderboardEpoch.new);

/// Spark: backfill de resultados pendientes del host. Una sola vez por sesión.
/// Con Cloud Functions no corre (el trigger `onChallengeResultCreated` basta).
final officialBackfillOnceProvider = FutureProvider<int>((ref) async {
  final uid = ref.watch(authStateProvider).value?.id;
  final config = ref.watch(appConfigProvider);
  if (uid == null || config.backendMode != BackendMode.firebase) return 0;
  if (config.usesCloudFunctions) return 0;
  try {
    final n =
        await ref.read(officialResultApplierProvider).backfillPendingForHost(uid);
    if (n > 0) {
      ref.read(leaderboardEpochProvider.notifier).bump();
    }
    return n;
  } catch (_) {
    return 0;
  }
});

/// Ranking paginado por scopeKey.
final rankingPageProvider = FutureProvider.autoDispose
    .family<RankingPage, ({String scopeKey, String? cursor})>((ref, args) async {
  // Epoch: fuerza recarga tras finish / backfill (sin keepAlive stale).
  ref.watch(leaderboardEpochProvider);

  return ref.watch(leaderboardRepositoryProvider).getRanking(
        scopeKey: args.scopeKey,
        cursor: args.cursor,
      );
});

final userRankingProvider = FutureProvider.autoDispose
    .family<UserRankingPosition, String>((ref, scopeKey) async {
  ref.watch(leaderboardEpochProvider);

  final uid = ref.watch(authStateProvider).value?.id;
  if (uid == null) {
    return UserRankingPosition(
      scopeKey: scopeKey,
      userId: '',
      position: null,
      bestScore: 0,
      wins: 0,
    );
  }
  return ref.watch(getUserRankingProvider)(scopeKey: scopeKey, userId: uid);
});

final recentRecordsProvider =
    FutureProvider.autoDispose<List<FoodRecord>>((ref) {
  ref.watch(leaderboardEpochProvider);
  return ref.watch(getRecentRecordsProvider)();
});

final scopeRecordProvider =
    FutureProvider.autoDispose.family<FoodRecord?, String>((ref, scopeKey) {
  ref.watch(leaderboardEpochProvider);
  return ref.watch(getRecordProvider)(scopeKey);
});

/// Helper scopes.
String globalScope() => RankingScopes.global;
String categoryScope(String categoryId) => RankingScopes.category(categoryId);
