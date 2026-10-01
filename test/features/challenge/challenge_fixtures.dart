import 'package:foodreto/core/avatar/avatar_config.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge_event.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge_result.dart';
import 'package:foodreto/features/profile/domain/entities/user_profile.dart';

UserProfile profileFor(String uid, {String? name}) => UserProfile(
  uid: uid,
  username: 'user_$uid',
  displayName: name ?? 'Usuario $uid',
  avatar: AvatarConfig(style: 'adventurer', seed: 'seed-$uid'),
);

final ana = profileFor('a', name: 'Ana');
final beto = profileFor('b', name: 'Beto');
final caro = profileFor('c', name: 'Caro');

const alitas = NewChallenge(categoryId: 'alitas', title: 'Reto de alitas');

Challenge challengeWith({
  String id = 'c1',
  String host = 'a',
  ChallengeStatus status = ChallengeStatus.waiting,
  List<String> participants = const ['a'],
  int max = 4,
}) => Challenge(
  id: id,
  hostUserId: host,
  categoryId: 'alitas',
  inviteCode: 'AB23CD',
  status: status,
  maxParticipants: max,
  participantIds: participants,
);

var _eventSeq = 0;

ChallengeEvent eventFor(
  String uid, {
  ChallengeEventType type = ChallengeEventType.increment,
  String? id,
}) => ChallengeEvent(
  clientEventId: id ?? 'evt${(_eventSeq++).toString().padLeft(17, '0')}',
  userId: uid,
  type: type,
);

ResultEntry entry(String uid, int count, {String? name}) => ResultEntry(
  userId: uid,
  username: 'user_$uid',
  displayName: name ?? uid,
  avatar: const AvatarConfig(style: 'adventurer', seed: 'x'),
  count: count,
);
