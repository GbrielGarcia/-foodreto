import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/outbox/event_outbox_repository.dart';
import '../../domain/repositories/challenge_repository.dart';

/// Procesa la outbox en orden y la envía a Firestore con reintentos suaves.
class EventSyncService {
  EventSyncService({
    required EventOutboxRepository outbox,
    required ChallengeEventRepository remote,
    required bool Function() isOnline,
    required String? Function() currentUserId,
    this.maxAttempts = 5,
  }) : _outbox = outbox,
       _remote = remote,
       _isOnline = isOnline,
       _currentUserId = currentUserId;

  final EventOutboxRepository _outbox;
  final ChallengeEventRepository _remote;
  final bool Function() _isOnline;
  final String? Function() _currentUserId;
  final int maxAttempts;

  bool _running = false;

  /// Arranque: recupera `syncing` atascados y lanza un flush.
  Future<void> start() async {
    final recovered = await _outbox.recoverStaleSyncing();
    if (recovered > 0) {
      debugPrint('FoodReto: outbox recuperó $recovered eventos syncing');
    }
    await flush();
  }

  /// Sincroniza pendientes (opcionalmente de un reto).
  Future<void> flush({String? challengeId}) async {
    if (_running) return;
    if (!_isOnline()) return;
    final uid = _currentUserId();
    if (uid == null) return;

    _running = true;
    try {
      final pending = await _outbox.pendingInOrder(challengeId: challengeId);
      for (final event in pending) {
        if (!_isOnline()) break;
        // Mismo celular: el host encola eventos del companero (userId != uid).
        // Firestore rules validan que solo el host pueda escribirlos.
        if (event.attempts >= maxAttempts &&
            event.status == OutboxEventStatus.failed) {
          continue;
        }

        await _outbox.markSyncing(event.localId);
        final result = await _remote.recordEvent(
          event.challengeId,
          event.toChallengeEvent(),
        );
        await result.fold(
          onSuccess: (_) async {
            await _outbox.markSynced(event.localId);
          },
          onFailure: (failure) async {
            await _outbox.markFailed(
              event.localId,
              failure.code ?? failure.message,
            );
            debugPrint(
              'FoodReto: sync fallo ${event.clientEventId}: '
              '${failure.code} ${failure.message}',
            );
            await Future<void>.delayed(
              Duration(milliseconds: 200 * (event.attempts + 1).clamp(1, 8)),
            );
          },
        );
      }
      await _outbox.purgeSynced();
    } finally {
      _running = false;
    }
  }
}
