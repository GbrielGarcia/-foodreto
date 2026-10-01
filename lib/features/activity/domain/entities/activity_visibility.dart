import '../../../challenge/domain/entities/challenge.dart';
import '../../../profile/domain/entities/user_profile.dart';

/// Visibilidad de una actividad en el feed.
enum ActivityVisibility {
  /// Cualquier usuario autenticado puede verla.
  public,

  /// Solo el actor y amigos aceptados.
  friends,

  /// Solo el actor.
  private;

  static ActivityVisibility? tryParse(Object? raw) {
    if (raw is! String) return null;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  /// Combina privacidad del reto y del perfil del actor.
  ///
  /// Retos `private` no generan actividad de feed (evita fallos de rules
  /// en queries `actorUserId in [...]` con docs ilegibles).
  static ActivityVisibility? resolveOrNull({
    required ChallengeVisibility challenge,
    required ProfileVisibility profile,
  }) {
    if (challenge == ChallengeVisibility.private) return null;
    if (profile == ProfileVisibility.private) {
      return ActivityVisibility.friends;
    }
    if (challenge == ChallengeVisibility.friends) {
      return ActivityVisibility.friends;
    }
    return ActivityVisibility.public;
  }

  static ActivityVisibility resolve({
    required ChallengeVisibility challenge,
    required ProfileVisibility profile,
  }) =>
      resolveOrNull(challenge: challenge, profile: profile) ??
      ActivityVisibility.friends;
}
