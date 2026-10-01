import '../../../../core/avatar/avatar_config.dart';
import '../../../challenge/domain/entities/challenge.dart';
import '../../../challenge/domain/entities/challenge_result.dart';
import '../../../leaderboard/domain/entities/ranking_scope.dart';
import '../../../leaderboard/domain/services/official_result_processor.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../entities/activity_visibility.dart';
import '../entities/social_activity.dart';
import '../entities/social_activity_type.dart';
import 'activity_ids.dart';

/// Construye actividades oficiales a partir del diff de Fase 5 (puro / idempotente).
abstract final class OfficialActivityBuilder {
  static List<SocialActivity> build({
    required ChallengeResult result,
    required OfficialResultDiff diff,
    required ChallengeVisibility challengeVisibility,
    ProfileVisibility Function(String userId)? profileVisibilityOf,
    Map<String, int>? previousRecordScores,
    String? restaurantName,
    String? categoryName,
    String? categoryIcon,
  }) {
    if (diff.skipped) return const [];

    final achievedAt = result.finishedAt ?? DateTime.now().toUtc();
    final winnerIds = {...diff.winnerIds};
    final out = <SocialActivity>[];

    for (final e in result.entries) {
      final visibility = ActivityVisibility.resolveOrNull(
        challenge: challengeVisibility,
        profile: profileVisibilityOf?.call(e.userId) ??
            ProfileVisibility.public,
      );
      if (visibility == null) continue;
      out.add(
        _base(
          id: ActivityIds.challengeCompleted(result.challengeId, e.userId),
          type: SocialActivityType.challengeCompleted,
          entry: e,
          result: result,
          visibility: visibility,
          createdAt: achievedAt,
          score: e.count,
          restaurantName: restaurantName,
          categoryName: categoryName,
          categoryIcon: categoryIcon,
        ),
      );
      if (winnerIds.contains(e.userId)) {
        out.add(
          _base(
            id: ActivityIds.challengeWon(result.challengeId, e.userId),
            type: SocialActivityType.challengeWon,
            entry: e,
            result: result,
            visibility: visibility,
            createdAt: achievedAt,
            score: e.count,
            restaurantName: restaurantName,
            categoryName: categoryName,
            categoryIcon: categoryIcon,
          ),
        );
      }
    }

    // Un rcord por usuario/reto (scope categora), evita triplicar global/rest.
    final seenRecord = <String>{};
    for (final h in diff.historyEvents) {
      if (!h.scopeKey.startsWith('global:cat:')) continue;
      final type = h.eventType == 'broken'
          ? SocialActivityType.recordBroken
          : SocialActivityType.recordCreated;
      final id = type == SocialActivityType.recordBroken
          ? ActivityIds.recordBroken(h.challengeId, h.userId)
          : ActivityIds.recordCreated(h.challengeId, h.userId);
      if (!seenRecord.add(id)) continue;

      final visibility = ActivityVisibility.resolveOrNull(
        challenge: challengeVisibility,
        profile: profileVisibilityOf?.call(h.userId) ??
            ProfileVisibility.public,
      );
      if (visibility == null) continue;
      out.add(
        SocialActivity(
          id: id,
          type: type,
          actorUserId: h.userId,
          actorUsername: h.username,
          actorDisplayName: h.displayName,
          actorAvatar: h.avatar,
          visibility: visibility,
          createdAt: h.achievedAt,
          challengeId: h.challengeId,
          categoryId: result.categoryId,
          categoryName: categoryName,
          categoryIcon: categoryIcon,
          restaurantId: result.restaurantId,
          restaurantName: restaurantName,
          score: h.score,
          previousRecordScore: previousRecordScores?[h.userId],
          scopeKey: h.scopeKey.isEmpty
              ? RankingScopes.category(result.categoryId)
              : h.scopeKey,
        ),
      );
    }

    return FeedDedupe.byId(out);
  }

  static SocialActivity _base({
    required String id,
    required SocialActivityType type,
    required ResultEntry entry,
    required ChallengeResult result,
    required ActivityVisibility visibility,
    required DateTime createdAt,
    required int score,
    String? restaurantName,
    String? categoryName,
    String? categoryIcon,
  }) =>
      SocialActivity(
        id: id,
        type: type,
        actorUserId: entry.userId,
        actorUsername: entry.username,
        actorDisplayName: entry.displayName,
        actorAvatar: entry.avatar,
        visibility: visibility,
        createdAt: createdAt,
        challengeId: result.challengeId,
        categoryId: result.categoryId,
        categoryName: categoryName,
        categoryIcon: categoryIcon,
        restaurantId: result.restaurantId,
        restaurantName: restaurantName,
        score: score,
      );
}

abstract final class FeedDedupe {
  static List<SocialActivity> byId(List<SocialActivity> items) {
    final map = <String, SocialActivity>{};
    for (final a in items) {
      map.putIfAbsent(a.id, () => a);
    }
    return map.values.toList();
  }
}

/// Actividad de unin a reto (permitida al cliente con rules estrictas).
abstract final class JoinActivityFactory {
  static SocialActivity? create({
    required String challengeId,
    required String userId,
    required String username,
    required String displayName,
    required AvatarConfig avatar,
    required ChallengeVisibility challengeVisibility,
    required ProfileVisibility profileVisibility,
    required String categoryId,
    String? restaurantId,
    String? restaurantName,
    String? categoryName,
    String? categoryIcon,
    DateTime? createdAt,
  }) {
    final visibility = ActivityVisibility.resolveOrNull(
      challenge: challengeVisibility,
      profile: profileVisibility,
    );
    if (visibility == null) return null;
    return SocialActivity(
      id: ActivityIds.friendJoined(challengeId, userId),
      type: SocialActivityType.friendJoinedChallenge,
      actorUserId: userId,
      actorUsername: username,
      actorDisplayName: displayName,
      actorAvatar: avatar,
      visibility: visibility,
      createdAt: createdAt ?? DateTime.now().toUtc(),
      challengeId: challengeId,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );
  }
}
