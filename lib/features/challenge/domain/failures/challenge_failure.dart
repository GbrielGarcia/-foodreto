import '../../../../core/error/failure.dart';

class ChallengeFailure extends Failure {
  const ChallengeFailure(super.message, {super.code, this.challengeId});

  /// Reto relacionado (p. ej. para llevar a la sala si ya eres participante).
  final String? challengeId;

  const ChallengeFailure.notFound()
    : challengeId = null,
      super('Este reto no existe.', code: 'not-found');

  const ChallengeFailure.invalidCode()
    : challengeId = null,
      super(
        'Código no válido: son 6 letras o números.',
        code: 'invalid-code',
      );

  const ChallengeFailure.finished()
    : challengeId = null,
      super('Este reto ya terminó.', code: 'finished');

  const ChallengeFailure.cancelled()
    : challengeId = null,
      super('Este reto fue cancelado.', code: 'cancelled');

  const ChallengeFailure.alreadyStarted()
    : challengeId = null,
      super(
        'Este reto ya empezó; ya no se puede entrar.',
        code: 'already-started',
      );

  const ChallengeFailure.full()
    : challengeId = null,
      super('El reto está lleno.', code: 'full');

  const ChallengeFailure.alreadyJoined(String this.challengeId)
    : super('Ya formas parte de este reto.', code: 'already-joined');

  const ChallengeFailure.notHost()
    : challengeId = null,
      super('Solo el anfitrión puede hacer esto.', code: 'not-host');

  const ChallengeFailure.notParticipant()
    : challengeId = null,
      super('No formas parte de este reto.', code: 'not-participant');

  const ChallengeFailure.hostCannotLeave()
    : challengeId = null,
      super(
        'Eres el anfitrión: si no quieres seguir, cancela el reto.',
        code: 'host-cannot-leave',
      );

  const ChallengeFailure.invalidTransition()
    : challengeId = null,
      super(
        'Esta acción ya no está disponible en el estado actual del reto.',
        code: 'invalid-transition',
      );

  const ChallengeFailure.notActive()
    : challengeId = null,
      super('El reto no está en curso.', code: 'not-active');

  const ChallengeFailure.negativeCount()
    : challengeId = null,
      super('El contador ya está en 0.', code: 'negative-count');

  const ChallengeFailure.codeUnavailable()
    : challengeId = null,
      super(
        'No pudimos generar un código. Inténtalo de nuevo.',
        code: 'code-unavailable',
      );

  const ChallengeFailure.invalidData(super.message)
    : challengeId = null,
      super(code: 'invalid-data');
}
