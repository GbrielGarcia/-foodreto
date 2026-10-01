import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/error/result.dart';
import '../../../notifications/data/repositories/in_memory_notification_repository.dart';
import '../../../notifications/domain/entities/app_notification.dart';
import '../../../notifications/domain/entities/notification_type.dart';
import '../../../notifications/domain/services/notification_ids.dart';
import '../../../notifications/domain/services/official_notification_builder.dart';
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

/// Backend social en memoria (modo local + tests).
class InMemorySocialRepository implements SocialRepository {
  InMemorySocialRepository({InMemoryNotificationRepository? notifications})
      : _notifications = notifications;

  final InMemoryNotificationRepository? _notifications;
  final profiles = <String, UserProfile>{};
  final stats = <String, UserStatistics>{};
  final friendships = <String, Friendship>{};
  final invitations = <String, ChallengeInvitation>{};
  var _inviteSeq = 0;

  void seedProfile(UserProfile profile, [UserStatistics? statistics]) {
    profiles[profile.uid] = profile;
    if (statistics != null) stats[profile.uid] = statistics;
  }

  @override
  Future<UserSearchPage> searchUsers({
    required String query,
    int limit = 20,
    String? cursor,
  }) async {
    final q = normalizeSearchQuery(query);
    if (q.isEmpty) return const UserSearchPage(hits: []);

    final all = <UserSearchHit>[];
    for (final p in profiles.values) {
      if (!p.isActive || p.visibility != ProfileVisibility.public) continue;
      final uname = p.username;
      final dname = p.displayName.toLowerCase();
      if (uname.startsWith(q) || dname.contains(q) || uname == q) {
        all.add(
          UserSearchHit(
            uid: p.uid,
            username: p.username,
            displayName: p.displayName,
            avatar: p.avatar,
          ),
        );
      }
    }
    all.sort((a, b) => a.username.compareTo(b.username));
    var start = 0;
    if (cursor != null) {
      final idx = all.indexWhere((h) => h.uid == cursor);
      start = idx < 0 ? 0 : idx + 1;
    }
    final page = all.skip(start).take(limit).toList();
    final next = start + page.length < all.length && page.isNotEmpty
        ? page.last.uid
        : null;
    return UserSearchPage(hits: page, nextCursor: next);
  }

  @override
  Future<Result<UserProfile>> getPublicProfile(String userId) async {
    final p = profiles[userId];
    if (p == null) return const Result.failure(SocialNotFound());
    if (p.visibility == ProfileVisibility.private) {
      return const Result.failure(SocialPrivateProfile());
    }
    return Result.success(p);
  }

  @override
  Future<Result<UserStatistics>> getPublicStatistics(String userId) async {
    final p = profiles[userId];
    if (p == null) return const Result.failure(SocialNotFound());
    if (p.visibility == ProfileVisibility.private) {
      return const Result.failure(SocialPrivateProfile());
    }
    return Result.success(stats[userId] ?? UserStatistics.empty);
  }

  @override
  Future<FriendshipRelation> getRelation({
    required String currentUid,
    required String otherUid,
  }) async {
    if (currentUid == otherUid) return FriendshipRelation.self;
    final id = Friendship.idFor(currentUid, otherUid);
    final f = friendships[id];
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
    final existing = friendships[id];
    if (existing != null &&
        (existing.status == FriendshipStatus.pending ||
            existing.status == FriendshipStatus.accepted)) {
      return const Result.failure(SocialDuplicate());
    }
    final now = DateTime.now().toUtc();
    final friendship = Friendship(
      id: id,
      userIds: fromUid.compareTo(toProfile.uid) < 0
          ? [fromUid, toProfile.uid]
          : [toProfile.uid, fromUid],
      requesterId: fromUid,
      addresseeId: toProfile.uid,
      status: FriendshipStatus.pending,
      requester: SocialDto.snapshotFromProfile(fromProfile),
      addressee: SocialDto.snapshotFromProfile(toProfile),
      createdAt: now,
      updatedAt: now,
    );
    friendships[id] = friendship;
    await _notifications?.upsert(
      OfficialNotificationBuilder.friendRequest(
        friendshipId: id,
        recipientUserId: toProfile.uid,
        actorUserId: fromUid,
        actorUsername: fromProfile.username,
        actorDisplayName: fromProfile.displayName,
        actorAvatar: fromProfile.avatar,
        at: now,
      ),
    );
    return Result.success(friendship);
  }

