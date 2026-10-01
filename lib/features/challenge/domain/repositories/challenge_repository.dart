import '../../../../core/error/result.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../entities/challenge.dart';
import '../entities/challenge_event.dart';
import '../entities/challenge_participant.dart';
import '../entities/challenge_result.dart';

/// Ciclo de vida del reto. Cada operación valida el estado dentro de una
/// transacción, y `firestore.rules` vuelve a validarlo en el servidor.
abstract interface class ChallengeRepository {
  /// Crea el reto en `waiting`, reserva un código único y añade al host
  /// como primer participante.
  Future<Result<Challenge>> createChallenge(
    NewChallenge data,
    UserProfile host,
  );

  /// Reto asociado a un código normalizado; `null` si no existe.
  Future<Result<Challenge?>> findByInviteCode(String code);

  Stream<Challenge?> watchChallenge(String challengeId);

  /// Retos en los que participa el usuario, del más reciente al más antiguo.
  Stream<List<Challenge>> watchUserChallenges(String uid);

  /// Retos publicos de un restaurante (pagina unica, limite).
  Future<Result<List<Challenge>>> listPublicByRestaurant({
    required String restaurantId,
    int limit = 20,
  });

  /// Retos publicos abiertos (waiting/active) para descubrir y unirse.
  Future<Result<List<Challenge>>> listOpenPublicChallenges({int limit = 20});

  Future<Result<void>> join(String challengeId, UserProfile user);

  Future<Result<void>> leave(String challengeId, String uid);

  Future<Result<void>> start(String challengeId, String uid);

  Future<Result<void>> cancel(String challengeId, String uid);

  /// Añade al compañero de mismo celular (amigo o guest) y deja el reto listo.
  Future<Result<void>> addSameDevicePartner(
    String challengeId,
    UserProfile partner,
  );

  /// El compañero confirma o rechaza el resultado tras jugar en el mismo celular.
  Future<Result<void>> confirmPartnerResult({
    required String challengeId,
    required String uid,
    required bool accept,
  });

  /// Cierra el reto y guarda el resultado en la misma transacción.
  Future<Result<ChallengeResult>> finish(String challengeId, String uid);

  Stream<ChallengeResult?> watchResult(String challengeId);
}

abstract interface class ChallengeParticipantRepository {
  Stream<List<ChallengeParticipant>> watchParticipants(String challengeId);
}

abstract interface class ChallengeEventRepository {
  /// Registra el evento y actualiza el contador del participante de forma
  /// atómica. Un `clientEventId` ya registrado se rechaza.
  Future<Result<void>> recordEvent(String challengeId, ChallengeEvent event);

  /// Todos los eventos del reto (para reconstruir/verificar totales).
  Future<Result<List<ChallengeEvent>>> getEvents(String challengeId);
}
