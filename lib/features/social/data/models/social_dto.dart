import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/entities/challenge_invitation.dart';
import '../../domain/entities/friendship.dart';
import '../../domain/entities/user_search_hit.dart';

abstract final class SocialDto {
  static FriendProfileSnapshot snapshotFromProfile(UserProfile p) =>
      FriendProfileSnapshot(
        userId: p.uid,
        username: p.username,
        displayName: p.displayName,
        avatarStyle: p.avatar.style,
        avatarSeed: p.avatar.seed,
      );

  static Map<String, Object?> snapshotToMap(FriendProfileSnapshot s) => {
        'userId': s.userId,
        'username': s.username,
        'displayName': s.displayName,
        'avatarStyle': s.avatarStyle,
        'avatarSeed': s.avatarSeed,
      };

  static FriendProfileSnapshot snapshotFromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const FriendProfileSnapshot(
        userId: '',
        username: '',
        displayName: '',
      );
    }
    return FriendProfileSnapshot(
      userId: data['userId'] as String? ?? '',
      username: data['username'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      avatarStyle: data['avatarStyle'] as String?,
      avatarSeed: data['avatarSeed'] as String?,
    );
  }

  static Friendship? friendshipFromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final statusRaw = data['status'] as String?;
    final status = FriendshipStatus.values.firstWhere(
      (s) => s.name == statusRaw,
      orElse: () => FriendshipStatus.cancelled,
    );
    final userIds = [
      for (final id in data['userIds'] as List? ?? const [])
        if (id is String) id,
    ];
    if (userIds.length < 2) return null;
    return Friendship(
      id: id,
      userIds: userIds,
      requesterId: data['requesterId'] as String? ?? '',
      addresseeId: data['addresseeId'] as String? ?? '',
      status: status,
      requester: snapshotFromMap(
        data['requester'] is Map
            ? Map<String, dynamic>.from(data['requester'] as Map)
            : null,
      ),
      addressee: snapshotFromMap(
        data['addressee'] is Map
            ? Map<String, dynamic>.from(data['addressee'] as Map)
            : null,
      ),
      createdAt: readTimestamp(data['createdAt']),
      updatedAt: readTimestamp(data['updatedAt']),
      acceptedAt: readTimestamp(data['acceptedAt']),
    );
  }

  static UserSearchHit? hitFromUserMap(String uid, Map<String, dynamic>? data) {
    if (data == null) return null;
    if (data['visibility'] == 'private') return null;
    if (data['isActive'] == false) return null;
    return UserSearchHit(
      uid: uid,
      username: data['username'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      avatar: AvatarConfig.fromData(
        style: data['avatarStyle'],
        seed: data['avatarSeed'],
        options: data['avatarOptions'],
      ),
    );
  }

  static ChallengeInvitation? invitationFromMap(
    String id,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final statusRaw = data['status'] as String?;
    final status = ChallengeInvitationStatus.values.firstWhere(
      (s) => s.name == statusRaw,
      orElse: () => ChallengeInvitationStatus.expired,
    );
    return ChallengeInvitation(
      id: id,
      challengeId: data['challengeId'] as String? ?? '',
      fromUserId: data['fromUserId'] as String? ?? '',
      toUserId: data['toUserId'] as String? ?? '',
      status: status,
      fromUsername: data['fromUsername'] as String? ?? '',
      fromDisplayName: data['fromDisplayName'] as String? ?? '',
      challengeTitle: data['challengeTitle'] as String? ?? '',
      createdAt: readTimestamp(data['createdAt']),
      respondedAt: readTimestamp(data['respondedAt']),
    );
  }
}
