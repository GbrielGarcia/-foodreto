import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/result.dart';
import '../../../../core/firebase/firestore_collections.dart';
import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../domain/entities/activity_visibility.dart';
import '../../domain/entities/social_activity.dart';
import '../../domain/entities/social_activity_type.dart';
import '../../domain/failures/activity_failure.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/services/feed_merger.dart';
import '../models/activity_dto.dart';

/// Lectura Firestore del feed. Escritura oficial: solo Admin/Functions.
class FirestoreActivityRepository implements ActivityRepository {
  FirestoreActivityRepository(this._db);

  final FirebaseFirestore _db;

  /// Viewer + hasta 29 amigos = 30 (lmite `in` de Firestore).
  static const maxFeedFriends = 29;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestoreCollections.activities);

  @override
  Future<SocialActivity?> getActivity(String activityId) async {
    final snap = await _col.doc(activityId).get();
    return ActivityDto.fromMap(snap.id, snap.data());
  }

  @override
  Future<ActivityFeedPage> getFeed({
    required String viewerUserId,
    required List<String> friendUserIds,
    int limit = 20,
    String? cursor,
  }) async {
    // Tres queries acotadas a lo que `canReadActivity` garantiza:
    // - propias (actor == yo)
    // - de amigos con visibility == friends
    // - públicas globales
    // Un solo `actorUserId in [yo, amigos]` falla: rules no son filtros.
    final friendsOnly = friendUserIds
        .where((id) => id.isNotEmpty && id != viewerUserId)
        .take(maxFeedFriends)
        .toList();
    final friendIds = {viewerUserId, ...friendsOnly};
    final decoded = ActivityDto.decodeCursor(cursor);
    final fetchLimit = limit + 1;

    Future<QuerySnapshot<Map<String, dynamic>>> runOwn({
      required bool withOrder,
    }) async {
      Query<Map<String, dynamic>> q =
          _col.where('actorUserId', isEqualTo: viewerUserId);
      if (withOrder) {
        q = q
            .orderBy('createdAt', descending: true)
            .orderBy(FieldPath.documentId);
        q = _applyStart(q, decoded);
      }
      return q.limit(fetchLimit).get();
    }

    Future<QuerySnapshot<Map<String, dynamic>>?> runFriendsVis({
      required bool withOrder,
    }) async {
      if (friendsOnly.isEmpty) return null;
      Query<Map<String, dynamic>> q = _col
          .where('actorUserId', whereIn: friendsOnly)
          .where(
            'visibility',
            isEqualTo: ActivityVisibility.friends.name,
          );
      if (withOrder) {
        q = q
            .orderBy('createdAt', descending: true)
            .orderBy(FieldPath.documentId);
        q = _applyStart(q, decoded);
      }
      return q.limit(fetchLimit).get();
    }

    Future<QuerySnapshot<Map<String, dynamic>>> runPublic({
      required bool withOrder,
    }) async {
      Query<Map<String, dynamic>> q = _col.where(
        'visibility',
        isEqualTo: ActivityVisibility.public.name,
      );
      if (withOrder) {
        q = q
            .orderBy('createdAt', descending: true)
            .orderBy(FieldPath.documentId);
        q = _applyStart(q, decoded);
      }
      return q.limit(fetchLimit).get();
    }

    Future<List<QuerySnapshot<Map<String, dynamic>>>> runAll({
      required bool withOrder,
    }) async {
      final ownF = runOwn(withOrder: withOrder);
      final friendsF = runFriendsVis(withOrder: withOrder);
      final publicF = runPublic(withOrder: withOrder);
      final own = await ownF;
      final friendsSnap = await friendsF;
      final public = await publicF;
      return [
        own,
        ?friendsSnap,
        public,
      ];
    }

    List<QuerySnapshot<Map<String, dynamic>>> snaps;
    try {
      snaps = await runAll(withOrder: true);
    } on FirebaseException catch (e) {
      // Indice compuesto building / no desplegado.
      if (e.code == 'failed-precondition') {
        snaps = await runAll(withOrder: false);
      } else {
        rethrow;
      }
    }

    final mapped = <SocialActivity>[];
    for (final snap in snaps) {
      for (final doc in snap.docs) {
        final a = ActivityDto.fromMap(doc.id, doc.data());
        if (a == null) continue;
        if (!_visibleToViewer(
          a,
          viewerUserId: viewerUserId,
          friendIds: friendIds,
        )) {
          continue;
        }
        if (decoded != null &&
            !_afterCursor(a, decoded.createdAt, decoded.id)) {
          continue;
        }
        mapped.add(a);
      }
    }

    final sorted = FeedMerger.dedupeAndSort(mapped);
    final hasMore = sorted.length > limit;
    final page = hasMore ? sorted.sublist(0, limit) : sorted;
    return ActivityFeedPage(
      items: page,
      nextCursor: hasMore && page.isNotEmpty
          ? ActivityDto.encodeCursor(page.last)
          : null,
    );
  }

  Query<Map<String, dynamic>> _applyStart(
    Query<Map<String, dynamic>> query,
    ({DateTime createdAt, String id})? decoded,
  ) {
    if (decoded == null) return query;
    return query.startAfter([
      Timestamp.fromDate(decoded.createdAt),
      decoded.id,
    ]);
  }

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

  static bool _visibleToViewer(
    SocialActivity a, {
    required String viewerUserId,
    required Set<String> friendIds,
  }) {
    if (a.actorUserId == viewerUserId) return true;
    if (a.visibility == ActivityVisibility.public) return true;
    if (a.visibility == ActivityVisibility.friends &&
        friendIds.contains(a.actorUserId)) {
      return true;
    }
    return false;
  }

  @override
  Future<ActivityFeedPage> getUserActivities({
    required String userId,
    required String viewerUserId,
    required bool viewerIsFriend,
    int limit = 20,
    String? cursor,
  }) async {
    final decoded = ActivityDto.decodeCursor(cursor);
    final viewingSelf = userId == viewerUserId;

    Future<QuerySnapshot<Map<String, dynamic>>> run({
      required bool withOrder,
    }) async {
      Query<Map<String, dynamic>> query =
          _col.where('actorUserId', isEqualTo: userId);
      // Perfil ajeno: acotar visibility para que la query sea rules-safe.
      if (!viewingSelf) {
        if (viewerIsFriend) {
          query = query.where(
            'visibility',
            whereIn: [
              ActivityVisibility.public.name,
              ActivityVisibility.friends.name,
            ],
          );
        } else {
          query = query.where(
            'visibility',
            isEqualTo: ActivityVisibility.public.name,
          );
        }
      }
      if (withOrder) {
        query = query
            .orderBy('createdAt', descending: true)
            .orderBy(FieldPath.documentId);
        query = _applyStart(query, decoded);
      }
      return query.limit(limit + 1).get();
    }

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await run(withOrder: true);
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        snap = await run(withOrder: false);
      } else {
        rethrow;
      }
    }

    final items = <SocialActivity>[];
    for (final doc in snap.docs) {
      final a = ActivityDto.fromMap(doc.id, doc.data());
      if (a == null) continue;
      if (!_visibleToViewer(
        a,
        viewerUserId: viewerUserId,
        friendIds: {
          if (viewerIsFriend) userId,
          viewerUserId,
        },
      )) {
        continue;
      }
      if (decoded != null &&
          !_afterCursor(a, decoded.createdAt, decoded.id)) {
        continue;
      }
      items.add(a);
    }
    final sorted = FeedMerger.dedupeAndSort(items);
    final hasMore = sorted.length > limit;
    final page = hasMore ? sorted.sublist(0, limit) : sorted;
    return ActivityFeedPage(
      items: page,
      nextCursor: hasMore && page.isNotEmpty
          ? ActivityDto.encodeCursor(page.last)
          : null,
    );
  }

  @override
  Future<ActivityFeedPage> getRestaurantActivities({
    required String restaurantId,
    int limit = 20,
    String? cursor,
  }) async {
    final decoded = ActivityDto.decodeCursor(cursor);

    Future<QuerySnapshot<Map<String, dynamic>>> run({
      required bool withOrder,
    }) async {
      Query<Map<String, dynamic>> query = _col
          .where('restaurantId', isEqualTo: restaurantId)
          .where('visibility', isEqualTo: ActivityVisibility.public.name);
      if (withOrder) {
        query = query
            .orderBy('createdAt', descending: true)
            .orderBy(FieldPath.documentId);
        query = _applyStart(query, decoded);
      }
      return query.limit(limit + 1).get();
    }

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await run(withOrder: true);
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        snap = await run(withOrder: false);
      } else {
        rethrow;
      }
    }

    final items = <SocialActivity>[];
    for (final doc in snap.docs) {
      final a = ActivityDto.fromMap(doc.id, doc.data());
      if (a == null) continue;
      if (decoded != null &&
          !_afterCursor(a, decoded.createdAt, decoded.id)) {
        continue;
      }
      items.add(a);
    }
    final sorted = FeedMerger.dedupeAndSort(items);
    final hasMore = sorted.length > limit;
    final page = hasMore ? sorted.sublist(0, limit) : sorted;
    return ActivityFeedPage(
      items: page,
      nextCursor: hasMore && page.isNotEmpty
          ? ActivityDto.encodeCursor(page.last)
          : null,
    );
  }

  @override
  Future<Result<void>> upsertJoinActivity(SocialActivity activity) async {
    if (activity.type != SocialActivityType.friendJoinedChallenge) {
      return const Result.failure(ActivityFailure.notAllowed());
    }
    if (activity.challengeId == null || activity.challengeId!.isEmpty) {
      return const Result.failure(ActivityFailure.notAllowed());
    }
    try {
      await _col.doc(activity.id).set(
            ActivityDto.toJoinCreateMap(activity),
            SetOptions(merge: true),
          );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ActivityFailure.unknown(mapFirestoreError(e).message));
    }
  }

  @override
  Future<void> upsertOfficialActivities(
    Iterable<SocialActivity> activities,
  ) async {
    // Spark: el applier escribe en batch. Este metodo queda para modo local /
    // tests on-device; en Firebase REAL no-op (evita escrituras duplicadas).
  }
}
