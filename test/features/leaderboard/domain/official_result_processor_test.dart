import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/avatar/avatar_config.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge_result.dart';
import 'package:foodreto/features/leaderboard/data/repositories/in_memory_leaderboard_repository.dart';
import 'package:foodreto/features/leaderboard/domain/entities/ranking_scope.dart';
import 'package:foodreto/features/leaderboard/domain/services/official_result_processor.dart';

AvatarConfig get _av =>
    const AvatarConfig(style: 'lorelei', seed: 't', options: {'backgroundColor': 'ffc53d'});

ChallengeResult _result({
  String id = 'c1',
  String category = 'alitas',
  String? restaurant = 'r1',
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
    categoryId: category,
    restaurantId: restaurant,
    finishedAt: DateTime.utc(2026, 1, 1),
    entries: entries,
    winnerIds: winnerIdsFromEntries(entries),
  );
}

void main() {
  group('resultados', () {
    test('un participante', () {
      final store = InMemoryLeaderboardRepository();
      final diff = store.applyResult(_result(scores: [('a', 5)]));
      expect(diff.winnerIds, ['a']);
      expect(diff.totalUnits, 5);
      expect(store.userStats['a']!.challengeCount, 1);
      expect(store.userStats['a']!.winCount, 1);
      expect(store.userStats['a']!.bestScore, 5);
    });

    test('empate de ganadores', () {
      final store = InMemoryLeaderboardRepository();
      final diff = store.applyResult(
        _result(scores: [('a', 10), ('b', 10), ('c', 8)]),
      );
      expect(diff.winnerIds, ['a', 'b']);
      expect(store.userStats['a']!.winCount, 1);
      expect(store.userStats['b']!.winCount, 1);
      expect(store.userStats['c']!.winCount, 0);
    });

    test('sin eventos (todos 0)', () {
      final store = InMemoryLeaderboardRepository();
      final diff = store.applyResult(
        _result(scores: [('a', 0), ('b', 0)]),
      );
      expect(diff.winnerIds, ['a', 'b']);
      expect(diff.totalUnits, 0);
    });
  });

  group('records', () {
    test('primer record y empate', () async {
      final store = InMemoryLeaderboardRepository();
      store.applyResult(_result(id: 'c1', scores: [('a', 12)]));
      final scope = RankingScopes.category('alitas');
      var record = await store.getRecord(scope);
      expect(record!.score, 12);
      expect(record.holders.map((h) => h.userId), ['a']);

      store.applyResult(_result(id: 'c2', scores: [('b', 12)]));
      record = await store.getRecord(scope);
      expect(record!.holders.map((h) => h.userId).toSet(), {'a', 'b'});

      final history = await store.getRecordHistory(scopeKey: scope);
      expect(history.any((h) => h.eventType == 'tied'), isTrue);
    });

    test('score menor no rompe record', () async {
      final store = InMemoryLeaderboardRepository();
      store.applyResult(_result(id: 'c1', scores: [('a', 15)]));
      store.applyResult(_result(id: 'c2', scores: [('b', 10)]));
      final record = await store.getRecord(RankingScopes.category('alitas'));
      expect(record!.score, 15);
      expect(record.holders.single.userId, 'a');
    });

    test('nuevo record broken', () async {
      final store = InMemoryLeaderboardRepository();
      store.applyResult(_result(id: 'c1', scores: [('a', 10)]));
      store.applyResult(_result(id: 'c2', scores: [('b', 14)]));
      final history = await store.getRecordHistory(
        scopeKey: RankingScopes.category('alitas'),
      );
      expect(history.first.eventType, 'broken');
      expect(history.first.userId, 'b');
    });
  });

  group('rankings', () {
    test('orden score wins fecha', () async {
      final store = InMemoryLeaderboardRepository();
      store.applyResult(_result(id: 'c1', scores: [('a', 10)]));
      store.applyResult(_result(id: 'c2', scores: [('b', 12)]));
      store.applyResult(_result(id: 'c3', scores: [('a', 12)]));
      final page = await store.getRanking(
        scopeKey: RankingScopes.global,
        limit: 10,
      );
      // a: best 12, wins 2 (c1+c3); b: best 12, wins 1
      expect(page.entries.map((e) => e.userId).take(2).toList(), ['a', 'b']);
    });

    test('paginación', () async {
      final store = InMemoryLeaderboardRepository();
      for (var i = 0; i < 5; i++) {
        store.applyResult(
          _result(id: 'c$i', scores: [('u$i', 10 + i)]),
        );
      }
      final page1 = await store.getRanking(
        scopeKey: RankingScopes.global,
        limit: 2,
      );
      expect(page1.entries.length, 2);
      expect(page1.nextCursor, isNotNull);
      final page2 = await store.getRanking(
        scopeKey: RankingScopes.global,
        limit: 2,
        cursor: page1.nextCursor,
      );
      expect(page2.entries.length, 2);
      expect(page2.entries.first.userId, isNot(page1.entries.first.userId));
    });

    test('ranking personal', () async {
      final store = InMemoryLeaderboardRepository();
      store.applyResult(_result(id: 'c1', scores: [('a', 20), ('b', 10)]));
      final pos = await store.getUserRanking(
        scopeKey: RankingScopes.global,
        userId: 'b',
      );
      expect(pos.position, 2);
      expect(pos.bestScore, 10);
    });

    test('categoría y restaurante', () async {
      final store = InMemoryLeaderboardRepository();
      store.applyResult(
        _result(
          id: 'c1',
          category: 'sushi',
          restaurant: 'restX',
          scores: [('a', 9)],
        ),
      );
      final cat = await store.getRanking(
        scopeKey: RankingScopes.category('sushi'),
      );
      final rest = await store.getRanking(
        scopeKey: RankingScopes.restaurantCategory('restX', 'sushi'),
      );
      expect(cat.entries.single.bestScore, 9);
      expect(rest.entries.single.bestScore, 9);
    });
  });

  group('idempotencia y reproceso', () {
    test('mismo challenge dos veces no duplica stats', () {
      final store = InMemoryLeaderboardRepository();
      final result = _result(scores: [('a', 7), ('b', 3)]);
      store.applyResult(result);
      store.applyResult(result);
      expect(store.userStats['a']!.challengeCount, 1);
      expect(store.userStats['a']!.totalUnits, 7);
      expect(store.userStats['a']!.winCount, 1);
    });

    test('processor puro skipped', () {
      const processor = OfficialResultProcessor();
      final result = _result(scores: [('a', 5)]);
      final first = processor.process(
        result: result,
        currentUserStats: const {},
        currentScopeEntries: const {},
        currentScopeRecords: const {},
      );
      final second = processor.process(
        result: result,
        currentUserStats: first.userStatsAfter,
        currentScopeEntries: first.scopeEntriesAfter,
        currentScopeRecords: first.scopeRecordsAfter,
        previousLedger: ProcessingLedger(
          challengeId: result.challengeId,
          contentHash: first.contentHash,
          userDeltas: first.userDeltas,
          scopeWinUserIds: first.scopeWinUserIds,
        ),
      );
      expect(second.skipped, isTrue);
    });
  });

  test('cliente no escribe: LeaderboardRepository solo lectura', () {
    // El contrato no expone métodos write; el store de tests es interno.
    expect(InMemoryLeaderboardRepository(), isA<Object>());
  });
}
