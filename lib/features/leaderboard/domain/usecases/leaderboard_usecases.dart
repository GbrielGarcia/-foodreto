import '../entities/food_record.dart';
import '../entities/ranking_entry.dart';
import '../entities/ranking_scope.dart';
import '../repositories/leaderboard_repository.dart';

class GetGlobalRanking {
  const GetGlobalRanking(this._repository);
  final LeaderboardRepository _repository;

  Future<RankingPage> call({int limit = 20, String? cursor}) =>
      _repository.getRanking(
        scopeKey: RankingScopes.global,
        limit: limit,
        cursor: cursor,
      );
}

class GetCategoryRanking {
  const GetCategoryRanking(this._repository);
  final LeaderboardRepository _repository;

  Future<RankingPage> call(
    String categoryId, {
    int limit = 20,
    String? cursor,
  }) =>
      _repository.getRanking(
        scopeKey: RankingScopes.category(categoryId),
        limit: limit,
        cursor: cursor,
      );
}

class GetRestaurantCategoryRanking {
  const GetRestaurantCategoryRanking(this._repository);
  final LeaderboardRepository _repository;

  Future<RankingPage> call(
    String restaurantId,
    String categoryId, {
    int limit = 20,
    String? cursor,
  }) =>
      _repository.getRanking(
        scopeKey: RankingScopes.restaurantCategory(restaurantId, categoryId),
        limit: limit,
        cursor: cursor,
      );
}

class GetUserRanking {
  const GetUserRanking(this._repository);
  final LeaderboardRepository _repository;

  Future<UserRankingPosition> call({
    required String scopeKey,
    required String userId,
  }) =>
      _repository.getUserRanking(scopeKey: scopeKey, userId: userId);
}

class GetRecord {
  const GetRecord(this._repository);
  final LeaderboardRepository _repository;

  Future<FoodRecord?> call(String scopeKey) => _repository.getRecord(scopeKey);
}

class GetRecordHistory {
  const GetRecordHistory(this._repository);
  final LeaderboardRepository _repository;

  Future<List<RecordHistoryEntry>> call(
    String scopeKey, {
    int limit = 20,
  }) =>
      _repository.getRecordHistory(scopeKey: scopeKey, limit: limit);
}

class GetRecentRecords {
  const GetRecentRecords(this._repository);
  final LeaderboardRepository _repository;

  Future<List<FoodRecord>> call({int limit = 10}) =>
      _repository.getRecentRecords(limit: limit);
}
