import '../../../../core/avatar/avatar_config.dart';
import 'result_processing_status.dart';

/// Marca final de un participante.
class ResultEntry {
  const ResultEntry({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.count,
  });

  final String userId;
  final String username;
  final String displayName;
  final AvatarConfig avatar;
  final int count;
}

/// Entrada con su posición. Los empates comparten posición (1, 1, 3).
class RankedEntry {
  const RankedEntry(this.position, this.entry);

  final int position;
  final ResultEntry entry;

  String get medal => switch (position) {
    1 => '🥇',
    2 => '🥈',
    3 => '🥉',
    _ => '',
  };
}

/// Resultado inmutable de un reto terminado (`challengeResults/{challengeId}`).
///
/// El anfitrión crea el documento; Cloud Functions materializa stats/records
/// y puede enriquecer campos oficiales (`processingStatus`, `winnerIds`, …).
class ChallengeResult {
  const ChallengeResult({
    required this.challengeId,
    required this.hostUserId,
    required this.categoryId,
    required this.entries,
    this.restaurantId,
    this.title = '',
    this.startedAt,
    this.finishedAt,
    this.processingStatus = ResultProcessingStatus.pending,
    this.winnerIds = const [],
  });

  final String challengeId;
  final String hostUserId;
  final String categoryId;
  final String? restaurantId;
  final String title;
  final List<ResultEntry> entries;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final ResultProcessingStatus processingStatus;
  final List<String> winnerIds;

  List<String> get participantIds => [for (final e in entries) e.userId];

  int get total => entries.fold(0, (sum, e) => sum + e.count);

  List<RankedEntry> get standings => rankEntries(entries);

  /// Ganadores por empate en la cima (posición 1).
  List<ResultEntry> get winners {
    if (winnerIds.isNotEmpty) {
      final byId = {for (final e in entries) e.userId: e};
      return [for (final id in winnerIds) if (byId[id] != null) byId[id]!];
    }
    final ranked = standings;
    if (ranked.isEmpty) return const [];
    final top = ranked.first.position;
    return [for (final r in ranked) if (r.position == top) r.entry];
  }

  bool get isOfficial =>
      processingStatus == ResultProcessingStatus.official;

  Duration? get duration {
    final start = startedAt;
    final end = finishedAt;
    if (start == null || end == null) return null;
    return end.difference(start);
  }
}

/// Ranking de competición: misma cantidad = misma posición. No hay
/// desempate; dentro de un empate se ordena por nombre solo para que la lista
/// sea estable.
List<RankedEntry> rankEntries(List<ResultEntry> entries) {
  final sorted = [...entries]
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
  final ranked = <RankedEntry>[];
  for (var i = 0; i < sorted.length; i++) {
    final position = i > 0 && sorted[i].count == sorted[i - 1].count
        ? ranked[i - 1].position
        : i + 1;
    ranked.add(RankedEntry(position, sorted[i]));
  }
  return ranked;
}

/// Ids de ganadores (empates incluidos) a partir de las entradas.
List<String> winnerIdsFromEntries(List<ResultEntry> entries) =>
    [for (final w in ChallengeResult(
      challengeId: '',
      hostUserId: '',
      categoryId: '',
      entries: entries,
    ).winners)
      w.userId];
