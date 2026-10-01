import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/network/connectivity_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/challenge_remote_data_source.dart';
import '../../data/local/caching_challenge_repository.dart';
import '../../data/local/challenge_local_cache.dart';
import '../../data/local/drift_event_outbox_repository.dart';
import '../../data/local/event_sync_service.dart';
import '../../data/local/offline_challenge_event_repository.dart';
import '../../data/repositories/firestore_challenge_repository.dart';
import '../../../activity/presentation/providers/activity_providers.dart';
import '../../../leaderboard/presentation/providers/leaderboard_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../data/repositories/in_memory_challenge_backend.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/challenge_participant.dart';
import '../../domain/entities/challenge_result.dart';
import '../../domain/outbox/event_outbox_repository.dart';
import '../../domain/repositories/challenge_repository.dart';
import '../../domain/usecases/challenge_usecases.dart';

// ---------------------------------------------------------------------------
// Repositorios y casos de uso
// ---------------------------------------------------------------------------

/// En modo local los tres repositorios comparten el mismo almacn.
final _inMemoryChallengeBackendProvider = Provider<InMemoryChallengeBackend>((
  ref,
) {
  final backend = InMemoryChallengeBackend(
    officialStats: ref.watch(inMemoryLeaderboardStoreProvider),
    activities: ref.watch(inMemoryActivityRepositoryProvider),
    notifications: ref.watch(inMemoryNotificationRepositoryProvider),
  );
  ref.onDispose(backend.dispose);
  return backend;
});

final _remoteDataSourceProvider = Provider(
  (ref) => ChallengeRemoteDataSource(ref.watch(firestoreProvider)),
);

final challengeLocalCacheProvider = Provider(
  (ref) => ChallengeLocalCache(ref.watch(appDatabaseProvider)),
);

final eventOutboxRepositoryProvider = Provider<EventOutboxRepository>((ref) {
  return DriftEventOutboxRepository(ref.watch(appDatabaseProvider));
});

final _firestoreEventRepositoryProvider = Provider(
  (ref) => FirestoreChallengeEventRepository(ref.watch(_remoteDataSourceProvider)),
);

final eventSyncServiceProvider = Provider<EventSyncService>((ref) {
  final service = EventSyncService(
    outbox: ref.watch(eventOutboxRepositoryProvider),
    remote: ref.watch(_firestoreEventRepositoryProvider),
    isOnline: () => ref.read(isOnlineProvider),
    currentUserId: () => ref.read(currentUidProvider),
  );
  // Arranque no bloqueante: recuperar syncing y flush.
  Future.microtask(service.start);
  ref.listen(isOnlineProvider, (prev, next) {
    if (next) Future.microtask(service.flush);
  });
  ref.listen(currentUidProvider, (prev, next) {
    if (next != null) Future.microtask(service.flush);
  });
  return service;
});

final _firestoreChallengeRepositoryProvider =
    Provider<FirestoreChallengeRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return FirestoreChallengeRepository(
    ref.watch(_remoteDataSourceProvider),
    // Functions on → no applier cliente (evita doble factura / writes).
    officialApplier:
        config.usesCloudFunctions ? null : ref.watch(officialResultApplierProvider),
  );
});

final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  return switch (ref.watch(appConfigProvider).backendMode) {
    BackendMode.firebase => CachingChallengeRepository(
      ref.watch(_firestoreChallengeRepositoryProvider),
      ref.watch(challengeLocalCacheProvider),
    ),
    BackendMode.local => ref.watch(_inMemoryChallengeBackendProvider),
  };
});

final challengeParticipantRepositoryProvider =
    Provider<ChallengeParticipantRepository>((ref) {
      return switch (ref.watch(appConfigProvider).backendMode) {
        BackendMode.firebase => CachingParticipantRepository(
          FirestoreChallengeParticipantRepository(
            ref.watch(_remoteDataSourceProvider),
          ),
          ref.watch(challengeLocalCacheProvider),
        ),
        BackendMode.local => ref.watch(_inMemoryChallengeBackendProvider),
      };
    });

