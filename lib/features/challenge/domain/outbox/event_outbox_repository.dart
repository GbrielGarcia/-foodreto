import '../entities/challenge_event.dart';

/// Fila de la cola offline del contador.
class OutboxEvent {
  const OutboxEvent({
    required this.localId,
    required this.challengeId,
    required this.clientEventId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.createdAt,
    required this.status,
    required this.attempts,
    this.lastAttemptAt,
    this.lastError,
    this.syncedAt,
  });

  final int localId;
  final String challengeId;
  final String clientEventId;
  final String userId;
  final ChallengeEventType type;
  final int amount;
  final DateTime createdAt;
  final OutboxEventStatus status;
  final int attempts;
  final DateTime? lastAttemptAt;
  final String? lastError;
  final DateTime? syncedAt;

  int get delta => type.delta;

  ChallengeEvent toChallengeEvent() => ChallengeEvent(
    clientEventId: clientEventId,
    userId: userId,
    type: type,
    createdAt: createdAt,
  );
}

enum OutboxEventStatus { pending, syncing, synced, failed }

/// Persistencia de la cola offline. La UI no accede a Drift directamente.
abstract interface class EventOutboxRepository {
  Future<void> enqueue({
    required String challengeId,
    required ChallengeEvent event,
  });

  /// Pendientes (+ syncing recuperados) en orden de creación.
  Future<List<OutboxEvent>> pendingInOrder({String? challengeId});

  Stream<List<OutboxEvent>> watchPending({
    required String challengeId,
    required String userId,
  });

  /// Suma de deltas aún no sincronizados (para el contador inmediato).
  Stream<int> watchPendingDelta({
    required String challengeId,
    required String userId,
  });

  Future<void> markSyncing(int localId);

  Future<void> markSynced(int localId);

  Future<void> markFailed(int localId, String error);

  /// `syncing` antiguos → `pending` (app cerrada a medias).
  Future<int> recoverStaleSyncing({
    Duration olderThan = const Duration(minutes: 2),
  });

  /// Borra filas ya sincronizadas (no hace falta guardarlas).
  Future<void> purgeSynced();

  /// Solo eventos del [userId] (logout / cambio de cuenta).
  Future<void> deleteForUser(String userId);
}
