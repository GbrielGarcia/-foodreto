import 'dart:async';

import '../../../../core/avatar/avatar_config.dart';
import '../../../challenge/domain/entities/challenge_result.dart';
import '../../../challenge/domain/entities/result_processing_status.dart';
import '../../domain/entities/food_record.dart';
import '../../domain/entities/ranking_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../../domain/services/official_result_processor.dart';

/// Store local: aplica el processor al finalizar retos (modo `local`).
class InMemoryLeaderboardRepository implements LeaderboardRepository {
  InMemoryLeaderboardRepository();

  final _processor = const OfficialResultProcessor();
  final _userStats = <String, UserStatsState>{};
  final _scopeEntries = <String, Map<String, ScopeEntryState>>{};
  final _scopeRecords = <String, ScopeRecordState>{};
  final _ledgers = <String, ProcessingLedger>{};
  final _history = <RecordHistoryEntry>[];
  var _historySeq = 0;

  Map<String, UserStatsState> get userStats => _userStats;

  /// Aplica (o re-aplica) un resultado oficial. Idempotente.
  OfficialResultDiff applyResult(
    ChallengeResult result, {
    bool rankingEligible = true,
  }) {
    final diff = _processor.process(
      result: result,
      currentUserStats: _userStats,
      currentScopeEntries: _scopeEntries,
      currentScopeRecords: _scopeRecords,
      previousLedger: _ledgers[result.challengeId],
      rankingEligible: rankingEligible,
      now: result.finishedAt ?? DateTime.now().toUtc(),
    );
    if (diff.skipped) return diff;

    _userStats
      ..clear()
      ..addAll(diff.userStatsAfter);
    _scopeEntries
      ..clear()
      ..addAll({
        for (final e in diff.scopeEntriesAfter.entries)
          e.key: Map<String, ScopeEntryState>.from(e.value),
      });
    _scopeRecords
      ..clear()
      ..addAll(diff.scopeRecordsAfter);

    for (final event in diff.historyEvents) {
      _historySeq += 1;
      _history.insert(
        0,
        RecordHistoryEntry(
          id: 'h$_historySeq',
          scopeKey: event.scopeKey,
          score: event.score,
          userId: event.userId,
          username: event.username,
          displayName: event.displayName,
          avatar: event.avatar,
          challengeId: event.challengeId,
          achievedAt: event.achievedAt,
          eventType: event.eventType,
        ),
      );
    }

    _ledgers[result.challengeId] = ProcessingLedger(
      challengeId: result.challengeId,
      contentHash: diff.contentHash,
      userDeltas: diff.userDeltas,
      scopeWinUserIds: diff.scopeWinUserIds,
      status: ResultProcessingStatus.official,
    );
    return diff;
  }

  /// Reprocesa forzando recálculo (mismo o distinto contenido).
  OfficialResultDiff reprocess(
    ChallengeResult result, {
    bool rankingEligible = true,
  }) {
    // Si forzamos, no usamos skip: borramos ledger temporalmente solo si
    // queremos forzar — aquí llamamos apply que ya maneja ledger.
    return applyResult(result, rankingEligible: rankingEligible);
  }

  @override
  Future<RankingPage> getRanking({
    required String scopeKey,
    int limit = 20,
    String? cursor,
  }) async {
    final entries = _scopeEntries[scopeKey]?.values ?? const [];
    final page = OfficialResultProcessor.paginate(
      entries,
      limit: limit,
      cursorUserId: cursor,
    );
    final all = [...entries]..sort(OfficialResultProcessor.compareEntries);
    String? next;
    if (page.isNotEmpty) {
      final lastIdx = all.indexWhere((e) => e.userId == page.last.userId);
      if (lastIdx >= 0 && lastIdx + 1 < all.length) {
        next = page.last.userId;
      }
    }
    return RankingPage(scopeKey: scopeKey, entries: page, nextCursor: next);
  }

  @override
  Future<UserRankingPosition> getUserRanking({
    required String scopeKey,
    required String userId,
  }) async {
    final entries = _scopeEntries[scopeKey]?.values ?? const [];
    final mine = _scopeEntries[scopeKey]?[userId];
    return UserRankingPosition(
      scopeKey: scopeKey,
      userId: userId,
      position: OfficialResultProcessor.personalPosition(entries, userId),
      bestScore: mine?.bestScore ?? 0,
      wins: mine?.wins ?? 0,
    );
  }

  @override
  Future<FoodRecord?> getRecord(String scopeKey) async {
    final state = _scopeRecords[scopeKey];
    if (state == null) return null;
    return FoodRecord(
      scopeKey: scopeKey,
      score: state.score,
      holders: state.holders,
    );
  }

  @override
  Future<List<RecordHistoryEntry>> getRecordHistory({
    required String scopeKey,
    int limit = 20,
  }) async {
    return _history.where((e) => e.scopeKey == scopeKey).take(limit).toList();
  }

  @override
  Future<List<FoodRecord>> getRecentRecords({int limit = 10}) async {
    final records = [
      for (final e in _scopeRecords.entries)
        FoodRecord(scopeKey: e.key, score: e.value.score, holders: e.value.holders),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return records.take(limit).toList();
  }

  @override
  Future<List<RankingEntry>> getEntriesByUserIds({
    required String scopeKey,
    required List<String> userIds,
  }) async {
    final map = _scopeEntries[scopeKey] ?? {};
    final states = [
      for (final id in userIds)
        if (map[id] case final e?) e,
    ]..sort(OfficialResultProcessor.compareEntries);
    return [
      for (var i = 0; i < states.length; i++)
        states[i].toEntry(
          position: OfficialResultProcessor.positionOf(states, i),
        ),
    ];
  }
}

/// Avatar por defecto para tests locales.
AvatarConfig get kDefaultLeaderboardAvatar =>
    const AvatarConfig(style: 'lorelei', seed: 'foodreto');
