import '../../../../core/error/result.dart';
import '../entities/social_activity.dart';
import '../entities/social_activity_type.dart';
import '../failures/activity_failure.dart';
import '../repositories/activity_repository.dart';

class GetFeed {
  const GetFeed(this._repo);
  final ActivityRepository _repo;

  Future<ActivityFeedPage> call({
    required String viewerUserId,
    required List<String> friendUserIds,
    int limit = 20,
    String? cursor,
  }) =>
      _repo.getFeed(
        viewerUserId: viewerUserId,
        friendUserIds: friendUserIds,
        limit: limit,
        cursor: cursor,
      );
}

class GetUserActivities {
  const GetUserActivities(this._repo);
  final ActivityRepository _repo;

  Future<ActivityFeedPage> call({
    required String userId,
    required String viewerUserId,
    required bool viewerIsFriend,
    int limit = 20,
    String? cursor,
  }) =>
      _repo.getUserActivities(
        userId: userId,
        viewerUserId: viewerUserId,
        viewerIsFriend: viewerIsFriend,
        limit: limit,
        cursor: cursor,
      );
}

class RecordJoinActivity {
  const RecordJoinActivity(this._repo);
  final ActivityRepository _repo;

  Future<Result<void>> call(SocialActivity activity) {
    if (activity.type != SocialActivityType.friendJoinedChallenge) {
      return Future.value(const Result.failure(ActivityFailure.notAllowed()));
    }
    return _repo.upsertJoinActivity(activity);
  }
}
