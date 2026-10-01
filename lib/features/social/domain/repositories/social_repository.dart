import '../../../../core/error/result.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/entities/user_statistics.dart';
import '../entities/challenge_invitation.dart';
import '../entities/friendship.dart';
import '../entities/user_search_hit.dart';

abstract interface class SocialRepository {
  Future<UserSearchPage> searchUsers({
    required String query,
    int limit = 20,
    String? cursor,
  });

  Future<Result<UserProfile>> getPublicProfile(String userId);

  Future<Result<UserStatistics>> getPublicStatistics(String userId);

  Future<FriendshipRelation> getRelation({
    required String currentUid,
    required String otherUid,
  });

  Future<Result<Friendship>> sendFriendRequest({
    required String fromUid,
    required UserProfile fromProfile,
    required UserProfile toProfile,
  });

  Future<Result<Friendship>> acceptFriendRequest({
    required String friendshipId,
    required String uid,
  });

  Future<Result<Friendship>> rejectFriendRequest({
    required String friendshipId,
    required String uid,
  });

  Future<Result<void>> cancelFriendRequest({
    required String friendshipId,
    required String uid,
  });

  Future<Result<void>> removeFriend({
    required String friendshipId,
    required String uid,
  });

  Future<({List<Friendship> items, String? nextCursor})> listFriends({
    required String uid,
    int limit = 30,
    String? cursor,
  });

  Future<({List<Friendship> items, String? nextCursor})> listIncomingRequests({
    required String uid,
    int limit = 30,
    String? cursor,
  });

  Future<({List<Friendship> items, String? nextCursor})> listOutgoingRequests({
    required String uid,
    int limit = 30,
    String? cursor,
  });

  Future<int> countFriends(String uid);

  Future<Result<ChallengeInvitation>> inviteFriendToChallenge({
    required String challengeId,
    required String fromUid,
    required String toUid,
    required String fromUsername,
    required String fromDisplayName,
    String challengeTitle = '',
  });

  Future<Result<void>> respondChallengeInvitation({
    required String invitationId,
    required String uid,
    required bool accept,
  });

  Future<List<ChallengeInvitation>> listChallengeInvitations({
    required String uid,
    int limit = 30,
  });
}
