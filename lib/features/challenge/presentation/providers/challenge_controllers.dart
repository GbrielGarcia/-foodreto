import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../leaderboard/presentation/providers/leaderboard_providers.dart';
import '../../../profile/domain/failures/profile_failure.dart';
import '../../../profile/presentation/providers/profile_controllers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/services/guest_account_service.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/challenge_event.dart';
import '../../domain/failures/challenge_failure.dart';
import 'challenge_providers.dart';

export '../../../profile/presentation/providers/profile_controllers.dart'
    show SaveState, SaveStatus;

/// Crear un reto. Devuelve el reto creado para navegar a su sala.
class CreateChallengeController extends Notifier<SaveState> {
  @override
  SaveState build() => SaveState.idle;

  Future<Challenge?> create(NewChallenge data) async {
    if (state.isSaving) return null;
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) {
      state = const SaveState(SaveStatus.error, ProfileFailure.notFound());
      return null;
    }
    state = const SaveState(SaveStatus.saving);

    var payload = data;
    if (data.sameDevicePlay &&
        (data.sameDevicePartnerId == null ||
            data.sameDevicePartnerId!.isEmpty) &&
        data.sameDeviceGuestEmail != null) {
      final guest = await GuestAccountService().register(
        displayName: data.sameDeviceGuestName ?? 'Invitado',
        email: data.sameDeviceGuestEmail!,
        password: data.sameDeviceGuestPassword ?? '',
      );
      final guestProfile = guest.fold(
        onSuccess: (p) => p,
        onFailure: (f) {
          if (!ref.mounted) return null;
          state = SaveState(SaveStatus.error, f);
          return null;
        },
      );
      if (guestProfile == null) return null;
      payload = NewChallenge(
        categoryId: data.categoryId,
        restaurantId: data.restaurantId,
        title: data.title,
        description: data.description,
        visibility: data.visibility,
        maxParticipants: data.maxParticipants,
        sameDevicePlay: true,
        sameDevicePartnerId: guestProfile.uid,
        sameDevicePartnerIds: [guestProfile.uid],
      );
    }

    final result = await ref.read(createChallengeProvider)(payload, profile);
    if (!ref.mounted) return null;
    return result.fold(
      onSuccess: (challenge) {
        state = const SaveState(SaveStatus.saved);
        return challenge;
      },
      onFailure: (failure) {
        state = SaveState(SaveStatus.error, failure);
        return null;
      },
    );
  }
}

final createChallengeControllerProvider =
    NotifierProvider.autoDispose<CreateChallengeController, SaveState>(
      CreateChallengeController.new,
    );

/// Unirse a un reto ya localizado por código.
class JoinChallengeController extends Notifier<SaveState> {
  @override
  SaveState build() => SaveState.idle;

  Future<bool> join(Challenge challenge) async {
    if (state.isSaving) return false;
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) {
      state = const SaveState(SaveStatus.error, ProfileFailure.notFound());
      return false;
    }
    state = const SaveState(SaveStatus.saving);
    final result = await ref.read(joinChallengeProvider)(challenge, profile);
    if (!ref.mounted) return result.isSuccess;
    state = result.fold(
      onSuccess: (_) => const SaveState(SaveStatus.saved),
      onFailure: (failure) => SaveState(SaveStatus.error, failure),
    );
    return result.isSuccess;
  }
}

final joinChallengeControllerProvider =
    NotifierProvider.autoDispose<JoinChallengeController, SaveState>(
      JoinChallengeController.new,
    );

enum RoomAction { start, finish, cancel, leave }

class RoomActionState {
  const RoomActionState({this.running, this.failure});

  final RoomAction? running;
  final Failure? failure;

  bool get isBusy => running != null;
}

/// Iniciar, finalizar, cancelar o salir. Una acción a la vez: evita dobles
/// envíos si se pulsa varias veces.
class RoomActionsController extends Notifier<RoomActionState> {
  RoomActionsController(this.challengeId);

  final String challengeId;

  @override
  RoomActionState build() => const RoomActionState();

  Future<bool> run(RoomAction action) async {
    if (state.isBusy) return false;
    final uid = ref.read(currentUidProvider);
    final challenge = ref.read(challengeProvider(challengeId)).value;
    if (uid == null || challenge == null) return false;

    state = RoomActionState(running: action);
    final status = ref.read(changeChallengeStatusProvider);
    final result = switch (action) {
      RoomAction.start => await status.start(challenge, uid),
      RoomAction.finish => await status.finish(challenge, uid),
      RoomAction.cancel => await status.cancel(challenge, uid),
      RoomAction.leave => await ref.read(leaveChallengeProvider)(
        challenge,
        uid,
      ),
    };
    if (!ref.mounted) return result.isSuccess;
    if (action == RoomAction.finish && result.isSuccess) {
      // Forzar recarga de rankings tras materializar el resultado oficial.
      ref.read(leaderboardEpochProvider.notifier).bump();
    }
    state = result.fold(
      onSuccess: (_) => const RoomActionState(),
      onFailure: (failure) => RoomActionState(failure: failure),
    );
    return result.isSuccess;
  }

