import '../../../../core/error/result.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/challenge_participant.dart';
import '../../domain/entities/challenge_result.dart';
import '../../domain/repositories/challenge_repository.dart';
import 'challenge_local_cache.dart';

/// Delega en Firestore y guarda snapshots en Drift para lectura offline.
class CachingChallengeRepository implements ChallengeRepository {
  CachingChallengeRepository(this._remote, this._cache);

  final ChallengeRepository _remote;
  final ChallengeLocalCache _cache;

  @override
  Future<Result<Challenge>> createChallenge(
    NewChallenge data,
    UserProfile host,
  ) => _remote.createChallenge(data, host);

  @override
  Future<Result<Challenge?>> findByInviteCode(String code) =>
      _remote.findByInviteCode(code);

  @override
  Stream<Challenge?> watchChallenge(String challengeId) async* {
    try {
      await for (final challenge in _remote.watchChallenge(challengeId)) {
        if (challenge != null) await _cache.upsertChallenge(challenge);
        yield challenge;
      }
    } catch (_) {
      final cached = await _cache.readChallenge(challengeId);
      if (cached != null) {
        yield cached;
      } else {
        rethrow;
      }
    }
  }

  @override
  Stream<List<Challenge>> watchUserChallenges(String uid) =>
      _remote.watchUserChallenges(uid);

  @override
  Future<Result<List<Challenge>>> listPublicByRestaurant({
    required String restaurantId,
    int limit = 20,
  }) =>
      _remote.listPublicByRestaurant(
        restaurantId: restaurantId,
        limit: limit,
      );

  @override
  Future<Result<List<Challenge>>> listOpenPublicChallenges({int limit = 20}) =>
      _remote.listOpenPublicChallenges(limit: limit);

  @override
  Future<Result<void>> join(String challengeId, UserProfile user) =>
      _remote.join(challengeId, user);

  @override
  Future<Result<void>> leave(String challengeId, String uid) =>
      _remote.leave(challengeId, uid);

  @override
  Future<Result<void>> start(String challengeId, String uid) =>
      _remote.start(challengeId, uid);

  @override
  Future<Result<void>> cancel(String challengeId, String uid) =>
      _remote.cancel(challengeId, uid);

  @override
  Future<Result<void>> addSameDevicePartner(
    String challengeId,
    UserProfile partner,
  ) =>
      _remote.addSameDevicePartner(challengeId, partner);

  @override
  Future<Result<void>> confirmPartnerResult({
    required String challengeId,
    required String uid,
    required bool accept,
  }) =>
      _remote.confirmPartnerResult(
        challengeId: challengeId,
        uid: uid,
        accept: accept,
      );

  @override
  Future<Result<ChallengeResult>> finish(String challengeId, String uid) =>
      _remote.finish(challengeId, uid);

  @override
  Stream<ChallengeResult?> watchResult(String challengeId) =>
      _remote.watchResult(challengeId);
}

class CachingParticipantRepository implements ChallengeParticipantRepository {
  CachingParticipantRepository(this._remote, this._cache);

  final ChallengeParticipantRepository _remote;
  final ChallengeLocalCache _cache;

  @override
  Stream<List<ChallengeParticipant>> watchParticipants(
    String challengeId,
  ) async* {
    try {
      await for (final people in _remote.watchParticipants(challengeId)) {
        await _cache.upsertParticipants(challengeId, people);
        yield people;
      }
    } catch (_) {
      final cached = await _cache.readParticipants(challengeId);
      if (cached.isNotEmpty) {
        yield cached;
      } else {
        rethrow;
      }
    }
  }
}
