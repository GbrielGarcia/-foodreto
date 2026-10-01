import '../../../../core/error/result.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/entities/user_statistics.dart';
import '../../../profile/domain/value_objects/username.dart';
import '../entities/challenge_invitation.dart';
import '../entities/friendship.dart';
import '../entities/user_search_hit.dart';
import '../failures/social_failure.dart';
import '../repositories/social_repository.dart';

class SearchUsers {
  const SearchUsers(this._repository);
  final SocialRepository _repository;

  Future<UserSearchPage> call(
    String raw, {
    int limit = 20,
    String? cursor,
  }) {
    final query = raw.trim();
    if (query.isEmpty) {
      return Future.value(const UserSearchPage(hits: []));
    }
    return _repository.searchUsers(query: query, limit: limit, cursor: cursor);
  }
}

class GetPublicProfile {
  const GetPublicProfile(this._repository);
  final SocialRepository _repository;

  Future<Result<UserProfile>> call(String userId) =>
      _repository.getPublicProfile(userId);
}

class GetPublicStatistics {
  const GetPublicStatistics(this._repository);
  final SocialRepository _repository;

  Future<Result<UserStatistics>> call(String userId) =>
      _repository.getPublicStatistics(userId);
}

class WatchFriendshipRelation {
  const WatchFriendshipRelation(this._repository);
  final SocialRepository _repository;

  Future<FriendshipRelation> call({
    required String currentUid,
    required String otherUid,
  }) =>
      _repository.getRelation(currentUid: currentUid, otherUid: otherUid);
}

class SendFriendRequest {
  const SendFriendRequest(this._repository);
  final SocialRepository _repository;

  Future<Result<Friendship>> call({
    required UserProfile from,
    required UserProfile to,
  }) {
    if (from.uid == to.uid) {
      return Future.value(const Result.failure(SocialSelfAction()));
    }
    return _repository.sendFriendRequest(
      fromUid: from.uid,
      fromProfile: from,
      toProfile: to,
    );
  }
}

class AcceptFriendRequest {
  const AcceptFriendRequest(this._repository);
  final SocialRepository _repository;

  Future<Result<Friendship>> call({
    required String friendshipId,
    required String uid,
  }) =>
      _repository.acceptFriendRequest(friendshipId: friendshipId, uid: uid);
}

class RejectFriendRequest {
  const RejectFriendRequest(this._repository);
  final SocialRepository _repository;

  Future<Result<Friendship>> call({
    required String friendshipId,
    required String uid,
  }) =>
      _repository.rejectFriendRequest(friendshipId: friendshipId, uid: uid);
}

class CancelFriendRequest {
  const CancelFriendRequest(this._repository);
  final SocialRepository _repository;

  Future<Result<void>> call({
    required String friendshipId,
    required String uid,
  }) =>
      _repository.cancelFriendRequest(friendshipId: friendshipId, uid: uid);
}

class RemoveFriend {
  const RemoveFriend(this._repository);
  final SocialRepository _repository;

  Future<Result<void>> call({
    required String friendshipId,
    required String uid,
  }) =>
      _repository.removeFriend(friendshipId: friendshipId, uid: uid);
}

class InviteFriendToChallenge {
  const InviteFriendToChallenge(this._repository);
  final SocialRepository _repository;

  Future<Result<ChallengeInvitation>> call({
    required String challengeId,
    required String fromUid,
    required String toUid,
    required String fromUsername,
    required String fromDisplayName,
    String challengeTitle = '',
  }) {
    if (fromUid == toUid) {
      return Future.value(const Result.failure(SocialSelfAction()));
    }
    return _repository.inviteFriendToChallenge(
      challengeId: challengeId,
      fromUid: fromUid,
      toUid: toUid,
      fromUsername: Username.normalize(fromUsername),
      fromDisplayName: fromDisplayName,
      challengeTitle: challengeTitle,
    );
  }
}

/// Normaliza query de búsqueda (quita @, lower).
String normalizeSearchQuery(String raw) {
  var q = raw.trim();
  if (q.startsWith('@')) q = q.substring(1);
  return q.toLowerCase();
}
