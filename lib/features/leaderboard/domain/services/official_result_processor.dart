import '../../../../core/avatar/avatar_config.dart';
import '../../../challenge/domain/entities/challenge_result.dart';
import '../../../challenge/domain/entities/result_processing_status.dart';
import '../entities/food_record.dart';
import '../entities/ranking_entry.dart';
import '../entities/ranking_scope.dart';

/// Snapshot previo del procesamiento de un challenge (idempotencia).
class ProcessingLedger {
  const ProcessingLedger({
    required this.challengeId,
    required this.contentHash,
    required this.userDeltas,
    this.scopeWinUserIds = const {},
    this.status = ResultProcessingStatus.official,
  });

  final String challengeId;
  final String contentHash;
  final Map<String, UserStatsDelta> userDeltas;

  /// Por scopeKey: userIds a los que se les sumó +1 win en ese ámbito.
  final Map<String, Set<String>> scopeWinUserIds;
  final ResultProcessingStatus status;
}

class UserStatsDelta {
  const UserStatsDelta({
    required this.units,
    required this.won,
    required this.score,
    this.restaurantId,
    this.categoryId,
  });

  final int units;
  final bool won;
  final int score;
  final String? restaurantId;
  final String? categoryId;
}

class UserStatsState {
  const UserStatsState({
    this.challengeCount = 0,
    this.winCount = 0,
    this.totalUnits = 0,
    this.bestScore = 0,
    this.recordCount = 0,
    this.restaurantIds = const {},
    this.categoryIds = const {},
  });

  final int challengeCount;
  final int winCount;
  final int totalUnits;
  final int bestScore;
  final int recordCount;
  final Set<String> restaurantIds;
  final Set<String> categoryIds;

  UserStatsState apply(UserStatsDelta delta, {required bool reverse}) {
    final sign = reverse ? -1 : 1;
    final restaurants = {...restaurantIds};
    final categories = {...categoryIds};
    final rid = delta.restaurantId;
    final cid = delta.categoryId;
    if (!reverse) {
      if (rid != null && rid.isNotEmpty) restaurants.add(rid);
      if (cid != null && cid.isNotEmpty) categories.add(cid);
    }
    return UserStatsState(
      challengeCount: challengeCount + sign,
      winCount: winCount + (delta.won ? sign : 0),
      totalUnits: totalUnits + sign * delta.units,
      bestScore: reverse
          ? bestScore
          : (delta.score > bestScore ? delta.score : bestScore),
      recordCount: recordCount,
      restaurantIds: restaurants,
      categoryIds: categories,
    );
  }

  UserStatsState withRecordDelta(int delta) => UserStatsState(
        challengeCount: challengeCount,
        winCount: winCount,
        totalUnits: totalUnits,
        bestScore: bestScore,
        recordCount: recordCount + delta,
        restaurantIds: restaurantIds,
        categoryIds: categoryIds,
      );
}

class ScopeEntryState {
  const ScopeEntryState({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.bestScore,
    required this.wins,
    required this.achievedAt,
    required this.challengeId,
  });

  final String userId;
  final String username;
  final String displayName;
  final AvatarConfig avatar;
  final int bestScore;
  final int wins;
  final DateTime achievedAt;
  final String challengeId;

  RankingEntry toEntry({int? position}) => RankingEntry(
        userId: userId,
        username: username,
        displayName: displayName,
        avatar: avatar,
        bestScore: bestScore,
        wins: wins,
        achievedAt: achievedAt,
        challengeId: challengeId,
        position: position,
      );

  ScopeEntryState copyWith({int? bestScore, int? wins, DateTime? achievedAt, String? challengeId}) =>
      ScopeEntryState(
        userId: userId,
        username: username,
        displayName: displayName,
        avatar: avatar,
        bestScore: bestScore ?? this.bestScore,
        wins: wins ?? this.wins,
        achievedAt: achievedAt ?? this.achievedAt,
        challengeId: challengeId ?? this.challengeId,
      );
}

class ScopeRecordState {
  const ScopeRecordState({required this.score, required this.holders});

  final int score;
  final List<RecordHolder> holders;
}

class PendingHistoryEvent {
  const PendingHistoryEvent({
    required this.scopeKey,
    required this.score,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.challengeId,
    required this.achievedAt,
    required this.eventType,
  });

  final String scopeKey;
  final int score;
  final String userId;
  final String username;
  final String displayName;
  final AvatarConfig avatar;
  final String challengeId;
  final DateTime achievedAt;
  final String eventType;
}

/// Diff resultante de procesar (o reprocesar) un resultado oficial.
class OfficialResultDiff {
  const OfficialResultDiff({
    required this.challengeId,
    required this.contentHash,
    required this.winnerIds,
    required this.totalUnits,
    required this.userDeltas,
    required this.scopeWinUserIds,
    required this.userStatsAfter,
    required this.scopeEntriesAfter,
    required this.scopeRecordsAfter,
    required this.historyEvents,
    required this.skipped,
    this.notificationHints = const [],
  });

