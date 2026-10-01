import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/error/result.dart';
import '../../../../core/firebase/firestore_collections.dart';
import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../../notifications/data/models/notification_dto.dart';
import '../../../notifications/domain/entities/app_notification.dart';
import '../../../notifications/domain/entities/notification_type.dart';
import '../../../notifications/domain/services/notification_ids.dart';
import '../../../notifications/domain/services/official_notification_builder.dart';
import '../../../profile/data/models/user_profile_dto.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/entities/user_statistics.dart';
import '../../../profile/domain/value_objects/username.dart';
import '../../domain/entities/challenge_invitation.dart';
import '../../domain/entities/friendship.dart';
import '../../domain/entities/user_search_hit.dart';
import '../../domain/failures/social_failure.dart';
import '../../domain/repositories/social_repository.dart';
import '../../domain/usecases/social_usecases.dart';
import '../models/social_dto.dart';

/// Lecturas/escrituras sociales en Firestore (sin Admin).
class FirestoreSocialRepository implements SocialRepository {
  FirestoreSocialRepository(
    this._db, {
    this.writeClientNotifications = true,
  });

  final FirebaseFirestore _db;

  /// False cuando Cloud Functions escriben notifs (evita doble write).
  final bool writeClientNotifications;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection(FirestoreCollections.usernames);

  CollectionReference<Map<String, dynamic>> get _friendships =>
      _db.collection(FirestoreCollections.friendships);

  CollectionReference<Map<String, dynamic>> get _invitations =>
      _db.collection(FirestoreCollections.challengeInvitations);

  CollectionReference<Map<String, dynamic>> get _stats =>
      _db.collection(FirestoreCollections.userStatistics);

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection(FirestoreCollections.notifications);

  @override
  Future<UserSearchPage> searchUsers({
    required String query,
    int limit = 20,
    String? cursor,
  }) async {
    final q = normalizeSearchQuery(query);
    if (q.isEmpty) return const UserSearchPage(hits: []);

    final hits = <UserSearchHit>[];
    final seen = <String>{};

    // 1) Username exacto (índice usernames).
    final exact = await _usernames.doc(q).get();
    final exactUid = exact.data()?['uid'] as String?;
    if (exactUid != null) {
      final user = await _users.doc(exactUid).get();
      final hit = SocialDto.hitFromUserMap(exactUid, user.data());
      if (hit != null) {
        hits.add(hit);
        seen.add(exactUid);
      }
    }

    // 2) Prefijo username + displayName (solo perfiles públicos).
    Query<Map<String, dynamic>> byUsername = _users
        .where('visibility', isEqualTo: 'public')
        .where('isActive', isEqualTo: true)
        .where('username', isGreaterThanOrEqualTo: q)
        .where('username', isLessThan: '$q\uf8ff')
        .orderBy('username')
        .limit(limit);

    Query<Map<String, dynamic>> byDisplay = _users
        .where('visibility', isEqualTo: 'public')
        .where('isActive', isEqualTo: true)
        .where('displayNameLower', isGreaterThanOrEqualTo: q)
        .where('displayNameLower', isLessThan: '$q\uf8ff')
        .orderBy('displayNameLower')
        .limit(limit);

    if (cursor != null) {
      byUsername = byUsername.startAfter([cursor]);
    }

    final usernameSnap = await byUsername.get();
    for (final doc in usernameSnap.docs) {
      if (seen.contains(doc.id)) continue;
      final hit = SocialDto.hitFromUserMap(doc.id, doc.data());
      if (hit != null) {
        hits.add(hit);
        seen.add(doc.id);
      }
    }

    final displaySnap = await byDisplay.get();
    for (final doc in displaySnap.docs) {
      if (seen.contains(doc.id)) continue;
      final hit = SocialDto.hitFromUserMap(doc.id, doc.data());
      if (hit != null) {
        hits.add(hit);
        seen.add(doc.id);
      }
    }

    final page = hits.take(limit).toList();
    return UserSearchPage(
      hits: page,
      nextCursor: page.length >= limit ? page.last.username : null,
    );
  }

