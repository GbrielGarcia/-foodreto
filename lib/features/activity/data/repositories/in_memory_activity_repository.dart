import '../../../../core/error/result.dart';
import '../../domain/entities/activity_visibility.dart';
import '../../domain/entities/social_activity.dart';
import '../../domain/entities/social_activity_type.dart';
import '../../domain/failures/activity_failure.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/services/feed_merger.dart';

/// Store en memoria (modo local / tests).
class InMemoryActivityRepository implements ActivityRepository {
  InMemoryActivityRepository();

  final _items = <String, SocialActivity>{};

  /// Tope de amigos en el feed (alineado con Firestore `in` ? 30 incl. viewer).
  static const maxFeedFriends = 29;

  void seed(SocialActivity activity) => _items[activity.id] = activity;

  List<SocialActivity> get all => _items.values.toList();

  @override
  Future<SocialActivity?> getActivity(String activityId) async =>
      _items[activityId];

  @override
  Future<ActivityFeedPage> getFeed({
    required String viewerUserId,
    required List<String> friendUserIds,
    int limit = 20,
    String? cursor,
  }) async {
    final friendSet = friendUserIds.take(maxFeedFriends).toSet();
    final visible = _items.values.where((a) {
      if (a.actorUserId == viewerUserId) return true;
      if (a.visibility == ActivityVisibility.public) return true;
      if (a.visibility == ActivityVisibility.friends &&
          friendSet.contains(a.actorUserId)) {
        return true;
      }
      return false;
    });
    return _page(visible, limit: limit, cursor: cursor);
  }

  @override
  Future<ActivityFeedPage> getUserActivities({
    required String userId,
    required String viewerUserId,
    required bool viewerIsFriend,
    int limit = 20,
    String? cursor,
  }) async {
    final visible = _items.values.where((a) {
      if (a.actorUserId != userId) return false;
      if (userId == viewerUserId) return true;
      if (a.visibility == ActivityVisibility.public) return true;
      if (a.visibility == ActivityVisibility.friends && viewerIsFriend) {
        return true;
      }
      return false;
    });
    return _page(visible, limit: limit, cursor: cursor);
  }

  @override
  Future<ActivityFeedPage> getRestaurantActivities({
    required String restaurantId,
    int limit = 20,
    String? cursor,
  }) async {
    final visible = _items.values.where(
      (a) =>
          a.restaurantId == restaurantId &&
          a.visibility == ActivityVisibility.public,
    );
    return _page(visible, limit: limit, cursor: cursor);
  }

  ActivityFeedPage _page(
    Iterable<SocialActivity> source, {
    required int limit,
    String? cursor,
  }) {
    final decoded = ActivityCursor.decode(cursor);
    var sorted = FeedMerger.dedupeAndSort(source);
    if (decoded != null) {
      sorted = [
        for (final a in sorted)
          if (_afterCursor(a, decoded.createdAt, decoded.id)) a,
      ];
    }
    final hasMore = sorted.length > limit;
    final page = hasMore ? sorted.sublist(0, limit) : sorted;
    return ActivityFeedPage(
      items: page,
      nextCursor: hasMore && page.isNotEmpty
          ? ActivityCursor.encode(page.last.createdAt, page.last.id)
          : null,
    );
  }

  /// Tras cursor en orden createdAt DESC, id ASC.
  static bool _afterCursor(
    SocialActivity a,
    DateTime cursorAt,
    String cursorId,
  ) {
    final t = a.createdAt.compareTo(cursorAt);
    if (t < 0) return true;
    if (t > 0) return false;
    return a.id.compareTo(cursorId) > 0;
  }

  @override
  Future<Result<void>> upsertJoinActivity(SocialActivity activity) async {
    if (activity.type != SocialActivityType.friendJoinedChallenge) {
      return const Result.failure(ActivityFailure.notAllowed());
    }
    _items[activity.id] = activity;
    return const Result.success(null);
  }

  @override
  Future<void> upsertOfficialActivities(
    Iterable<SocialActivity> activities,
  ) async {
    for (final a in activities) {
      if (!a.type.isOfficial) continue;
      _items.putIfAbsent(a.id, () => a);
    }
  }
}
