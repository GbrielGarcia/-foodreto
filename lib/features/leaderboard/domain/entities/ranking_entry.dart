import '../../../../core/avatar/avatar_config.dart';

/// Mejor marca de un usuario en un ámbito (`leaderboards/{scope}/entries/{uid}`).
class RankingEntry {
  const RankingEntry({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.bestScore,
    required this.wins,
    required this.achievedAt,
    required this.challengeId,
    this.position,
  });

  final String userId;
  final String username;
  final String displayName;
  final AvatarConfig avatar;

  /// Mejor score oficial en este ámbito.
  final int bestScore;

  /// Victorias oficiales en este ámbito (desempate).
  final int wins;

  final DateTime achievedAt;
  final String challengeId;

  /// Posición (1,1,3) si se calculó en una página.
  final int? position;
}

/// Página paginada de un ranking.
class RankingPage {
  const RankingPage({
    required this.entries,
    required this.scopeKey,
    this.nextCursor,
  });

  final String scopeKey;
  final List<RankingEntry> entries;

  /// Cursor opaco para la siguiente página (`null` = no hay más).
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

/// Posición personal en un ámbito.
class UserRankingPosition {
  const UserRankingPosition({
    required this.scopeKey,
    required this.userId,
    required this.position,
    required this.bestScore,
    required this.wins,
  });

  final String scopeKey;
  final String userId;

  /// `null` si el usuario aún no tiene entrada.
  final int? position;
  final int bestScore;
  final int wins;

  bool get isRanked => position != null;
}