  @override
  Future<Result<UserProfile>> getPublicProfile(String userId) async {
    try {
      final snap = await _users.doc(userId).get();
      final profile = UserProfileDto.fromMap(userId, snap.data());
      if (profile == null) return const Result.failure(SocialNotFound());
      if (profile.visibility == ProfileVisibility.private) {
        return const Result.failure(SocialPrivateProfile());
      }
      return Result.success(profile);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<UserStatistics>> getPublicStatistics(String userId) async {
    try {
      final profileResult = await getPublicProfile(userId);
      final denied = profileResult.fold(
        onSuccess: (_) => null,
        onFailure: (f) => f,
      );
      if (denied != null) return Result.failure(denied);
      final snap = await _stats.doc(userId).get();
      return Result.success(UserStatisticsDto.fromMap(snap.data()));
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<FriendshipRelation> getRelation({
    required String currentUid,
    required String otherUid,
  }) async {
    if (currentUid == otherUid) return FriendshipRelation.self;
    final id = Friendship.idFor(currentUid, otherUid);
    final snap = await _friendships.doc(id).get();
    final f = SocialDto.friendshipFromMap(id, snap.data());
    if (f == null ||
        f.status == FriendshipStatus.cancelled ||
        f.status == FriendshipStatus.rejected) {
      return FriendshipRelation.none;
    }
    if (f.status == FriendshipStatus.accepted) {
      return FriendshipRelation.friends;
    }
    if (f.requesterId == currentUid) return FriendshipRelation.outgoingPending;
    return FriendshipRelation.incomingPending;
  }

  @override
  Future<Result<Friendship>> sendFriendRequest({
    required String fromUid,
    required UserProfile fromProfile,
    required UserProfile toProfile,
  }) async {
    if (fromUid == toProfile.uid) {
      return const Result.failure(SocialSelfAction());
    }
    final id = Friendship.idFor(fromUid, toProfile.uid);
    final ref = _friendships.doc(id);
    try {
      await _db.runTransaction((tx) async {
        final existing = await tx.get(ref);
        final current = SocialDto.friendshipFromMap(id, existing.data());
        if (current != null &&
            (current.status == FriendshipStatus.pending ||
                current.status == FriendshipStatus.accepted)) {
          throw const _Dup();
        }
        tx.set(ref, {
          'userIds': fromUid.compareTo(toProfile.uid) < 0
              ? [fromUid, toProfile.uid]
              : [toProfile.uid, fromUid],
          'requesterId': fromUid,
          'addresseeId': toProfile.uid,
          'status': FriendshipStatus.pending.name,
          'requester': SocialDto.snapshotToMap(
            SocialDto.snapshotFromProfile(fromProfile),
          ),
          'addressee': SocialDto.snapshotToMap(
            SocialDto.snapshotFromProfile(toProfile),
          ),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      final snap = await ref.get();
      final friendship = SocialDto.friendshipFromMap(id, snap.data())!;
      // Spark: sin Functions, el remitente escribe la notificacion al destinatario.
      await _writeFriendRequestNotification(
        friendshipId: id,
        fromProfile: fromProfile,
        toUid: toProfile.uid,
      );
      return Result.success(friendship);
    } on _Dup {
      return const Result.failure(SocialDuplicate());
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  Future<void> _writeFriendRequestNotification({
    required String friendshipId,
    required UserProfile fromProfile,
    required String toUid,
  }) async {
    if (!writeClientNotifications) return;
    final n = OfficialNotificationBuilder.friendRequest(
      friendshipId: friendshipId,
      recipientUserId: toUid,
      actorUserId: fromProfile.uid,
      actorUsername: fromProfile.username,
      actorDisplayName: fromProfile.displayName,
      actorAvatar: fromProfile.avatar,
    );
    try {
      final ref = _notifications.doc(n.id);
      if ((await ref.get()).exists) return;
      await ref.set(_socialNotificationMap(n, friendshipId: friendshipId));
    } catch (_) {
      // La amistad ya quedo; la notificacion se puede reintentar luego.
    }
  }

  Future<void> _writeFriendAcceptedNotification(Friendship f) async {
    if (!writeClientNotifications) return;
    final n = AppNotification(
      id: NotificationIds.friendAccepted(f.id),
      recipientUserId: f.requesterId,
      type: NotificationType.friendRequestAccepted,
      actorUserId: f.addresseeId,
      actorUsername: f.addressee.username,
      actorDisplayName: f.addressee.displayName,
      actorAvatar: AvatarConfig.fromData(
        style: f.addressee.avatarStyle,
        seed: f.addressee.avatarSeed,
      ),
      title: 'Solicitud aceptada',
      body: '@${f.addressee.username} acepto tu solicitud de amistad',
      read: false,
      createdAt: DateTime.now().toUtc(),
      targetRoute: '/u/${f.addresseeId}',
    );
    try {
      final ref = _notifications.doc(n.id);
      if ((await ref.get()).exists) return;
      await ref.set(_socialNotificationMap(n, friendshipId: f.id));
    } catch (_) {}
  }

  Map<String, Object?> _socialNotificationMap(
    AppNotification n, {
    required String friendshipId,
  }) =>
      {
        ...NotificationDto.toMap(n),
        'friendshipId': friendshipId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      };

  Future<Result<Friendship>> _transition({
    required String friendshipId,
    required String uid,
    required FriendshipStatus from,
    required FriendshipStatus to,
    required bool Function(Friendship f) allowed,
  }) async {
    final ref = _friendships.doc(friendshipId);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final f = SocialDto.friendshipFromMap(friendshipId, snap.data());
        if (f == null) throw const _Missing();
        if (f.status != from || !allowed(f)) throw const _Forbidden();
        tx.update(ref, {
          'status': to.name,
          'updatedAt': FieldValue.serverTimestamp(),
          if (to == FriendshipStatus.accepted)
            'acceptedAt': FieldValue.serverTimestamp(),
        });
      });
      final snap = await ref.get();
      return Result.success(
        SocialDto.friendshipFromMap(friendshipId, snap.data())!,
      );
    } on _Missing {
      return const Result.failure(SocialNotFound());
    } on _Forbidden {
      return const Result.failure(SocialForbidden());
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<Friendship>> acceptFriendRequest({
    required String friendshipId,
    required String uid,
  }) async {
    final result = await _transition(
      friendshipId: friendshipId,
      uid: uid,
      from: FriendshipStatus.pending,
      to: FriendshipStatus.accepted,
      allowed: (f) => f.addresseeId == uid,
    );
    if (result case Success(:final value)) {
      await _writeFriendAcceptedNotification(value);
    }
    return result;
  }

  @override
  Future<Result<Friendship>> rejectFriendRequest({
    required String friendshipId,
    required String uid,
  }) =>
      _transition(
        friendshipId: friendshipId,
        uid: uid,
        from: FriendshipStatus.pending,
        to: FriendshipStatus.rejected,
        allowed: (f) => f.addresseeId == uid,
      );

  @override
  Future<Result<void>> cancelFriendRequest({
    required String friendshipId,
    required String uid,
  }) async {
    final r = await _transition(
      friendshipId: friendshipId,
      uid: uid,
      from: FriendshipStatus.pending,
      to: FriendshipStatus.cancelled,
      allowed: (f) => f.requesterId == uid,
    );
    return r.fold(
      onSuccess: (_) => const Result.success(null),
      onFailure: Result.failure,
    );
  }

  @override
  Future<Result<void>> removeFriend({
    required String friendshipId,
    required String uid,
  }) async {
    final r = await _transition(
      friendshipId: friendshipId,
      uid: uid,
      from: FriendshipStatus.accepted,
      to: FriendshipStatus.cancelled,
      allowed: (f) => f.involves(uid),
    );
    return r.fold(
      onSuccess: (_) => const Result.success(null),
      onFailure: Result.failure,
    );
  }

  @override
  Future<({List<Friendship> items, String? nextCursor})> listFriends({
    required String uid,
    int limit = 30,
    String? cursor,
  }) =>
      _listByStatus(
        uid: uid,
        status: FriendshipStatus.accepted,
        limit: limit,
        cursor: cursor,
      );

  @override
  Future<({List<Friendship> items, String? nextCursor})> listIncomingRequests({
    required String uid,
    int limit = 30,
    String? cursor,
  }) async {
    Query<Map<String, dynamic>> q = _friendships
        .where('addresseeId', isEqualTo: uid)
        .where('status', isEqualTo: FriendshipStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .limit(limit + 1);
    if (cursor != null) {
      final c = await _friendships.doc(cursor).get();
      if (c.exists) q = q.startAfterDocument(c);
    }
    final snap = await q.get();
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final page = hasMore ? docs.sublist(0, limit) : docs;
    return (
      items: [
        for (final d in page)
          if (SocialDto.friendshipFromMap(d.id, d.data()) case final f?) f,
      ],
      nextCursor: hasMore && page.isNotEmpty ? page.last.id : null,
    );
  }

  @override
  Future<({List<Friendship> items, String? nextCursor})> listOutgoingRequests({
    required String uid,
    int limit = 30,
    String? cursor,
  }) async {
    Query<Map<String, dynamic>> q = _friendships
        .where('requesterId', isEqualTo: uid)
        .where('status', isEqualTo: FriendshipStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .limit(limit + 1);
    if (cursor != null) {
      final c = await _friendships.doc(cursor).get();
      if (c.exists) q = q.startAfterDocument(c);
    }
    final snap = await q.get();
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final page = hasMore ? docs.sublist(0, limit) : docs;
    return (
      items: [
        for (final d in page)
          if (SocialDto.friendshipFromMap(d.id, d.data()) case final f?) f,
      ],
      nextCursor: hasMore && page.isNotEmpty ? page.last.id : null,
    );
  }

  Future<({List<Friendship> items, String? nextCursor})> _listByStatus({
    required String uid,
    required FriendshipStatus status,
    required int limit,
    String? cursor,
  }) async {
    Future<QuerySnapshot<Map<String, dynamic>>> run({
      required bool orderByUpdatedAt,
    }) async {
      Query<Map<String, dynamic>> q = _friendships
          .where('userIds', arrayContains: uid)
          .where('status', isEqualTo: status.name);
      if (orderByUpdatedAt) {
        q = q.orderBy('updatedAt', descending: true);
      }
      q = q.limit(limit + 1);
      if (cursor != null) {
        final c = await _friendships.doc(cursor).get();
        if (c.exists) q = q.startAfterDocument(c);
      }
      return q.get();
    }

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await run(orderByUpdatedAt: true);
    } on FirebaseException catch (e) {
      // Indice compuesto aun no desplegado.
      if (e.code == 'failed-precondition') {
        snap = await run(orderByUpdatedAt: false);
      } else {
        rethrow;
      }
    }

    final docs = [...snap.docs];
    docs.sort((a, b) {
      final ta = a.data()['updatedAt'];
      final tb = b.data()['updatedAt'];
      final da = ta is Timestamp ? ta.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
      final db = tb is Timestamp ? tb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
      final byTime = db.compareTo(da);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });

    final hasMore = docs.length > limit;
    final page = hasMore ? docs.sublist(0, limit) : docs;
    return (
      items: [
        for (final d in page)
          if (SocialDto.friendshipFromMap(d.id, d.data()) case final f?) f,
      ],
      nextCursor: hasMore && page.isNotEmpty ? page.last.id : null,
    );
  }

  @override
  Future<int> countFriends(String uid) async {
    final agg = await _friendships
        .where('userIds', arrayContains: uid)
        .where('status', isEqualTo: FriendshipStatus.accepted.name)
        .count()
        .get();
    return agg.count ?? 0;
  }

  @override
  Future<Result<ChallengeInvitation>> inviteFriendToChallenge({
    required String challengeId,
    required String fromUid,
    required String toUid,
    required String fromUsername,
    required String fromDisplayName,
    String challengeTitle = '',
  }) async {
    final relation = await getRelation(currentUid: fromUid, otherUid: toUid);
    if (relation != FriendshipRelation.friends) {
      return const Result.failure(SocialForbidden());
    }
    final id = '${challengeId}_$toUid';
    final ref = _invitations.doc(id);
    try {
      await _db.runTransaction((tx) async {
        final existing = await tx.get(ref);
        final cur = SocialDto.invitationFromMap(id, existing.data());
        if (cur != null && cur.status == ChallengeInvitationStatus.pending) {
          throw const _Dup();
        }
        tx.set(ref, {
          'challengeId': challengeId,
          'fromUserId': fromUid,
          'toUserId': toUid,
          'status': ChallengeInvitationStatus.pending.name,
          'fromUsername': Username.normalize(fromUsername),
          'fromDisplayName': fromDisplayName,
          'challengeTitle': challengeTitle,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      final snap = await ref.get();
      final invitation = SocialDto.invitationFromMap(id, snap.data())!;
      await _writeChallengeInvitationNotification(
        invitation: invitation,
        fromUsername: fromUsername,
        fromDisplayName: fromDisplayName,
      );
      return Result.success(invitation);
    } on _Dup {
      return const Result.failure(SocialDuplicate());
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  Future<void> _writeChallengeInvitationNotification({
    required ChallengeInvitation invitation,
    required String fromUsername,
    required String fromDisplayName,
  }) async {
    if (!writeClientNotifications) return;
    final nId = NotificationIds.challengeInvitation(
      invitation.challengeId,
      invitation.toUserId,
    );
    final title = 'Invitacion a reto';
    final body = invitation.challengeTitle.trim().isEmpty
        ? '@${Username.normalize(fromUsername)} te invito a un reto'
        : '@${Username.normalize(fromUsername)} te invito a ${invitation.challengeTitle}';
    try {
      final ref = _notifications.doc(nId);
      if ((await ref.get()).exists) return;
      await ref.set({
        'recipientUserId': invitation.toUserId,
        'type': NotificationType.challengeInvitation.name,
        'actorUserId': invitation.fromUserId,
        'actorUsername': Username.normalize(fromUsername),
        'actorDisplayName': fromDisplayName,
        'actorAvatarStyle': 'lorelei',
        'actorAvatarSeed': invitation.fromUserId,
        'actorAvatarOptions': <String, String>{},
        'title': title,
        'body': body,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'challengeId': invitation.challengeId,
        'targetRoute': '/challenges/${invitation.challengeId}',
      });
    } catch (_) {}
  }

  @override
  Future<Result<void>> respondChallengeInvitation({
    required String invitationId,
    required String uid,
    required bool accept,
  }) async {
    final ref = _invitations.doc(invitationId);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final inv = SocialDto.invitationFromMap(invitationId, snap.data());
        if (inv == null) throw const _Missing();
        if (inv.toUserId != uid ||
            inv.status != ChallengeInvitationStatus.pending) {
          throw const _Forbidden();
        }
        tx.update(ref, {
          'status': accept
              ? ChallengeInvitationStatus.accepted.name
              : ChallengeInvitationStatus.rejected.name,
          'respondedAt': FieldValue.serverTimestamp(),
        });
      });
      return const Result.success(null);
    } on _Missing {
      return const Result.failure(SocialNotFound());
    } on _Forbidden {
      return const Result.failure(SocialForbidden());
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<List<ChallengeInvitation>> listChallengeInvitations({
    required String uid,
    int limit = 30,
  }) async {
    final snap = await _invitations
        .where('toUserId', isEqualTo: uid)
        .where('status', isEqualTo: ChallengeInvitationStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [
      for (final d in snap.docs)
        if (SocialDto.invitationFromMap(d.id, d.data()) case final i?) i,
    ];
  }
}

class _Dup implements Exception {
  const _Dup();
}

class _Missing implements Exception {
  const _Missing();
}

class _Forbidden implements Exception {
  const _Forbidden();
}
