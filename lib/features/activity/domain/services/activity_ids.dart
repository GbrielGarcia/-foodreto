import '../entities/social_activity_type.dart';

/// IDs deterministicos para idempotencia (reintentos / Functions).
abstract final class ActivityIds {
  static String forActorType({
    required String challengeId,
    required String userId,
    required SocialActivityType type,
  }) =>
      '${challengeId}_${userId}_${type.name}';

  static String challengeCompleted(String challengeId, String userId) =>
      forActorType(
        challengeId: challengeId,
        userId: userId,
        type: SocialActivityType.challengeCompleted,
      );

  static String challengeWon(String challengeId, String userId) => forActorType(
        challengeId: challengeId,
        userId: userId,
        type: SocialActivityType.challengeWon,
      );

  static String recordCreated(String challengeId, String userId) => forActorType(
        challengeId: challengeId,
        userId: userId,
        type: SocialActivityType.recordCreated,
      );

  static String recordBroken(String challengeId, String userId) => forActorType(
        challengeId: challengeId,
        userId: userId,
        type: SocialActivityType.recordBroken,
      );

  static String friendJoined(String challengeId, String userId) => forActorType(
        challengeId: challengeId,
        userId: userId,
        type: SocialActivityType.friendJoinedChallenge,
      );
}
