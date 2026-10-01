import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/avatar/avatar_config.dart';
import 'package:foodreto/features/activity/data/models/activity_dto.dart';
import 'package:foodreto/features/activity/data/repositories/in_memory_activity_repository.dart';
import 'package:foodreto/features/activity/domain/entities/activity_visibility.dart';
import 'package:foodreto/features/activity/domain/entities/social_activity.dart';
import 'package:foodreto/features/activity/domain/entities/social_activity_type.dart';
import 'package:foodreto/features/activity/domain/services/activity_ids.dart';
import 'package:foodreto/features/activity/domain/services/feed_merger.dart';
import 'package:foodreto/features/activity/domain/services/official_activity_builder.dart';
import 'package:foodreto/features/activity/domain/usecases/activity_usecases.dart';
import 'package:foodreto/features/activity/domain/failures/activity_failure.dart';
import 'package:foodreto/core/error/result.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge_result.dart';
import 'package:foodreto/features/challenge/domain/entities/result_processing_status.dart';
import 'package:foodreto/features/leaderboard/domain/services/official_result_processor.dart';
import 'package:foodreto/features/profile/domain/entities/user_profile.dart';

AvatarConfig get _av => const AvatarConfig(
      style: 'lorelei',
      seed: 's',
      options: {'backgroundColor': 'ffc53d'},
    );

SocialActivity _act(
  String id, {
  required String actor,
  required DateTime at,
  ActivityVisibility v = ActivityVisibility.public,
  SocialActivityType type = SocialActivityType.challengeCompleted,
}) =>
    SocialActivity(
      id: id,
      type: type,
      actorUserId: actor,
      actorUsername: actor,
      actorDisplayName: actor,
      actorAvatar: _av,
      visibility: v,
      createdAt: at,
      challengeId: 'c1',
      categoryId: 'sushi',
    );

