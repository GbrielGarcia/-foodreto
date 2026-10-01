import '../../../../core/avatar/avatar_config.dart';
import 'activity_visibility.dart';
import 'social_activity_type.dart';

/// Hecho social derivado de un reto, resultado o record oficial.
class SocialActivity {
  const SocialActivity({
    required this.id,
    required this.type,
    required this.actorUserId,
    required this.actorUsername,
    required this.actorDisplayName,
    required this.actorAvatar,
    required this.visibility,
    required this.createdAt,
    this.challengeId,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.restaurantId,
    this.restaurantName,
    this.score,
    this.previousRecordScore,
    this.scopeKey,
  });

  final String id;
  final SocialActivityType type;
  final String actorUserId;
  final String actorUsername;
  final String actorDisplayName;
  final AvatarConfig actorAvatar;
  final ActivityVisibility visibility;
  final DateTime createdAt;

  final String? challengeId;
  final String? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? restaurantId;
  final String? restaurantName;
  final int? score;
  final int? previousRecordScore;
  final String? scopeKey;

  AvatarConfig get avatar => actorAvatar;
}

/// Pagina de feed con cursor estable (`createdAt` + `id`).
class ActivityFeedPage {
  const ActivityFeedPage({
    required this.items,
    this.nextCursor,
  });

  final List<SocialActivity> items;

  /// Cursor opaco para la siguiente pagina; null = no hay mas.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
