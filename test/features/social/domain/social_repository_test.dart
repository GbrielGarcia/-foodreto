import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/avatar/avatar_config.dart';
import 'package:foodreto/core/error/result.dart';
import 'package:foodreto/features/leaderboard/data/repositories/in_memory_leaderboard_repository.dart';
import 'package:foodreto/features/leaderboard/domain/entities/ranking_scope.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge_result.dart';
import 'package:foodreto/features/profile/domain/entities/user_profile.dart';
import 'package:foodreto/features/profile/domain/entities/user_statistics.dart';
import 'package:foodreto/features/social/domain/entities/challenge_invitation.dart';
import 'package:foodreto/features/social/data/repositories/in_memory_social_repository.dart';
import 'package:foodreto/features/social/domain/entities/friendship.dart';
import 'package:foodreto/features/social/domain/failures/social_failure.dart';
import 'package:foodreto/features/social/domain/usecases/social_usecases.dart';

AvatarConfig get _av => const AvatarConfig(
  style: 'lorelei',
  seed: 's',
  options: {'backgroundColor': 'ffc53d'},
);

UserProfile _profile(String id, {ProfileVisibility v = ProfileVisibility.public}) =>
    UserProfile(
      uid: id,
      username: id,
      displayName: id.toUpperCase(),
      avatar: _av,
      visibility: v,
    );

