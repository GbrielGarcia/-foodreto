import '../../../../core/avatar/avatar_config.dart';
import 'ranking_scope.dart';

/// Titular (o co-titular) de un récord.
class RecordHolder {
  const RecordHolder({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.challengeId,
    required this.achievedAt,
  });

  final String userId;
  final String username;
  final String displayName;
  final AvatarConfig avatar;
  final String challengeId;
  final DateTime achievedAt;
}

/// Récord actual de un ámbito (`leaderboards/{scopeKey}`).
class FoodRecord {
  const FoodRecord({
    required this.scopeKey,
    required this.score,
    required this.holders,
    this.categoryId,
    this.restaurantId,
    this.updatedAt,
  });

  final String scopeKey;
  final int score;
  final List<RecordHolder> holders;
  final String? categoryId;
  final String? restaurantId;
  final DateTime? updatedAt;

  RankingScopeType get scopeType => RankingScopes.typeOf(scopeKey);

  bool get hasHolders => holders.isNotEmpty;
}

/// Entrada del historial (`recordHistory/{id}`).
class RecordHistoryEntry {
  const RecordHistoryEntry({
    required this.id,
    required this.scopeKey,
    required this.score,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.challengeId,
    required this.achievedAt,
    required this.eventType,
  });

  final String id;
  final String scopeKey;
  final int score;
  final String userId;
  final String username;
  final String displayName;
  final AvatarConfig avatar;
  final String challengeId;
  final DateTime achievedAt;

  /// `created` | `tied` | `broken`
  final String eventType;
}
