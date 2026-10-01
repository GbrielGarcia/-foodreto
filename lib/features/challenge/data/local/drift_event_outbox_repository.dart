import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables.dart';
import '../../domain/entities/challenge_event.dart';
import '../../domain/outbox/event_outbox_repository.dart';

class DriftEventOutboxRepository implements EventOutboxRepository {
  DriftEventOutboxRepository(this._db);

  final AppDatabase _db;

  static const _open = [
    OutboxStatus.pending,
    OutboxStatus.syncing,
    OutboxStatus.failed,
  ];

  @override
  Future<void> enqueue({
    required String challengeId,
    required ChallengeEvent event,
  }) async {
    await _db
        .into(_db.eventOutboxEntries)
        .insert(
          EventOutboxEntriesCompanion.insert(
            challengeId: challengeId,
            clientEventId: event.clientEventId,
            userId: event.userId,
            type: event.type.name,
            amount: const Value(ChallengeEvent.amount),
            createdAt: event.createdAt ?? DateTime.now(),
            status: OutboxStatus.pending,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<List<OutboxEvent>> pendingInOrder({String? challengeId}) async {
    final query = _db.select(_db.eventOutboxEntries)
      ..where((t) {
        final open = t.status.isInValues(_open);
        if (challengeId == null) return open;
        return open & t.challengeId.equals(challengeId);
      })
      ..orderBy([
        (t) => OrderingTerm.asc(t.createdAt),
        (t) => OrderingTerm.asc(t.localId),
      ]);
    return [for (final row in await query.get()) _map(row)];
  }

  @override
  Stream<List<OutboxEvent>> watchPending({
    required String challengeId,
    required String userId,
  }) {
    final query = _db.select(_db.eventOutboxEntries)
      ..where(
        (t) =>
            t.challengeId.equals(challengeId) &
            t.userId.equals(userId) &
            t.status.isInValues(_open),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map((rows) => [for (final row in rows) _map(row)]);
  }

  @override
  Stream<int> watchPendingDelta({
    required String challengeId,
    required String userId,
  }) {
    return watchPending(challengeId: challengeId, userId: userId).map(
      (events) => events.fold<int>(0, (sum, e) => sum + e.delta),
    );
  }

  @override
  Future<void> markSyncing(int localId) async {
    final row = await (_db.select(
      _db.eventOutboxEntries,
    )..where((t) => t.localId.equals(localId))).getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.eventOutboxEntries)
          ..where((t) => t.localId.equals(localId)))
        .write(
          EventOutboxEntriesCompanion(
            status: const Value(OutboxStatus.syncing),
            lastAttemptAt: Value(DateTime.now()),
            attempts: Value(row.attempts + 1),
          ),
        );
  }

  @override
  Future<void> markSynced(int localId) async {
    await (_db.update(_db.eventOutboxEntries)
          ..where((t) => t.localId.equals(localId)))
        .write(
          EventOutboxEntriesCompanion(
            status: const Value(OutboxStatus.synced),
            syncedAt: Value(DateTime.now()),
            lastError: const Value(null),
          ),
        );
  }

  @override
  Future<void> markFailed(int localId, String error) async {
    await (_db.update(_db.eventOutboxEntries)
          ..where((t) => t.localId.equals(localId)))
        .write(
          EventOutboxEntriesCompanion(
            status: const Value(OutboxStatus.failed),
            lastError: Value(error),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<int> recoverStaleSyncing({
    Duration olderThan = const Duration(minutes: 2),
  }) async {
    final cutoff = DateTime.now().subtract(olderThan);
    return (_db.update(_db.eventOutboxEntries)..where(
          (t) =>
              t.status.equalsValue(OutboxStatus.syncing) &
              (t.lastAttemptAt.isNull() |
                  t.lastAttemptAt.isSmallerThanValue(cutoff)),
        ))
        .write(
          const EventOutboxEntriesCompanion(
            status: Value(OutboxStatus.pending),
          ),
        );
  }

  @override
  Future<void> purgeSynced() async {
    await (_db.delete(_db.eventOutboxEntries)
          ..where((t) => t.status.equalsValue(OutboxStatus.synced)))
        .go();
  }

  @override
  Future<void> deleteForUser(String userId) async {
    await (_db.delete(
      _db.eventOutboxEntries,
    )..where((t) => t.userId.equals(userId))).go();
  }

  OutboxEvent _map(EventOutboxEntry row) => OutboxEvent(
    localId: row.localId,
    challengeId: row.challengeId,
    clientEventId: row.clientEventId,
    userId: row.userId,
    type: ChallengeEventType.fromId(row.type) ?? ChallengeEventType.increment,
    amount: row.amount,
    createdAt: row.createdAt,
    status: switch (row.status) {
      OutboxStatus.pending => OutboxEventStatus.pending,
      OutboxStatus.syncing => OutboxEventStatus.syncing,
      OutboxStatus.synced => OutboxEventStatus.synced,
      OutboxStatus.failed => OutboxEventStatus.failed,
    },
    attempts: row.attempts,
    lastAttemptAt: row.lastAttemptAt,
    lastError: row.lastError,
    syncedAt: row.syncedAt,
  );
}
