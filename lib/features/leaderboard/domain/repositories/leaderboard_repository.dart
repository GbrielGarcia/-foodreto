import '../entities/food_record.dart';
import '../entities/ranking_entry.dart';

/// Lectura de rankings/récords oficiales. Sin métodos de escritura de cliente.
abstract interface class LeaderboardRepository {
  Future<RankingPage> getRanking({
    required String scopeKey,
    int limit = 20,
    String? cursor,
  });

  Future<UserRankingPosition> getUserRanking({
    required String scopeKey,
    required String userId,
  });

  Future<FoodRecord?> getRecord(String scopeKey);

  Future<List<RecordHistoryEntry>> getRecordHistory({
    required String scopeKey,
    int limit = 20,
  });

  /// Récords recientes (p. ej. Home). Lectura bajo demanda.
  Future<List<FoodRecord>> getRecentRecords({int limit = 10});

  /// Entradas de un scope para un conjunto de usuarios (ranking entre amigos).
  Future<List<RankingEntry>> getEntriesByUserIds({
    required String scopeKey,
    required List<String> userIds,
  });
}