void main() {
  group('SocialActivityType / IDs', () {
    test('parse y oficiales', () {
      expect(
        SocialActivityType.tryParse('challengeWon'),
        SocialActivityType.challengeWon,
      );
      expect(SocialActivityType.challengeWon.isOfficial, isTrue);
      expect(SocialActivityType.friendJoinedChallenge.isOfficial, isFalse);
    });

    test('ids determinísticos', () {
      expect(
        ActivityIds.challengeCompleted('c1', 'u1'),
        'c1_u1_challengeCompleted',
      );
      expect(ActivityIds.friendJoined('c1', 'u1'), 'c1_u1_friendJoinedChallenge');
    });
  });

  group('ActivityDto', () {
    test('roundtrip map', () {
      final a = _act('c1_u1_challengeCompleted', actor: 'u1', at: DateTime.utc(2026, 1, 2));
      final map = ActivityDto.toMap(a);
      final back = ActivityDto.fromMap(a.id, {
        ...map,
        'createdAt': a.createdAt,
        'actorAvatarOptions': a.actorAvatar.options,
      });
      expect(back?.type, a.type);
      expect(back?.actorUserId, 'u1');
      expect(back?.visibility, ActivityVisibility.public);
    });

    test('documento inválido → null', () {
      expect(ActivityDto.fromMap('x', {'type': 'nope'}), isNull);
      expect(ActivityDto.fromMap('x', null), isNull);
    });
  });

  group('FeedMerger', () {
    test('ordena createdAt DESC y dedupe', () {
      final a = _act('a', actor: 'u', at: DateTime.utc(2026, 1, 1));
      final b = _act('b', actor: 'u', at: DateTime.utc(2026, 1, 3));
      final dup = _act('a', actor: 'u', at: DateTime.utc(2026, 1, 1));
      final sorted = FeedMerger.dedupeAndSort([a, b, dup]);
      expect(sorted.map((e) => e.id), ['b', 'a']);
    });

    test('cursor estable', () {
      final encoded = ActivityCursor.encode(DateTime.utc(2026, 5, 1), 'id1');
      final decoded = ActivityCursor.decode(encoded)!;
      expect(decoded.id, 'id1');
      expect(decoded.createdAt, DateTime.utc(2026, 5, 1));
    });
  });

  group('InMemoryActivityRepository', () {
    late InMemoryActivityRepository repo;

    setUp(() {
      repo = InMemoryActivityRepository();
      final t0 = DateTime.utc(2026, 1, 10);
      repo.seed(_act('1', actor: 'me', at: t0));
      repo.seed(_act('2', actor: 'friend', at: t0.add(const Duration(hours: 1))));
      repo.seed(
        _act(
          '3',
          actor: 'stranger',
          at: t0.add(const Duration(hours: 2)),
          v: ActivityVisibility.public,
        ),
      );
      repo.seed(
        _act(
          '4',
          actor: 'stranger',
          at: t0.add(const Duration(hours: 3)),
          v: ActivityVisibility.friends,
        ),
      );
    });

    test('feed incluye propias, amigos y públicas; no friends de extraños', () async {
      final page = await repo.getFeed(
        viewerUserId: 'me',
        friendUserIds: ['friend'],
        limit: 20,
      );
      final ids = page.items.map((e) => e.id).toSet();
      expect(ids.contains('1'), isTrue);
      expect(ids.contains('2'), isTrue);
      expect(ids.contains('3'), isTrue);
      expect(ids.contains('4'), isFalse);
    });

    test('paginación por cursor', () async {
      final first = await repo.getFeed(
        viewerUserId: 'me',
        friendUserIds: ['friend'],
        limit: 2,
      );
      expect(first.items.length, 2);
      expect(first.hasMore, isTrue);
      final second = await repo.getFeed(
        viewerUserId: 'me',
        friendUserIds: ['friend'],
        limit: 2,
        cursor: first.nextCursor,
      );
      final allIds = {...first.items.map((e) => e.id), ...second.items.map((e) => e.id)};
      expect(allIds.length, greaterThanOrEqualTo(3));
      expect(
        first.items.map((e) => e.id).toSet().intersection(second.items.map((e) => e.id).toSet()),
        isEmpty,
      );
    });

    test('cliente no puede upsert oficiales vía join', () async {
      final official = _act(
        'x',
        actor: 'me',
        at: DateTime.utc(2026),
        type: SocialActivityType.challengeWon,
      );
      final result = await repo.upsertJoinActivity(official);
      expect(
        result.fold(onSuccess: (_) => null, onFailure: (f) => f),
        isA<ActivityNotAllowed>(),
      );
    });

    test('RecordJoinActivity rechaza tipos oficiales', () async {
      final useCase = RecordJoinActivity(repo);
      final r = await useCase(
        _act(
          'x',
          actor: 'me',
          at: DateTime.utc(2026),
          type: SocialActivityType.recordBroken,
        ),
      );
      expect(r, isA<Err<void>>());
    });
  });

  group('OfficialActivityBuilder', () {
    test('idempotente y no escribe retos private', () {
      final entries = [
        ResultEntry(
          userId: 'a',
          username: 'a',
          displayName: 'A',
          avatar: _av,
          count: 10,
        ),
        ResultEntry(
          userId: 'b',
          username: 'b',
          displayName: 'B',
          avatar: _av,
          count: 5,
        ),
      ];
      final result = ChallengeResult(
        challengeId: 'c9',
        hostUserId: 'a',
        categoryId: 'sushi',
        restaurantId: null,
        title: '',
        startedAt: DateTime.utc(2026),
        finishedAt: DateTime.utc(2026, 1, 2),
        entries: entries,
        winnerIds: ['a'],
        processingStatus: ResultProcessingStatus.official,
      );
      final diff = const OfficialResultProcessor().process(
        result: result,
        currentUserStats: const {},
        currentScopeEntries: const {},
        currentScopeRecords: const {},
        rankingEligible: true,
      );
      final acts = OfficialActivityBuilder.build(
        result: result,
        diff: diff,
        challengeVisibility: ChallengeVisibility.public,
      );
      expect(acts.where((a) => a.type == SocialActivityType.challengeCompleted).length, 2);
      expect(acts.where((a) => a.type == SocialActivityType.challengeWon).length, 1);
      expect(acts.map((a) => a.id).toSet().length, acts.length);

      final privateActs = OfficialActivityBuilder.build(
        result: result,
        diff: diff,
        challengeVisibility: ChallengeVisibility.private,
      );
      expect(privateActs, isEmpty);
    });
  });

  group('ActivityVisibility', () {
    test('private challenge → null', () {
      expect(
        ActivityVisibility.resolveOrNull(
          challenge: ChallengeVisibility.private,
          profile: ProfileVisibility.public,
        ),
        isNull,
      );
    });
  });
}
