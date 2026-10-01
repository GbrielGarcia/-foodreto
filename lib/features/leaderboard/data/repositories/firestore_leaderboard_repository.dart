import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_collections.dart';
import '../../domain/entities/food_record.dart';
import '../../domain/entities/ranking_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../../domain/services/official_result_processor.dart';
import '../models/leaderboard_dto.dart';

/// Lectura paginada de rankings/récords. Sin escrituras de cliente.
class FirestoreLeaderboardRepository implements LeaderboardRepository {
  FirestoreLeaderboardRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _boards =>
      _db.collection(FirestoreCollections.leaderboards);

  CollectionReference<Map<String, dynamic>> get _history =>
      _db.collection(FirestoreCollections.recordHistory);

  CollectionReference<Map<String, dynamic>> _entries(String scopeKey) =>
      _boards.doc(scopeKey).collection('entries');

  @override
  Future<RankingPage> getRanking({
    required String scopeKey,
    int limit = 20,
    String? cursor,
  }) async {
    final cursorUid = LeaderboardDto.decodeCursor(cursor);

    Future<QuerySnapshot<Map<String, dynamic>>> run({
      required bool withTieBreakers,
    }) async {
      Query<Map<String, dynamic>> query = _entries(scopeKey).orderBy(
        LeaderboardOrder.amount,
        descending: true,
      );
      if (withTieBreakers) {
        query = query
            .orderBy(LeaderboardOrder.wins, descending: true)
            .orderBy(LeaderboardOrder.achievedAt);
      }
      query = query.limit(limit + 1);
      if (cursorUid != null) {
        final cursorDoc = await _entries(scopeKey).doc(cursorUid).get();
        if (cursorDoc.exists) {
          query = query.startAfterDocument(cursorDoc);
        }
      }
      return query.get();
    }

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await run(withTieBreakers: true);
    } on FirebaseException catch (e) {
      // Índice compuesto aún no desplegado: degradar a orderBy(amount).
      if (e.code == 'failed-precondition') {
        snap = await run(withTieBreakers: false);
      } else {
        rethrow;
      }
    }

    final docs = [...snap.docs];
    // Reordenar en cliente con la métrica oficial (score, wins, fecha).
    docs.sort((a, b) {
      final ea = LeaderboardDto.entryFromMap(a.id, a.data());
      final eb = LeaderboardDto.entryFromMap(b.id, b.data());
      if (ea == null || eb == null) return 0;
      return OfficialResultProcessor.compareEntries(
        ScopeEntryState(
          userId: ea.userId,
          username: ea.username,
          displayName: ea.displayName,
          avatar: ea.avatar,
          bestScore: ea.bestScore,
          wins: ea.wins,
          achievedAt: ea.achievedAt,
          challengeId: ea.challengeId,
        ),
        ScopeEntryState(
          userId: eb.userId,
          username: eb.username,
          displayName: eb.displayName,
          avatar: eb.avatar,
          bestScore: eb.bestScore,
          wins: eb.wins,
          achievedAt: eb.achievedAt,
          challengeId: eb.challengeId,
        ),
      );
    });

    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

    final entries = <RankingEntry>[];
    for (var i = 0; i < pageDocs.length; i++) {
      final mapped = LeaderboardDto.entryFromMap(
        pageDocs[i].id,
        pageDocs[i].data(),
      );
      if (mapped == null) continue;
      final states = [
        for (final e in entries)
          ScopeEntryState(
            userId: e.userId,
            username: e.username,
            displayName: e.displayName,
            avatar: e.avatar,
            bestScore: e.bestScore,
            wins: e.wins,
            achievedAt: e.achievedAt,
            challengeId: e.challengeId,
          ),
        ScopeEntryState(
          userId: mapped.userId,
          username: mapped.username,
          displayName: mapped.displayName,
          avatar: mapped.avatar,
          bestScore: mapped.bestScore,
          wins: mapped.wins,
          achievedAt: mapped.achievedAt,
          challengeId: mapped.challengeId,
        ),
      ];
      final pos = OfficialResultProcessor.positionOf(states, states.length - 1);
      entries.add(
        RankingEntry(
          userId: mapped.userId,
          username: mapped.username,
          displayName: mapped.displayName,
          avatar: mapped.avatar,
          bestScore: mapped.bestScore,
          wins: mapped.wins,
          achievedAt: mapped.achievedAt,
          challengeId: mapped.challengeId,
          position: cursorUid == null ? pos : null,
        ),
      );
    }