  final String challengeId;
  final String contentHash;
  final List<String> winnerIds;
  final int totalUnits;
  final Map<String, UserStatsDelta> userDeltas;
  final Map<String, Set<String>> scopeWinUserIds;
  final Map<String, UserStatsState> userStatsAfter;
  final Map<String, Map<String, ScopeEntryState>> scopeEntriesAfter;
  final Map<String, ScopeRecordState> scopeRecordsAfter;
  final List<PendingHistoryEvent> historyEvents;
  final bool skipped;
  final List<String> notificationHints;
}

/// Procesa un [ChallengeResult] de forma pura e idempotente.
///
/// Ranking: bestScore DESC, wins DESC, achievedAt ASC.
class OfficialResultProcessor {
  const OfficialResultProcessor();

  static String contentHashOf(ChallengeResult result) {
    final parts = [
      for (final e in [...result.entries]
        ..sort((a, b) => a.userId.compareTo(b.userId)))
        '${e.userId}:${e.count}',
    ];
    return '${result.challengeId}|${result.categoryId}|'
        '${result.restaurantId ?? ''}|${parts.join(',')}';
  }

  OfficialResultDiff process({
    required ChallengeResult result,
    required Map<String, UserStatsState> currentUserStats,
    required Map<String, Map<String, ScopeEntryState>> currentScopeEntries,
    required Map<String, ScopeRecordState> currentScopeRecords,
    ProcessingLedger? previousLedger,
    bool rankingEligible = true,
    DateTime? now,
  }) {
    final achievedAt = result.finishedAt ?? now ?? DateTime.now().toUtc();
    final hash = contentHashOf(result);
    if (previousLedger != null &&
        previousLedger.contentHash == hash &&
        previousLedger.status == ResultProcessingStatus.official) {
      return OfficialResultDiff(
        challengeId: result.challengeId,
        contentHash: hash,
        winnerIds: [for (final w in result.winners) w.userId]..sort(),
        totalUnits: result.total,
        userDeltas: previousLedger.userDeltas,
        scopeWinUserIds: previousLedger.scopeWinUserIds,
        userStatsAfter: currentUserStats,
        scopeEntriesAfter: currentScopeEntries,
        scopeRecordsAfter: currentScopeRecords,
        historyEvents: const [],
        skipped: true,
      );
    }

    var stats = {
      for (final e in currentUserStats.entries) e.key: e.value,
    };
    final scopeEntries = {
      for (final e in currentScopeEntries.entries)
        e.key: {
          for (final u in e.value.entries) u.key: u.value,
        },
    };

    // Revertir wins de scope del ledger anterior.
    if (previousLedger != null) {
      for (final entry in previousLedger.userDeltas.entries) {
        final prev = stats[entry.key] ?? const UserStatsState();
        stats[entry.key] = prev.apply(entry.value, reverse: true);
      }
      for (final scopeEntry in previousLedger.scopeWinUserIds.entries) {
        final map = scopeEntries[scopeEntry.key];
        if (map == null) continue;
        for (final uid in scopeEntry.value) {
          final existing = map[uid];
          if (existing == null) continue;
          map[uid] = existing.copyWith(wins: existing.wins - 1);
        }
      }
    }

    final winners = {for (final w in result.winners) w.userId};
    final deltas = <String, UserStatsDelta>{};
    for (final e in result.entries) {
      final delta = UserStatsDelta(
        units: e.count,
        won: winners.contains(e.userId),
        score: e.count,
        restaurantId: result.restaurantId,
        categoryId: result.categoryId,
      );
      deltas[e.userId] = delta;
      final prev = stats[e.userId] ?? const UserStatsState();
      stats[e.userId] = prev.apply(delta, reverse: false);
    }

    final scopeRecords =
        Map<String, ScopeRecordState>.from(currentScopeRecords);
    final history = <PendingHistoryEvent>[];
    final hints = <String>[];
    final scopeWins = <String, Set<String>>{};

    if (rankingEligible) {
      final scopes = RankingScopes.forResult(
        categoryId: result.categoryId,
        restaurantId: result.restaurantId,
      );
      for (final scope in scopes) {
        final entries =
            scopeEntries.putIfAbsent(scope, () => <String, ScopeEntryState>{});
        final winSet = <String>{};
        for (final e in result.entries) {
          final existing = entries[e.userId];
          final won = winners.contains(e.userId);
          if (won) winSet.add(e.userId);
          final improved =
              existing == null || e.count > existing.bestScore;
          entries[e.userId] = ScopeEntryState(
            userId: e.userId,
            username: e.username,
            displayName: e.displayName,
            avatar: e.avatar,
            bestScore: improved ? e.count : existing.bestScore,
            wins: (existing?.wins ?? 0) + (won ? 1 : 0),
            achievedAt: improved ? achievedAt : existing.achievedAt,
            challengeId:
                improved ? result.challengeId : existing.challengeId,
          );
        }
        scopeWins[scope] = winSet;

        final maxInChallenge = result.entries.fold<int>(
          0,
          (m, e) => e.count > m ? e.count : m,
        );
        final topEntries = [
          for (final e in result.entries)
            if (e.count == maxInChallenge) e,
        ];
        final current = scopeRecords[scope];
        if (current == null || maxInChallenge > current.score) {
          final holders = [
            for (final e in topEntries)
              RecordHolder(
                userId: e.userId,
                username: e.username,
                displayName: e.displayName,
                avatar: e.avatar,
                challengeId: result.challengeId,
                achievedAt: achievedAt,
              ),
          ];
          scopeRecords[scope] =
              ScopeRecordState(score: maxInChallenge, holders: holders);
          for (final h in holders) {
            history.add(
              PendingHistoryEvent(
                scopeKey: scope,
                score: maxInChallenge,
                userId: h.userId,
                username: h.username,
                displayName: h.displayName,
                avatar: h.avatar,
                challengeId: result.challengeId,
                achievedAt: achievedAt,
                eventType: current == null ? 'created' : 'broken',
              ),
            );
            hints.add(current == null ? 'record_created' : 'record_broken');
            final st = stats[h.userId] ?? const UserStatsState();
            stats[h.userId] = st.withRecordDelta(1);
          }
        } else if (maxInChallenge == current.score) {
          final existingIds = {for (final h in current.holders) h.userId};
          final added = <RecordHolder>[];
          for (final e in topEntries) {
            if (existingIds.contains(e.userId)) continue;
            added.add(
              RecordHolder(
                userId: e.userId,
                username: e.username,
                displayName: e.displayName,
                avatar: e.avatar,
                challengeId: result.challengeId,
                achievedAt: achievedAt,
              ),
            );
            history.add(
              PendingHistoryEvent(
                scopeKey: scope,
                score: maxInChallenge,
                userId: e.userId,
                username: e.username,
                displayName: e.displayName,
                avatar: e.avatar,
                challengeId: result.challengeId,
                achievedAt: achievedAt,
                eventType: 'tied',
              ),
            );
            hints.add('record_created');
            final st = stats[e.userId] ?? const UserStatsState();
            stats[e.userId] = st.withRecordDelta(1);
          }
          if (added.isNotEmpty) {
            scopeRecords[scope] = ScopeRecordState(
              score: current.score,
              holders: [...current.holders, ...added],
            );
          }
        }
      }
    }

    return OfficialResultDiff(
      challengeId: result.challengeId,
      contentHash: hash,
      winnerIds: winners.toList()..sort(),
      totalUnits: result.total,
      userDeltas: deltas,
      scopeWinUserIds: scopeWins,
      userStatsAfter: stats,
      scopeEntriesAfter: scopeEntries,
      scopeRecordsAfter: scopeRecords,
      historyEvents: history,
      skipped: false,
      notificationHints: hints,
    );
  }