  void clearError() {
    if (state.failure != null) state = const RoomActionState();
  }
}

final roomActionsControllerProvider = NotifierProvider.autoDispose
    .family<RoomActionsController, RoomActionState, String>(
      RoomActionsController.new,
    );

class CounterState {
  const CounterState({this.pending = 0, this.failure});

  /// Eventos enviados que el servidor aún no confirmó.
  final int pending;

  /// Último error al registrar (se limpia con el siguiente éxito).
  final Failure? failure;

  bool get isSyncing => pending > 0;

  CounterState copyWith({int? pending, Failure? failure, bool clear = false}) =>
      CounterState(
        pending: pending ?? this.pending,
        failure: clear ? null : (failure ?? this.failure),
      );
}

/// +1 / ?1 del usuario actual.
///
/// No hay contador optimista propio: la caché de Firestore aplica el batch al
/// instante y el stream de participantes emite el nuevo valor sin esperar a
/// la red. Aquí solo se lleva la cuenta de envíos pendientes y los errores.
/// Si el servidor rechaza un evento, Firestore revierte la caché y el número
/// vuelve solo a su valor real.
class CounterController extends Notifier<CounterState> {
  CounterController(this.challengeId);

  final String challengeId;

  @override
  CounterState build() => const CounterState();

  Future<void> increment({String? forUserId}) =>
      _send(ChallengeEventType.increment, forUserId: forUserId);

  Future<void> decrement({String? forUserId}) =>
      _send(ChallengeEventType.decrement, forUserId: forUserId);

  Future<void> _send(
    ChallengeEventType type, {
    String? forUserId,
  }) async {
    final uid = ref.read(currentUidProvider);
    final challenge = ref.read(challengeProvider(challengeId)).value;
    if (uid == null || challenge == null) return;
    final targetUid = forUserId ?? uid;
    if (targetUid != uid) {
      if (!challenge.sameDevicePlay ||
          !challenge.isHost(uid) ||
          !challenge.participantIds.contains(targetUid)) {
        state = state.copyWith(
          failure: const ChallengeFailure.notParticipant(),
        );
        return;
      }
    }
    final participants =
        ref.read(challengeParticipantsProvider(challengeId)).value ?? const [];
    final me = participants.where((p) => p.userId == targetUid).firstOrNull;
    if (me == null) {
      state = state.copyWith(failure: const ChallengeFailure.notParticipant());
      return;
    }

    final pendingDelta = ref
            .read(
              pendingCounterDeltaForUserProvider((
                challengeId: challengeId,
                userId: targetUid,
              )),
            )
            .value ??
        0;
    final effectiveCount = me.currentCount + pendingDelta;

    final record = ref.read(recordCounterEventProvider);
    final event = record.buildEvent(uid: targetUid, type: type);
    state = state.copyWith(pending: state.pending + 1);
    final result = await record(
      challenge: challenge,
      event: event,
      currentCount: effectiveCount,
    );
    if (!ref.mounted) return;
    state = result.fold(
      onSuccess: (_) => state.copyWith(pending: state.pending - 1, clear: true),
      onFailure: (failure) =>
          state.copyWith(pending: state.pending - 1, failure: failure),
    );
  }

  void clearError() {
    if (state.failure != null) state = state.copyWith(clear: true);
  }
}

final counterControllerProvider = NotifierProvider.autoDispose
    .family<CounterController, CounterState, String>(CounterController.new);

/// Confirmacion del companero tras reto en el mismo celular.
class ConfirmPartnerResultController extends Notifier<SaveState> {
  ConfirmPartnerResultController(this.challengeId);
  final String challengeId;

  @override
  SaveState build() => SaveState.idle;

  Future<bool> confirm({required bool accept}) async {
    if (state.isSaving) return false;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return false;
    state = const SaveState(SaveStatus.saving);
    final result = await ref.read(challengeRepositoryProvider).confirmPartnerResult(
          challengeId: challengeId,
          uid: uid,
          accept: accept,
        );
    if (!ref.mounted) return false;
    return result.fold(
      onSuccess: (_) {
        state = const SaveState(SaveStatus.saved);
        return true;
      },
      onFailure: (f) {
        state = SaveState(SaveStatus.error, f);
        return false;
      },
    );
  }
}

final confirmPartnerResultControllerProvider = NotifierProvider.autoDispose
    .family<ConfirmPartnerResultController, SaveState, String>(
  ConfirmPartnerResultController.new,
);