void main() {
  late InMemorySocialRepository social;

  setUp(() {
    social = InMemorySocialRepository();
    social.seedProfile(_profile('alice'));
    social.seedProfile(_profile('bob'));
    social.seedProfile(_profile('cara'));
    social.seedProfile(
      _profile('dave', v: ProfileVisibility.private),
      const UserStatistics(challengeCount: 9, bestScore: 40),
    );
  });

  group('búsqueda', () {
    test('por username y paginación', () async {
      final page = await social.searchUsers(query: 'a', limit: 2);
      expect(page.hits, isNotEmpty);
      expect(page.hits.every((h) => h.username.startsWith('a') || h.displayName.toLowerCase().contains('a')), isTrue);
    });

    test('usuario inexistente', () async {
      final page = await social.searchUsers(query: 'zzz');
      expect(page.hits, isEmpty);
    });

    test('no muestra perfiles privados', () async {
      final page = await social.searchUsers(query: 'dave');
      expect(page.hits.where((h) => h.uid == 'dave'), isEmpty);
    });
  });

  group('solicitudes', () {
    test('enviar aceptar y no duplicar', () async {
      final a = _profile('alice');
      final b = _profile('bob');
      final sent = await social.sendFriendRequest(
        fromUid: a.uid,
        fromProfile: a,
        toProfile: b,
      );
      expect(sent, isA<Success<Friendship>>());
      final dup = await social.sendFriendRequest(
        fromUid: a.uid,
        fromProfile: a,
        toProfile: b,
      );
      expect(dup.fold(onSuccess: (_) => null, onFailure: (f) => f), isA<SocialDuplicate>());

      final id = Friendship.idFor('alice', 'bob');
      final accepted = await social.acceptFriendRequest(
        friendshipId: id,
        uid: 'bob',
      );
      expect(accepted.fold(onSuccess: (f) => f.isAccepted, onFailure: (_) => false), isTrue);
    });

    test('self-request', () async {
      final a = _profile('alice');
      final r = await SendFriendRequest(social)(from: a, to: a);
      expect(r.fold(onSuccess: (_) => null, onFailure: (f) => f), isA<SocialSelfAction>());
    });

    test('rechazar y cancelar', () async {
      final a = _profile('alice');
      final b = _profile('bob');
      await social.sendFriendRequest(fromUid: a.uid, fromProfile: a, toProfile: b);
      final id = Friendship.idFor('alice', 'bob');
      await social.rejectFriendRequest(friendshipId: id, uid: 'bob');
      expect(
        await social.getRelation(currentUid: 'alice', otherUid: 'bob'),
        FriendshipRelation.none,
      );

      await social.sendFriendRequest(fromUid: a.uid, fromProfile: a, toProfile: b);
      await social.cancelFriendRequest(friendshipId: id, uid: 'alice');
      expect(
        await social.getRelation(currentUid: 'alice', otherUid: 'bob'),
        FriendshipRelation.none,
      );
    });
  });

  group('amistad', () {
    test('listar y eliminar', () async {
      final a = _profile('alice');
      final b = _profile('bob');
      await social.sendFriendRequest(fromUid: a.uid, fromProfile: a, toProfile: b);
      final id = Friendship.idFor('alice', 'bob');
      await social.acceptFriendRequest(friendshipId: id, uid: 'bob');
      final list = await social.listFriends(uid: 'alice');
      expect(list.items.length, 1);
      await social.removeFriend(friendshipId: id, uid: 'alice');
      expect((await social.listFriends(uid: 'alice')).items, isEmpty);
    });
  });

  group('privacidad', () {
    test('perfil privado bloquea stats', () async {
      final r = await social.getPublicProfile('dave');
      expect(r.fold(onSuccess: (_) => null, onFailure: (f) => f), isA<SocialPrivateProfile>());
      final s = await social.getPublicStatistics('dave');
      expect(s.fold(onSuccess: (_) => null, onFailure: (f) => f), isA<SocialPrivateProfile>());
    });

    test('perfil público ok', () async {
      final r = await social.getPublicProfile('alice');
      expect(r.fold(onSuccess: (p) => p.username, onFailure: (_) => ''), 'alice');
    });
  });

  group('ranking amigos', () {
    test('orden oficial Fase 5', () async {
      final board = InMemoryLeaderboardRepository();
      board.applyResult(
        ChallengeResult(
          challengeId: 'c1',
          hostUserId: 'alice',
          categoryId: 'alitas',
          finishedAt: DateTime.utc(2026, 1, 1),
          entries: [
            ResultEntry(userId: 'alice', username: 'alice', displayName: 'A', avatar: _av, count: 10),
            ResultEntry(userId: 'bob', username: 'bob', displayName: 'B', avatar: _av, count: 12),
          ],
        ),
      );
      final a = _profile('alice');
      final b = _profile('bob');
      await social.sendFriendRequest(fromUid: a.uid, fromProfile: a, toProfile: b);
      await social.acceptFriendRequest(
        friendshipId: Friendship.idFor('alice', 'bob'),
        uid: 'bob',
      );
      final entries = await board.getEntriesByUserIds(
        scopeKey: RankingScopes.global,
        userIds: ['alice', 'bob'],
      );
      expect(entries.first.userId, 'bob');
      expect(entries.first.bestScore, 12);
    });
  });

  group('invitaciones', () {
    test('crear duplicado aceptar rechazar', () async {
      final a = _profile('alice');
      final b = _profile('bob');
      await social.sendFriendRequest(fromUid: a.uid, fromProfile: a, toProfile: b);
      await social.acceptFriendRequest(
        friendshipId: Friendship.idFor('alice', 'bob'),
        uid: 'bob',
      );
      final inv = await social.inviteFriendToChallenge(
        challengeId: 'ch1',
        fromUid: 'alice',
        toUid: 'bob',
        fromUsername: 'alice',
        fromDisplayName: 'A',
      );
      expect(inv, isA<Success<ChallengeInvitation>>());
      final dup = await social.inviteFriendToChallenge(
        challengeId: 'ch1',
        fromUid: 'alice',
        toUid: 'bob',
        fromUsername: 'alice',
        fromDisplayName: 'A',
      );
      expect(dup.fold(onSuccess: (_) => null, onFailure: (f) => f), isA<SocialDuplicate>());

      final id = inv.fold(onSuccess: (i) => i.id, onFailure: (_) => '');
      await social.respondChallengeInvitation(
        invitationId: id,
        uid: 'bob',
        accept: true,
      );
      final list = await social.listChallengeInvitations(uid: 'bob');
      expect(list.where((i) => i.status.name == 'pending'), isEmpty);
    });

    test('sin amistad no invita', () async {
      final r = await social.inviteFriendToChallenge(
        challengeId: 'ch1',
        fromUid: 'alice',
        toUid: 'cara',
        fromUsername: 'alice',
        fromDisplayName: 'A',
      );
      expect(r.fold(onSuccess: (_) => null, onFailure: (f) => f), isA<SocialForbidden>());
    });
  });

  test('id determinístico', () {
    expect(Friendship.idFor('b', 'a'), Friendship.idFor('a', 'b'));
  });
}
