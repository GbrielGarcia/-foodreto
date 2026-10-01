import '../../../../core/error/result.dart';
import '../entities/social_activity.dart';

/// Lectura de actividades + escritura limitada (join) / upsert local-oficial.
abstract class ActivityRepository {
  /// Feed del usuario: propias + amigos (tope) + publicas, paginado.
  Future<ActivityFeedPage> getFeed({
    required String viewerUserId,
    required List<String> friendUserIds,
    int limit = 20,
    String? cursor,
  });

  Future<SocialActivity?> getActivity(String activityId);

  Future<ActivityFeedPage> getUserActivities({
    required String userId,
    required String viewerUserId,
    required bool viewerIsFriend,
    int limit = 20,
    String? cursor,
  });

  /// Actividades publicas asociadas a un restaurante.
  Future<ActivityFeedPage> getRestaurantActivities({
    required String restaurantId,
    int limit = 20,
    String? cursor,
  });

  /// Solo `friendJoinedChallenge` del propio actor (cliente).
  Future<Result<void>> upsertJoinActivity(SocialActivity activity);

  /// Escritura de actividades oficiales (modo local / tests). Firebase: Functions.
  Future<void> upsertOfficialActivities(Iterable<SocialActivity> activities);
}
