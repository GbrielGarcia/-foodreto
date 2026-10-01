import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/database/app_database.dart';
import 'package:foodreto/core/error/failure.dart';
import 'package:foodreto/core/error/result.dart';
import 'package:foodreto/features/challenge/data/local/drift_event_outbox_repository.dart';
import 'package:foodreto/features/challenge/data/local/event_sync_service.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge_event.dart';
import 'package:foodreto/features/challenge/domain/outbox/event_outbox_repository.dart';
import 'package:foodreto/features/challenge/domain/repositories/challenge_repository.dart';

class _FakeRemote implements ChallengeEventRepository {
  final writes = <String>[];
  Object? failOnce;
  int calls = 0;

  @override
  Future<Result<void>> recordEvent(
    String challengeId,
    ChallengeEvent event,
  ) async {
    calls++;
    if (failOnce != null && calls == 1) {
      failOnce = null;
      return const Result.failure(_Fail());
    }
    writes.add(event.clientEventId);
    return const Result.success(null);
  }

  @override
  Future<Result<List<ChallengeEvent>>> getEvents(String challengeId) async =>
      const Result.success([]);
}

class _Fail extends Failure {
  const _Fail() : super('boom', code: 'test');
}

ChallengeEvent _evt(
  String id, {
  String user = 'a',
  ChallengeEventType? type,
  DateTime? at,
}) => ChallengeEvent(
  clientEventId: id,
  userId: user,
  type: type ?? ChallengeEventType.increment,
  createdAt: at ?? DateTime.now(),
);

void main() {
  late AppDatabase db;
  late DriftEventOutboxRepository outbox;

  setUp(() {
    db = AppDatabase.memory();
    outbox = DriftEventOutboxRepository(db);
  });

  tearDown(() async => db.close());

  test('enqueue, pendientes, syncing, synced y purge', () async {
    await outbox.enqueue(
      challengeId: 'c1',
      event: _evt('id000000000000000001'),
    );
    var pending = await outbox.pendingInOrder();
    expect(pending, hasLength(1));
    expect(pending.first.status, OutboxEventStatus.pending);

    await outbox.markSyncing(pending.first.localId);
    pending = await outbox.pendingInOrder();
    expect(pending.first.status, OutboxEventStatus.syncing);
    expect(pending.first.attempts, 1);

    await outbox.markSynced(pending.first.localId);
    expect(await outbox.pendingInOrder(), isEmpty);
    await outbox.purgeSynced();
  });

  test('mismo clientEventId no duplica', () async {
    const id = 'id000000000000000002';
    await outbox.enqueue(challengeId: 'c1', event: _evt(id));
    await outbox.enqueue(challengeId: 'c1', event: _evt(id));
    expect(await outbox.pendingInOrder(), hasLength(1));
  });

  test('orden A B C por createdAt', () async {
    final t0 = DateTime(2026, 1, 1, 12);
    await outbox.enqueue(
      challengeId: 'c1',
      event: _evt('id00000000000000000A', at: t0),
    );
    await outbox.enqueue(
      challengeId: 'c1',
      event: _evt(
        'id00000000000000000B',
        at: t0.add(const Duration(seconds: 1)),
      ),
    );
    await outbox.enqueue(
      challengeId: 'c1',
      event: _evt(
        'id00000000000000000C',
        type: ChallengeEventType.decrement,
        at: t0.add(const Duration(seconds: 2)),
      ),
    );
    final ids = [
      for (final e in await outbox.pendingInOrder()) e.clientEventId,
    ];
    expect(ids, [
      'id00000000000000000A',
      'id00000000000000000B',
      'id00000000000000000C',
    ]);
  });

  test('recoverStaleSyncing vuelve a pending', () async {
    await outbox.enqueue(
      challengeId: 'c1',
      event: _evt('id000000000000000003'),
    );
    final id = (await outbox.pendingInOrder()).first.localId;
    await outbox.markSyncing(id);
    await (db.update(db.eventOutboxEntries)..where((t) => t.localId.equals(id)))
        .write(
          EventOutboxEntriesCompanion(
            lastAttemptAt: Value(
              DateTime.now().subtract(const Duration(minutes: 10)),
            ),
          ),
        );
    final n = await outbox.recoverStaleSyncing(
      olderThan: const Duration(minutes: 2),
    );
    expect(n, 1);
    expect(
      (await outbox.pendingInOrder()).first.status,
      OutboxEventStatus.pending,
    );
  });

  test('sync: primer fallo, segundo �xito; no mezcla usuarios', () async {
    final remote = _FakeRemote()..failOnce = 'boom';
    final sync = EventSyncService(
      outbox: outbox,
      remote: remote,
      isOnline: () => true,
      currentUserId: () => 'a',
    );
    await outbox.enqueue(
      challengeId: 'c1',
      event: _evt('id00000000000000000A'),
    );
    await outbox.enqueue(
      challengeId: 'c1',
      event: _evt('id00000000000000000X', user: 'b'),
    );
    await sync.flush();
    expect(remote.writes, isEmpty);
    await sync.flush();
    expect(remote.writes, ['id00000000000000000A']);
    expect(remote.writes, isNot(contains('id00000000000000000X')));
  });

  test('persistencia en la misma DB: pendientes sobreviven', () async {
    await outbox.enqueue(
      challengeId: 'c1',
      event: _evt('id000000000000000099'),
    );
    final again = DriftEventOutboxRepository(db);
    expect(await again.pendingInOrder(), hasLength(1));
  });

  test('watchPendingDelta suma increment/decrement', () async {
    await outbox.enqueue(
      challengeId: 'c1',
      event: _evt('id0000000000000000I1'),
    );
    await outbox.enqueue(
      challengeId: 'c1',
      event: _evt('id0000000000000000I2'),
    );
    await outbox.enqueue(
      challengeId: 'c1',
      event: _evt('id0000000000000000D1', type: ChallengeEventType.decrement),
    );
    final delta = await outbox
        .watchPendingDelta(challengeId: 'c1', userId: 'a')
        .first;
    expect(delta, 1);
  });
}