  @override
  Future<Result<Friendship>> acceptFriendRequest({
    required String friendshipId,
    required String uid,
  }) async {
    final f = friendships[friendshipId];
    if (f == null) return const Result.failure(SocialNotFound());
    if (f.addresseeId != uid || f.status != FriendshipStatus.pending) {
      return const Result.failure(SocialForbidden());
    }
    final now = DateTime.now().toUtc();
    final updated = Friendship(
      id: f.id,
      userIds: f.userIds,
      requesterId: f.requesterId,
      addresseeId: f.addresseeId,
      status: FriendshipStatus.accepted,
      requester: f.requester,
      addressee: f.addressee,
      createdAt: f.createdAt,
      updatedAt: now,
      acceptedAt: now,
    );
    friendships[friendshipId] = updated;
    await _notifications?.upsert(
      AppNotification(
        id: NotificationIds.friendAccepted(friendshipId),
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
        body:
            '@${f.addressee.username} acept\u00f3 tu solicitud de amistad',
        read: false,
        createdAt: now,
        targetRoute: '/u/${f.addresseeId}',
      ),
    );
    return Result.success(updated);
  }

  @override
  Future<Result<Friendship>> rejectFriendRequest({
    required String friendshipId,
    required String uid,
  }) async {
    final f = friendships[friendshipId];
    if (f == null) return const Result.failure(SocialNotFound());
    if (f.addresseeId != uid || f.status != FriendshipStatus.pending) {
      return const Result.failure(SocialForbidden());
    }
    final updated = Friendship(
      id: f.id,
      userIds: f.userIds,
      requesterId: f.requesterId,
      addresseeId: f.addresseeId,
      status: FriendshipStatus.rejected,
      requester: f.requester,
      addressee: f.addressee,
      createdAt: f.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    friendships[friendshipId] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<void>> cancelFriendRequest({
    required String friendshipId,
    required String uid,
  }) async {
    final f = friendships[friendshipId];
    if (f == null) return const Result.failure(SocialNotFound());
    if (f.requesterId != uid || f.status != FriendshipStatus.pending) {
      return const Result.failure(SocialForbidden());
    }
    friendships[friendshipId] = Friendship(
      id: f.id,
      userIds: f.userIds,
      requesterId: f.requesterId,
      addresseeId: f.addresseeId,
      status: FriendshipStatus.cancelled,
      requester: f.requester,
      addressee: f.addressee,
      createdAt: f.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> removeFriend({
    required String friendshipId,
    required String uid,
  }) async {
    final f = friendships[friendshipId];
    if (f == null) return const Result.failure(SocialNotFound());
    if (!f.involves(uid) || f.status != FriendshipStatus.accepted) {
      return const Result.failure(SocialForbidden());
    }
    friendships[friendshipId] = Friendship(
      id: f.id,
      userIds: f.userIds,
      requesterId: f.requesterId,
      addresseeId: f.addresseeId,
      status: FriendshipStatus.cancelled,
      requester: f.requester,
      addressee: f.addressee,
      createdAt: f.createdAt,
      updatedAt: DateTime.now().toUtc(),
      acceptedAt: f.acceptedAt,
    );
    return const Result.success(null);
  }

  @override
  Future<({List<Friendship> items, String? nextCursor})> listFriends({
    required String uid,
    int limit = 30,
    String? cursor,
  }) async {
    final all = friendships.values
        .where((f) => f.isAccepted && f.involves(uid))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return _page(all, limit, cursor);
  }

  @override
  Future<({List<Friendship> items, String? nextCursor})> listIncomingRequests({
    required String uid,
    int limit = 30,
    String? cursor,
  }) async {
    final all = friendships.values
        .where((f) => f.status == FriendshipStatus.pending && f.addresseeId == uid)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return _page(all, limit, cursor);
  }

  @override
  Future<({List<Friendship> items, String? nextCursor})> listOutgoingRequests({
    required String uid,
    int limit = 30,
    String? cursor,
  }) async {
    final all = friendships.values
        .where((f) => f.status == FriendshipStatus.pending && f.requesterId == uid)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return _page(all, limit, cursor);
  }

  ({List<Friendship> items, String? nextCursor}) _page(
    List<Friendship> all,
    int limit,
    String? cursor,
  ) {
    var start = 0;
    if (cursor != null) {
      final idx = all.indexWhere((f) => f.id == cursor);
      start = idx < 0 ? 0 : idx + 1;
    }
    final page = all.skip(start).take(limit).toList();
    final next = start + page.length < all.length && page.isNotEmpty
        ? page.last.id
        : null;
    return (items: page, nextCursor: next);
  }

  @override
  Future<int> countFriends(String uid) async {
    return friendships.values
        .where((f) => f.isAccepted && f.involves(uid))
        .length;
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
    final dup = invitations.values.any(
      (i) =>
          i.challengeId == challengeId &&
          i.toUserId == toUid &&
          i.status == ChallengeInvitationStatus.pending,
    );
    if (dup) return const Result.failure(SocialDuplicate());
    _inviteSeq += 1;
    final inv = ChallengeInvitation(
      id: 'inv$_inviteSeq',
      challengeId: challengeId,
      fromUserId: fromUid,
      toUserId: toUid,
      status: ChallengeInvitationStatus.pending,
      fromUsername: Username.normalize(fromUsername),
      fromDisplayName: fromDisplayName,
      challengeTitle: challengeTitle,
      createdAt: DateTime.now().toUtc(),
    );
    invitations[inv.id] = inv;
    await _notifications?.upsert(
      AppNotification(
        id: NotificationIds.challengeInvitation(challengeId, toUid),
        recipientUserId: toUid,
        type: NotificationType.challengeInvitation,
        actorUserId: fromUid,
        actorUsername: Username.normalize(fromUsername),
        actorDisplayName: fromDisplayName,
        actorAvatar: const AvatarConfig(style: 'lorelei', seed: 'invite'),
        title: 'Invitaci\u00f3n a reto',
        body: challengeTitle.trim().isEmpty
            ? '@${Username.normalize(fromUsername)} te invit\u00f3 a un reto'
            : '@${Username.normalize(fromUsername)} te invit\u00f3 a $challengeTitle',
        read: false,
        createdAt: inv.createdAt ?? DateTime.now().toUtc(),
        challengeId: challengeId,
        targetRoute: '/challenges/$challengeId',
      ),
    );
    return Result.success(inv);
  }

  @override
  Future<Result<void>> respondChallengeInvitation({
    required String invitationId,
    required String uid,
    required bool accept,
  }) async {
    final inv = invitations[invitationId];
    if (inv == null) return const Result.failure(SocialNotFound());
    if (inv.toUserId != uid || inv.status != ChallengeInvitationStatus.pending) {
      return const Result.failure(SocialForbidden());
    }
    invitations[invitationId] = ChallengeInvitation(
      id: inv.id,
      challengeId: inv.challengeId,
      fromUserId: inv.fromUserId,
      toUserId: inv.toUserId,
      status: accept
          ? ChallengeInvitationStatus.accepted
          : ChallengeInvitationStatus.rejected,
      fromUsername: inv.fromUsername,
      fromDisplayName: inv.fromDisplayName,
      challengeTitle: inv.challengeTitle,
      createdAt: inv.createdAt,
      respondedAt: DateTime.now().toUtc(),
    );
    return const Result.success(null);
  }

  @override
  Future<List<ChallengeInvitation>> listChallengeInvitations({
    required String uid,
    int limit = 30,
  }) async {
    return invitations.values
        .where((i) => i.toUserId == uid)
        .take(limit)
        .toList();
  }
}
