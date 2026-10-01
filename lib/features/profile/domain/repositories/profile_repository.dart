import '../../../../core/error/result.dart';
import '../entities/user_profile.dart';
import '../entities/user_statistics.dart';
import '../entities/username_availability.dart';

abstract interface class ProfileRepository {
  /// Emite `null` si el usuario todavía no completó su perfil.
  Stream<UserProfile?> watchProfile(String uid);

  /// [username] ya viene normalizado y con formato válido.
  Future<Result<UsernameAvailability>> checkUsernameAvailability(
    String username, {
    String? currentUid,
  });

  /// Crea `users/{uid}` y reserva `usernames/{username}` de forma atómica
  /// (equivale a `createUsername()`). Falla con `usernameTaken` si otro
  /// usuario lo reservó antes, incluso en paralelo.
  Future<Result<UserProfile>> createProfile(NewProfile profile);

  /// Aplica [changes] de forma atómica. Si cambia el username, libera el
  /// anterior y reserva el nuevo en la misma transacción.
  Future<Result<void>> updateProfile(String uid, ProfileChanges changes);
}

abstract interface class UserStatisticsRepository {
  /// Emite [UserStatistics.empty] si todavía no hay actividad.
  Stream<UserStatistics> watchStatistics(String uid);
}
