import '../../../../core/error/result.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../entities/challenge.dart';
import '../entities/challenge_event.dart';
import '../entities/challenge_result.dart';
import '../failures/challenge_failure.dart';
import '../repositories/challenge_repository.dart';
import '../value_objects/client_event_id.dart';
import '../value_objects/invite_code.dart';

class CreateChallenge {
  const CreateChallenge(this._repository);

  final ChallengeRepository _repository;

  Future<Result<Challenge>> call(NewChallenge data, UserProfile host) {
    final title = data.title.trim();
    final description = data.description.trim();
    final problem = switch (data) {
      _ when data.categoryId.isEmpty => 'Elige qué vas a comer.',
      _ when title.length > Challenge.maxTitleLength =>
        'El título admite hasta ${Challenge.maxTitleLength} caracteres.',
      _ when description.length > Challenge.maxDescriptionLength =>
        'La descripción admite hasta '
            '${Challenge.maxDescriptionLength} caracteres.',
      _
          when data.maxParticipants < Challenge.minParticipants ||
              data.maxParticipants > Challenge.maxParticipantsLimit =>
        'Elige entre ${Challenge.minParticipants} y '
            '${Challenge.maxParticipantsLimit} participantes.',
      _ => null,
    };
    if (problem != null) {
      return Future.value(
        Result.failure(ChallengeFailure.invalidData(problem)),
      );
    }
    if (data.sameDevicePlay) {
      final partners = data.resolvedPartnerIds;
      if (partners.isEmpty) {
        return Future.value(
          const Result.failure(
            ChallengeFailure.invalidData(
              'Elige al menos un amigo o crea la cuenta del invitado.',
            ),
          ),
        );
      }
      if (partners.contains(host.uid)) {
        return Future.value(
          const Result.failure(
            ChallengeFailure.invalidData('No puedes retarte a ti mismo.'),
          ),
        );
      }
      final expected = partners.length + 1;
      if (data.maxParticipants != expected ||
          expected < 2 ||
          expected > Challenge.maxParticipantsLimit) {
        return Future.value(
          const Result.failure(
            ChallengeFailure.invalidData(
              'En el mismo celular: entre 2 y '
              '${Challenge.maxParticipantsLimit} jugadores.',
            ),
          ),
        );
      }
    }
    return _repository.createChallenge(
      NewChallenge(
        categoryId: data.categoryId,
        restaurantId: data.restaurantId,
        title: title,
        description: description,
        visibility: data.visibility,
        maxParticipants: data.maxParticipants,
        sameDevicePlay: data.sameDevicePlay,
        sameDevicePartnerId: data.resolvedPartnerIds.firstOrNull,
        sameDevicePartnerIds: data.resolvedPartnerIds,
      ),
      host,
    );
  }
}

/// Busca el reto de un código y comprueba si se puede entrar. No une: la
/// pantalla muestra primero de qué reto se trata.
class FindChallengeByCode {
  const FindChallengeByCode(this._repository);

  final ChallengeRepository _repository;

  Future<Result<Challenge>> call(String rawCode) async {
    final code = InviteCode.normalize(rawCode);
    if (!InviteCode.isValid(code)) {
      return const Result.failure(ChallengeFailure.invalidCode());
    }
    final result = await _repository.findByInviteCode(code);
    return result.fold(
      onSuccess: (challenge) => challenge == null
          ? const Result.failure(ChallengeFailure.notFound())
          : Result.success(challenge),
      onFailure: Result.failure,
    );
  }
}

/// Motivo por el que [uid] no puede entrar en [challenge]; `null` si puede.
ChallengeFailure? joinBlocker(Challenge challenge, String uid) {
  if (challenge.isParticipant(uid)) {
    return ChallengeFailure.alreadyJoined(challenge.id);
  }
  return switch (challenge.status) {
    ChallengeStatus.finished => const ChallengeFailure.finished(),
    ChallengeStatus.cancelled => const ChallengeFailure.cancelled(),
    ChallengeStatus.active => const ChallengeFailure.alreadyStarted(),
    ChallengeStatus.draft => const ChallengeFailure.notFound(),
    ChallengeStatus.waiting when challenge.isFull =>
      const ChallengeFailure.full(),
    ChallengeStatus.waiting => null,
  };
}