  /// Orden: score DESC, wins DESC, achievedAt ASC, userId ASC.
  static int compareEntries(ScopeEntryState a, ScopeEntryState b) {
    final byScore = b.bestScore.compareTo(a.bestScore);
    if (byScore != 0) return byScore;
    final byWins = b.wins.compareTo(a.wins);
    if (byWins != 0) return byWins;
    final byTime = a.achievedAt.compareTo(b.achievedAt);
    if (byTime != 0) return byTime;
    return a.userId.compareTo(b.userId);
  }

  static List<RankingEntry> paginate(
    Iterable<ScopeEntryState> entries, {
    int limit = 20,
    String? cursorUserId,
  }) {
    final sorted = [...entries]..sort(compareEntries);
    var start = 0;
    if (cursorUserId != null) {
      final idx = sorted.indexWhere((e) => e.userId == cursorUserId);
      start = idx < 0 ? 0 : idx + 1;
    }
    final slice = sorted.skip(start).take(limit).toList();
    return [
      for (var i = 0; i < slice.length; i++)
        slice[i].toEntry(position: positionOf(sorted, start + i)),
    ];
  }

  static int positionOf(List<ScopeEntryState> sorted, int index) {
    if (index <= 0) return 1;
    final prev = sorted[index - 1];
    final cur = sorted[index];
    if (cur.bestScore == prev.bestScore && cur.wins == prev.wins) {
      return positionOf(sorted, index - 1);
    }
    return index + 1;
  }

  static int? personalPosition(
    Iterable<ScopeEntryState> entries,
    String userId,
  ) {
    final sorted = [...entries]..sort(compareEntries);
    final idx = sorted.indexWhere((e) => e.userId == userId);
    if (idx < 0) return null;
    return positionOf(sorted, idx);
  }
}
