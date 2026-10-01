import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../domain/entities/food_record.dart';
import '../../domain/entities/ranking_entry.dart';

abstract final class LeaderboardDto {
  static RankingEntry? entryFromMap(String userId, Map<String, dynamic>? data) {
    if (data == null) return null;
    final amount = (data['amount'] as num?)?.toInt() ?? 0;
    final achieved = readTimestamp(data['achievedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return RankingEntry(
      userId: userId,
      username: data['username'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      avatar: AvatarConfig.fromData(
        style: data['avatarStyle'],
        seed: data['avatarSeed'],
        options: data['avatarOptions'],
      ),
      bestScore: amount,
      wins: (data['wins'] as num?)?.toInt() ?? 0,
      achievedAt: achieved,
      challengeId: data['challengeId'] as String? ?? '',
    );
  }

  static FoodRecord? recordFromMap(String scopeKey, Map<String, dynamic>? data) {
    if (data == null) return null;
    final holdersRaw = data['topHolders'] as List? ?? const [];
    return FoodRecord(
      scopeKey: scopeKey,
      score: (data['topAmount'] as num?)?.toInt() ?? 0,
      categoryId: data['categoryId'] as String?,
      restaurantId: data['restaurantId'] as String?,
      updatedAt: readTimestamp(data['updatedAt']),
      holders: [
        for (final raw in holdersRaw)
          if (raw is Map)
            RecordHolder(
              userId: raw['userId'] as String? ?? '',
              username: raw['username'] as String? ?? '',
              displayName: raw['displayName'] as String? ?? '',
              avatar: AvatarConfig.fromData(
                style: raw['avatarStyle'],
                seed: raw['avatarSeed'],
                options: raw['avatarOptions'],
              ),
              challengeId: raw['challengeId'] as String? ?? '',
              achievedAt: readTimestamp(raw['achievedAt']) ??
                  DateTime.fromMillisecondsSinceEpoch(0),
            ),
      ],
    );
  }

  static RecordHistoryEntry? historyFromMap(
    String id,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    return RecordHistoryEntry(
      id: id,
      scopeKey: data['scopeKey'] as String? ?? '',
      score: (data['score'] as num?)?.toInt() ?? 0,
      userId: data['userId'] as String? ?? '',
      username: data['username'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      avatar: AvatarConfig.fromData(
        style: data['avatarStyle'],
        seed: data['avatarSeed'],
        options: data['avatarOptions'],
      ),
      challengeId: data['challengeId'] as String? ?? '',
      achievedAt: readTimestamp(data['achievedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      eventType: data['eventType'] as String? ?? 'created',
    );
  }

  /// Cursor opaco: userId del último elemento.
  static String? encodeCursor(String? userId) => userId;

  static String? decodeCursor(String? cursor) =>
      cursor == null || cursor.isEmpty ? null : cursor;
}

/// Campos de ordenación en Firestore para entries.
abstract final class LeaderboardOrder {
  static const amount = 'amount';
  static const wins = 'wins';
  static const achievedAt = 'achievedAt';
}