class JoinChallenge {
  const JoinChallenge(this._repository);

  final ChallengeRepository _repository;

  /// La comprobación previa da un mensaje claro; la definitiva ocurre en la
  /// transacción del repositorio (y en las reglas) por si otro ocupó el cupo.
  Future<Result<void>> call(Challenge challenge, UserProfile user) {
    final blocker = joinBlocker(challenge, user.uid);
    if (blocker != null) return Future.value(Result.failure(blocker));
    return _repository.join(challenge.id, user);
  }
}

class LeaveChallenge {
  const LeaveChallenge(this._repository);

  final ChallengeRepository _repository;

  Future<Result<void>> call(Challenge challenge, String uid) {
    if (challenge.isHost(uid)) {
      return Future.value(
        const Result.failure(ChallengeFailure.hostCannotLeave()),
      );
    }
    if (!challenge.status.acceptsParticipants) {
      return Future.value(
        const Result.failure(ChallengeFailure.invalidTransition()),
      );
    }
    return _repository.leave(challenge.id, uid);
  }
}

/// Acciones reservadas al host que cambian el estado.
class ChangeChallengeStatus {
  const ChangeChallengeStatus(this._repository);

  final ChallengeRepository _repository;

  Future<Result<void>> start(Challenge challenge, String uid) {
    final problem = _check(challenge, uid, ChallengeStatus.active);
    if (problem != null) return Future.value(Result.failure(problem));
    return _repository.start(challenge.id, uid);
  }

  Future<Result<void>> cancel(Challenge challenge, String uid) {
    final problem = _check(challenge, uid, ChallengeStatus.cancelled);
    if (problem != null) return Future.value(Result.failure(problem));
    return _repository.cancel(challenge.id, uid);
  }

  Future<Result<ChallengeResult>> finish(Challenge challenge, String uid) {
    final problem = _check(challenge, uid, ChallengeStatus.finished);
    if (problem != null) return Future.value(Result.failure(problem));
    return _repository.finish(challenge.id, uid);
  }

  static ChallengeFailure? _check(
    Challenge challenge,
    String uid,
    ChallengeStatus next,
  ) {
    if (!challenge.isHost(uid)) return const ChallengeFailure.notHost();
    if (!challenge.status.canTransitionTo(next)) {
      return const ChallengeFailure.invalidTransition();
    }
    return null;
  }
}

/// +1 / −1. Genera el `clientEventId` aquí para que un reintento de la misma
/// pulsación pueda reutilizarlo.
class RecordCounterEvent {
  const RecordCounterEvent(this._repository, {String Function()? newId})
    : _newId = newId ?? ClientEventId.generate;

  final ChallengeEventRepository _repository;
  final String Function() _newId;

  ChallengeEvent buildEvent({
    required String uid,
    required ChallengeEventType type,
  }) => ChallengeEvent(clientEventId: _newId(), userId: uid, type: type);

  Future<Result<void>> call({
    required Challenge challenge,
    required ChallengeEvent event,
    required int currentCount,
  }) {
    if (!challenge.status.acceptsEvents) {
      return Future.value(const Result.failure(ChallengeFailure.notActive()));
    }
    if (!challenge.isParticipant(event.userId)) {
      return Future.value(
        const Result.failure(ChallengeFailure.notParticipant()),
      );
    }
    if (currentCount + event.delta < 0) {
      return Future.value(
        const Result.failure(ChallengeFailure.negativeCount()),
      );
    }
    return _repository.recordEvent(challenge.id, event);
  }
}
