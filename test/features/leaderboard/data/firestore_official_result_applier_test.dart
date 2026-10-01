import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/avatar/avatar_config.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge_result.dart';
import 'package:foodreto/features/leaderboard/data/services/firestore_official_result_applier.dart';
import 'package:foodreto/features/leaderboard/domain/entities/ranking_scope.dart';
import 'package:foodreto/features/leaderboard/domain/services/official_result_processor.dart';

AvatarConfig get _av => const AvatarConfig(
      style: 'lorelei',
      seed: 't',
      options: {'backgroundColor': 'ffc53d'},
    );

ChallengeResult _result({
  String id = 'c1',
  required List<(String, int)> scores,
}) {
  final entries = [
    for (final (uid, count) in scores)
      ResultEntry(
        userId: uid,
        username: uid,
        displayName: uid.toUpperCase(),
        avatar: _av,
        count: count,
      ),
  ];
  return ChallengeResult(
    challengeId: id,
    hostUserId: scores.first.$1,
    categoryId: 'alitas',
    restaurantId: 'r1',
    finishedAt: DateTime.utc(2026, 1, 1),
    entries: entries,
    winnerIds: winnerIdsFromEntries(entries),
  );
}

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreOfficialResultApplier applier;

  setUp(() {
    db = FakeFirebaseFirestore();
    applier = FirestoreOfficialResultApplier(db);
  });

  Future<void> seedChallenge({
    required String id,
    required String host,
    List<String> participants = const ['a', 'b'],
    String visibility = 'public',
  }) async {
    await db.collection('challenges').doc(id).set({
      'hostUserId': host,
      'status': 'finished',
      'visibility': visibility,
      'participantIds': participants,
      'categoryId': 'alitas',
      'restaurantId': 'r1',
    });
  }

  test('aplica entries en global y categoría', () async {
    await seedChallenge(id: 'c1', host: 'a');
    final result = _result(scores: [('a', 10), ('b', 7)]);
    final diff = await applier.apply(
      result: result,
      visibility: ChallengeVisibility.public,
    );

    expect(diff.skipped, isFalse);
    expect(diff.winnerIds, ['a']);

    final globalEntry =
        await db.doc('leaderboards/global/entries/a').get();
    expect(globalEntry.data()?['amount'], 10);
    expect(globalEntry.data()?['wins'], 1);

    final catScope = RankingScopes.category('alitas');
    final catEntry =
        await db.doc('leaderboards/$catScope/entries/a').get();
    expect(catEntry.data()?['amount'], 10);

    final board = await db.doc('leaderboards/global').get();
    expect(board.data()?['topAmount'], 10);

    final processed = await db.doc('challengeResults/c1').get();
    // apply merges processingStatus even if doc didn't exist
    expect(processed.data()?['processingStatus'], 'official');
    expect(processed.data()?['winnerIds'], ['a']);

    final ledger = await db.doc('resultProcessing/c1').get();
    expect(ledger.data()?['contentHash'], isNotEmpty);
  });

  test('idempotente: segundo apply no duplica wins', () async {
    await seedChallenge(id: 'c1', host: 'a');
    final result = _result(scores: [('a', 10), ('b', 7)]);
    await applier.apply(
      result: result,
      visibility: ChallengeVisibility.public,
    );
    final second = await applier.apply(
      result: result,
      visibility: ChallengeVisibility.public,
    );
    expect(second.skipped, isTrue);

    final entry = await db.doc('leaderboards/global/entries/a').get();
    expect(entry.data()?['wins'], 1);
  });

  test('reto privado no escribe leaderboards pero sí stats', () async {
    await seedChallenge(id: 'c2', host: 'a', visibility: 'private');
    final result = _result(id: 'c2', scores: [('a', 5), ('b', 3)]);
    await applier.apply(
      result: result,
      visibility: ChallengeVisibility.private,
    );

    final global = await db.doc('leaderboards/global/entries/a').get();
    expect(global.exists, isFalse);

    final stats = await db.doc('userStatistics/a').get();
    expect(stats.data()?['challengeCount'], 1);
    expect(stats.data()?['winCount'], 1);
    expect(stats.data()?['bestScore'], 5);
  });

  test('contentHash estable', () {
    final r = _result(scores: [('a', 1), ('b', 2)]);
    expect(
      OfficialResultProcessor.contentHashOf(r),
      OfficialResultProcessor.contentHashOf(r),
    );
  });
}