final challengeEventRepositoryProvider = Provider<ChallengeEventRepository>((
  ref,
) {
  return switch (ref.watch(appConfigProvider).backendMode) {
    BackendMode.firebase => OfflineChallengeEventRepository(
      remote: ref.watch(_firestoreEventRepositoryProvider),
      outbox: ref.watch(eventOutboxRepositoryProvider),
      sync: ref.watch(eventSyncServiceProvider),
    ),
    BackendMode.local => ref.watch(_inMemoryChallengeBackendProvider),
  };
});

final createChallengeProvider = Provider(
  (ref) => CreateChallenge(ref.watch(challengeRepositoryProvider)),
);

final findChallengeByCodeProvider = Provider(
  (ref) => FindChallengeByCode(ref.watch(challengeRepositoryProvider)),
);

final joinChallengeProvider = Provider(
  (ref) => JoinChallenge(ref.watch(challengeRepositoryProvider)),
);

final leaveChallengeProvider = Provider(
  (ref) => LeaveChallenge(ref.watch(challengeRepositoryProvider)),
);

final changeChallengeStatusProvider = Provider(
  (ref) => ChangeChallengeStatus(ref.watch(challengeRepositoryProvider)),
);

final recordCounterEventProvider = Provider(
  (ref) => RecordCounterEvent(ref.watch(challengeEventRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Lecturas en vivo (un listener por reto, compartido por todas las pantallas)
// ---------------------------------------------------------------------------

final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider.select((auth) => auth.value?.id)),
);

final challengeProvider = StreamProvider.autoDispose.family<Challenge?, String>(
  (ref, id) => ref.watch(challengeRepositoryProvider).watchChallenge(id),
);

/// Participantes en vivo. Solo lo escuchan quienes forman parte del reto
/// (las reglas no dejan leer la lista a los dems).
final challengeParticipantsProvider = StreamProvider.autoDispose
    .family<List<ChallengeParticipant>, String>(
      (ref, id) => ref
          .watch(challengeParticipantRepositoryProvider)
          .watchParticipants(id),
    );

/// Delta local an no confirmado por Firestore (outbox pending/syncing/failed).
final pendingCounterDeltaProvider = StreamProvider.autoDispose
    .family<int, String>((ref, challengeId) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return Stream.value(0);
      return ref
          .watch(eventOutboxRepositoryProvider)
          .watchPendingDelta(challengeId: challengeId, userId: uid);
    });

/// Delta pendiente para un participante concreto (mismo celular / host).
final pendingCounterDeltaForUserProvider = StreamProvider.autoDispose
    .family<int, ({String challengeId, String userId})>((ref, key) {
      return ref.watch(eventOutboxRepositoryProvider).watchPendingDelta(
            challengeId: key.challengeId,
            userId: key.userId,
          );
    });

final challengeResultProvider = StreamProvider.autoDispose
    .family<ChallengeResult?, String>(
      (ref, id) => ref.watch(challengeRepositoryProvider).watchResult(id),
    );

/// Retos del usuario (historial basico y "retos activos" del inicio).
final myChallengesProvider = StreamProvider.autoDispose<List<Challenge>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(challengeRepositoryProvider).watchUserChallenges(uid);
});

/// Retos publicos abiertos para descubrir (Home / amigos).
final openPublicChallengesProvider =
    FutureProvider.autoDispose<List<Challenge>>((ref) async {
  final result = await ref
      .watch(challengeRepositoryProvider)
      .listOpenPublicChallenges(limit: 12);
  return result.fold(
    onSuccess: (list) => list,
    onFailure: (f) => throw f,
  );
});

/// Reto de un codigo de invitacion (para la pantalla de unirse).
final challengeByCodeProvider = FutureProvider.autoDispose
    .family<Challenge, String>((ref, code) async {
      final result = await ref.watch(findChallengeByCodeProvider)(code);
      return result.fold(
        onSuccess: (challenge) => challenge,
        onFailure: (failure) => throw failure,
      );
    }, retry: (_, _) => null);