    return RankingPage(
      scopeKey: scopeKey,
      entries: entries,
      nextCursor: hasMore && pageDocs.isNotEmpty
          ? LeaderboardDto.encodeCursor(pageDocs.last.id)
          : null,
    );
  }

  @override
  Future<UserRankingPosition> getUserRanking({
    required String scopeKey,
    required String userId,
  }) async {
    final doc = await _entries(scopeKey).doc(userId).get();
    final entry = LeaderboardDto.entryFromMap(userId, doc.data());
    if (entry == null) {
      return UserRankingPosition(
        scopeKey: scopeKey,
        userId: userId,
        position: null,
        bestScore: 0,
        wins: 0,
      );
    }

    // count(amount > mine) + count(amount == mine && wins > mine) +
    // count(amount == mine && wins == mine && achievedAt < mine) + 1
    final betterScore = await _entries(scopeKey)
        .where(LeaderboardOrder.amount, isGreaterThan: entry.bestScore)
        .count()
        .get();
    final betterWins = await _entries(scopeKey)
        .where(LeaderboardOrder.amount, isEqualTo: entry.bestScore)
        .where(LeaderboardOrder.wins, isGreaterThan: entry.wins)
        .count()
        .get();
    final earlier = await _entries(scopeKey)
        .where(LeaderboardOrder.amount, isEqualTo: entry.bestScore)
        .where(LeaderboardOrder.wins, isEqualTo: entry.wins)
        .where(LeaderboardOrder.achievedAt, isLessThan: entry.achievedAt)
        .count()
        .get();

    final position = (betterScore.count ?? 0) +
            (betterWins.count ?? 0) +
            (earlier.count ?? 0) +
            1;

    return UserRankingPosition(
      scopeKey: scopeKey,
      userId: userId,
      position: position,
      bestScore: entry.bestScore,
      wins: entry.wins,
    );
  }

  @override
  Future<FoodRecord?> getRecord(String scopeKey) async {
    final doc = await _boards.doc(scopeKey).get();
    return LeaderboardDto.recordFromMap(scopeKey, doc.data());
  }

  @override
  Future<List<RecordHistoryEntry>> getRecordHistory({
    required String scopeKey,
    int limit = 20,
  }) async {
    final snap = await _history
        .where('scopeKey', isEqualTo: scopeKey)
        .orderBy('achievedAt', descending: true)
        .limit(limit)
        .get();
    return [
      for (final doc in snap.docs)
        if (LeaderboardDto.historyFromMap(doc.id, doc.data()) case final e?) e,
    ];
  }

  @override
  Future<List<FoodRecord>> getRecentRecords({int limit = 10}) async {
    final snap = await _boards
        .where('topAmount', isGreaterThan: 0)
        .orderBy('topAmount', descending: true)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();
    return [
      for (final doc in snap.docs)
        if (LeaderboardDto.recordFromMap(doc.id, doc.data()) case final r?) r,
    ];
  }

  @override
  Future<List<RankingEntry>> getEntriesByUserIds({
    required String scopeKey,
    required List<String> userIds,
  }) async {
    if (userIds.isEmpty) return const [];
    final entries = <RankingEntry>[];
    // whereIn máx. 30 ids por lote.
    for (var i = 0; i < userIds.length; i += 30) {
      final chunk = userIds.sublist(i, i + 30 > userIds.length ? userIds.length : i + 30);
      final snap = await _entries(scopeKey)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final e = LeaderboardDto.entryFromMap(doc.id, doc.data());
        if (e != null) entries.add(e);
      }
    }
    return entries;
  }
}
