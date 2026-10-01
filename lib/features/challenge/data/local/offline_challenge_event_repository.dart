import '../../../../core/error/result.dart';
import '../../domain/entities/challenge_event.dart';
import '../../domain/outbox/event_outbox_repository.dart';
import '../../domain/repositories/challenge_repository.dart';
import 'event_sync_service.dart';

/// Contador offline-first: escribe en Drift (outbox) y dispara sync.
///
/// Firestore sigue siendo el remoto compartido; Drift no sustituye las rules.
class OfflineChallengeEventRepository implements ChallengeEventRepository {
  OfflineChallengeEventRepository({
    required ChallengeEventRepository remote,
    required EventOutboxRepository outbox,
    required EventSyncService sync,
  }) : _remote = remote,
       _outbox = outbox,
       _sync = sync;

  final ChallengeEventRepository _remote;
  final EventOutboxRepository _outbox;
  final EventSyncService _sync;

  @override
  Future<Result<void>> recordEvent(
    String challengeId,
    ChallengeEvent event,
  ) async {
    // 1) Persistencia real offline (no "fake success").
    await _outbox.enqueue(
      challengeId: challengeId,
      event: ChallengeEvent(
        clientEventId: event.clientEventId,
        userId: event.userId,
        type: event.type,
        createdAt: event.createdAt ?? DateTime.now(),
      ),
    );
    // 2) Intento inmediato si hay red; si falla, queda en outbox.
    await _sync.flush(challengeId: challengeId);
    return const Result.success(null);
  }

  @override
  Future<Result<List<ChallengeEvent>>> getEvents(String challengeId) =>
      _remote.getEvents(challengeId);
}
