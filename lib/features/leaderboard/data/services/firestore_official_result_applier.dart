import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/firebase/firestore_collections.dart';
import '../../../activity/data/models/activity_dto.dart';
import '../../../activity/domain/services/official_activity_builder.dart';
import '../../../challenge/domain/entities/challenge.dart';
import '../../../challenge/domain/entities/challenge_result.dart';
import '../../../challenge/domain/entities/result_processing_status.dart';
import '../../../notifications/data/models/notification_dto.dart';
import '../../../notifications/domain/services/official_notification_builder.dart';
import '../../domain/entities/food_record.dart';
import '../../domain/entities/ranking_scope.dart';
import '../../domain/services/official_result_processor.dart';

/// Aplica el resultado oficial en Firestore desde el cliente (plan Spark).
///
/// Equivalente a Cloud Functions `onChallengeResultCreated`, usando
/// [OfficialResultProcessor] en Dart. Idempotente via `resultProcessing`.
///
/// Orden: 1) stats/rankings/ledger  2) activities/notifications (best-effort).
/// Asi un fallo social no deja el ranking sin actualizar.
class FirestoreOfficialResultApplier {
  FirestoreOfficialResultApplier(this._db);

  final FirebaseFirestore _db;
  final _processor = const OfficialResultProcessor();

  CollectionReference<Map<String, dynamic>> get _results =>
      _db.collection(FirestoreCollections.challengeResults);

  CollectionReference<Map<String, dynamic>> get _challenges =>
      _db.collection(FirestoreCollections.challenges);

  CollectionReference<Map<String, dynamic>> get _ledgers =>
      _db.collection(FirestoreCollections.resultProcessing);

  CollectionReference<Map<String, dynamic>> get _boards =>
      _db.collection(FirestoreCollections.leaderboards);

  CollectionReference<Map<String, dynamic>> get _stats =>
      _db.collection(FirestoreCollections.userStatistics);

  CollectionReference<Map<String, dynamic>> get _history =>
      _db.collection(FirestoreCollections.recordHistory);

  CollectionReference<Map<String, dynamic>> get _activities =>
      _db.collection(FirestoreCollections.activities);

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection(FirestoreCollections.notifications);

  /// Procesa un resultado pendiente/oficial. No-op si el hash no cambio.
  Future<OfficialResultDiff> apply({
    required ChallengeResult result,
    required ChallengeVisibility visibility,
    String? categoryName,
  }) async {
    final challengeSnap = await _challenges.doc(result.challengeId).get();
    final challengeVisibility = challengeSnap.data()?['visibility'] as String?;
    final resolvedVisibility = ChallengeVisibility.fromId(
      challengeVisibility ?? visibility.name,
    );
    // Solo retos publicos cuentan para rankings/records oficiales.
    final rankingEligible =
        resolvedVisibility == ChallengeVisibility.public;

    final ledgerRef = _ledgers.doc(result.challengeId);
    final ledgerSnap = await ledgerRef.get();
    final previousLedger = ledgerSnap.exists
        ? _ledgerFromMap(result.challengeId, ledgerSnap.data())
        : null;

    final scopes = RankingScopes.forResult(
      categoryId: result.categoryId,
      restaurantId: result.restaurantId,
    );

    final affectedUserIds = <String>{
      for (final e in result.entries) e.userId,
      if (previousLedger != null) ...previousLedger.userDeltas.keys,
      if (previousLedger != null)
        for (final set in previousLedger.scopeWinUserIds.values) ...set,
    };

    final currentUserStats = <String, UserStatsState>{};
    for (final uid in affectedUserIds) {
      final snap = await _stats.doc(uid).get();
      currentUserStats[uid] = _statsFromMap(snap.data());
    }

    final currentScopeEntries = <String, Map<String, ScopeEntryState>>{};
    final currentScopeRecords = <String, ScopeRecordState>{};
    if (rankingEligible) {
      for (final scope in scopes) {
        final entries = <String, ScopeEntryState>{};
        for (final uid in affectedUserIds) {
          final snap =
              await _boards.doc(scope).collection('entries').doc(uid).get();
          final mapped = _entryFromMap(uid, snap.data());
          if (mapped != null) entries[uid] = mapped;
        }
        currentScopeEntries[scope] = entries;

        final boardSnap = await _boards.doc(scope).get();
        final record = _recordFromMap(boardSnap.data());
        if (record != null) currentScopeRecords[scope] = record;
      }
    }

    final diff = _processor.process(
      result: result,
      currentUserStats: currentUserStats,
      currentScopeEntries: currentScopeEntries,
      currentScopeRecords: currentScopeRecords,
      previousLedger: previousLedger,
      rankingEligible: rankingEligible,
      now: result.finishedAt ?? DateTime.now().toUtc(),
    );

    if (diff.skipped) {
      await _results.doc(result.challengeId).set({
        'processingStatus': ResultProcessingStatus.official.name,
        'winnerIds': diff.winnerIds,
        'totalUnits': diff.totalUnits,
      }, SetOptions(merge: true));
      return diff;
    }

    await _commitCore(result: result, diff: diff, rankingEligible: rankingEligible);

    // Social: no debe tumbar el ranking si falla Rules/merge.
    await _commitSocialBestEffort(
      result: result,
      diff: diff,
      visibility: resolvedVisibility,
      categoryName: categoryName,
    );

    return diff;
  }

  Future<void> _commitCore({
    required ChallengeResult result,
    required OfficialResultDiff diff,
    required bool rankingEligible,
  }) async {
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();
    final affectedUserIds = <String>{
      for (final e in result.entries) e.userId,
      ...diff.userDeltas.keys,
      for (final set in diff.scopeWinUserIds.values) ...set,
    };

    for (final uid in affectedUserIds) {
      final after = diff.userStatsAfter[uid] ?? const UserStatsState();
      batch.set(_stats.doc(uid), {
        'challengeCount': after.challengeCount,
        'winCount': after.winCount,
        'totalUnits': after.totalUnits,
        'bestScore': after.bestScore,
        'recordCount': after.recordCount,
        'restaurantIds': after.restaurantIds.toList(),
        'categoryIds': after.categoryIds.toList(),
        'restaurantCount': after.restaurantIds.length,
        'categoryCount': after.categoryIds.length,
        'lastOfficialChallengeId': result.challengeId,
        'updatedAt': now,
      }, SetOptions(merge: true));
    }

    if (rankingEligible) {
      final scopes = RankingScopes.forResult(
        categoryId: result.categoryId,
        restaurantId: result.restaurantId,
      );
      for (final scope in scopes) {
        final entries = diff.scopeEntriesAfter[scope] ?? {};
        for (final uid in affectedUserIds) {
          final entry = entries[uid];
          if (entry == null) continue;
          batch.set(_boards.doc(scope).collection('entries').doc(uid), {
            'userId': entry.userId,
            'username': entry.username,
            'displayName': entry.displayName,
            ..._avatarFields(entry.avatar),
            'amount': entry.bestScore,
            'wins': entry.wins,
            'achievedAt': Timestamp.fromDate(entry.achievedAt.toUtc()),
            'challengeId': entry.challengeId,
            'lastChallengeId': result.challengeId,
            'updatedAt': now,
          }, SetOptions(merge: true));
        }

        final record = diff.scopeRecordsAfter[scope];
        if (record != null) {
          batch.set(_boards.doc(scope), {
            'scopeKey': scope,
            'categoryId': result.categoryId,
            'restaurantId': result.restaurantId,
            'topAmount': record.score,
            'topHolders': [
              for (final h in record.holders)
                {
                  'userId': h.userId,
                  'username': h.username,
                  'displayName': h.displayName,
                  ..._avatarFields(h.avatar),
                  'challengeId': h.challengeId,
                  'achievedAt': Timestamp.fromDate(h.achievedAt.toUtc()),
                },
            ],
            'lastChallengeId': result.challengeId,
            'updatedAt': now,
          }, SetOptions(merge: true));
        }
      }

      for (final event in diff.historyEvents) {
        batch.set(_history.doc(), {
          'scopeKey': event.scopeKey,
          'score': event.score,
          'userId': event.userId,
          'username': event.username,
          'displayName': event.displayName,
          ..._avatarFields(event.avatar),
          'challengeId': event.challengeId,
          'achievedAt': Timestamp.fromDate(event.achievedAt.toUtc()),
          'eventType': event.eventType,
        });
      }
    }

    batch.set(_ledgers.doc(result.challengeId), {
      'challengeId': result.challengeId,
      'contentHash': diff.contentHash,
      'status': ResultProcessingStatus.official.name,
      'userDeltas': {
        for (final e in diff.userDeltas.entries)
          e.key: {
            'units': e.value.units,
            'won': e.value.won,
            'score': e.value.score,
            if (e.value.restaurantId != null)
              'restaurantId': e.value.restaurantId,
            if (e.value.categoryId != null) 'categoryId': e.value.categoryId,
          },
      },
      'scopeWinUserIds': {
        for (final e in diff.scopeWinUserIds.entries) e.key: e.value.toList(),
      },
      'updatedAt': now,
    });

    batch.set(_results.doc(result.challengeId), {
      'processingStatus': ResultProcessingStatus.official.name,
      'winnerIds': diff.winnerIds,
      'totalUnits': diff.totalUnits,
      'officialAt': now,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> _commitSocialBestEffort({
    required ChallengeResult result,
    required OfficialResultDiff diff,
    required ChallengeVisibility visibility,
    String? categoryName,
  }) async {
    try {
      final activities = OfficialActivityBuilder.build(
        result: result.copyWithOfficial(
          winnerIds: diff.winnerIds,
          processingStatus: ResultProcessingStatus.official,
        ),
        diff: diff,
        challengeVisibility: visibility,
        categoryName: categoryName,
      );
      for (final a in activities) {
        final ref = _activities.doc(a.id);
        if ((await ref.get()).exists) continue;
        await ref.set(ActivityDto.toMap(a, forCreate: true));
      }

      final notifications = OfficialNotificationBuilder.fromResult(
        result: result.copyWithOfficial(
          winnerIds: diff.winnerIds,
          processingStatus: ResultProcessingStatus.official,
        ),
        diff: diff,
        categoryName: categoryName,
      );
      for (final n in notifications) {
        final ref = _notifications.doc(n.id);
        // No get() previo: el host no puede leer notifs de otros recipients.
        try {
          await ref.set({
            ...NotificationDto.toMap(n),
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        } catch (e) {
          debugPrint('FoodReto: notif ${n.id} omitida: $e');
        }
      }
    } catch (e, st) {
      debugPrint('FoodReto: official social write failed: $e\n$st');
    }
  }

  /// Reprocesa resultados del host que aun no estan `official`.
  Future<int> backfillPendingForHost(String hostUserId) async {
    final snap = await _results
        .where('hostUserId', isEqualTo: hostUserId)
        .limit(30)
        .get();
    var count = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final status = data['processingStatus'] as String?;
      if (status == ResultProcessingStatus.official.name) continue;

      final result = _resultFromDoc(doc.id, data);
      if (result == null) continue;

      final challengeSnap = await _challenges.doc(result.challengeId).get();
      final visRaw = challengeSnap.data()?['visibility'] as String?;
      final visibility = ChallengeVisibility.fromId(visRaw);

      try {
        await apply(result: result, visibility: visibility);
        count += 1;
      } catch (e, st) {
        debugPrint(
          'FoodReto: backfill ${result.challengeId} failed: $e\n$st',
        );
      }
    }
    return count;
  }

  ChallengeResult? _resultFromDoc(String id, Map<String, dynamic> data) {
    final participants = data['participants'];
    if (participants is! List || participants.isEmpty) return null;
    final entries = <ResultEntry>[];
    for (final raw in participants) {
      if (raw is! Map) continue;
      entries.add(
        ResultEntry(
          userId: raw['userId'] as String? ?? '',
          username: raw['username'] as String? ?? '',
          displayName: raw['displayName'] as String? ?? '',
          avatar: AvatarConfig.fromData(
            style: raw['avatarStyle'],
            seed: raw['avatarSeed'],
            options: raw['avatarOptions'],
          ),
          count: (raw['count'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    if (entries.isEmpty) return null;
    return ChallengeResult(
      challengeId: id,
      hostUserId: data['hostUserId'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      restaurantId: data['restaurantId'] as String?,
      title: data['title'] as String? ?? '',
      finishedAt: (data['finishedAt'] is Timestamp)
          ? (data['finishedAt'] as Timestamp).toDate()
          : DateTime.now().toUtc(),
      entries: entries,
      winnerIds: [
        for (final id in data['winnerIds'] as List? ?? const [])
          if (id is String) id,
      ],
    );
  }

  ProcessingLedger? _ledgerFromMap(
    String challengeId,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final hash = data['contentHash'] as String?;
    if (hash == null || hash.isEmpty) return null;
    final deltasRaw = data['userDeltas'];
    final deltas = <String, UserStatsDelta>{};
    if (deltasRaw is Map) {
      for (final e in deltasRaw.entries) {
        final v = e.value;
        if (v is! Map) continue;
        deltas[e.key as String] = UserStatsDelta(
          units: (v['units'] as num?)?.toInt() ?? 0,
          won: v['won'] == true,
          score: (v['score'] as num?)?.toInt() ?? 0,
          restaurantId: v['restaurantId'] as String?,
          categoryId: v['categoryId'] as String?,
        );
      }
    }
    final winsRaw = data['scopeWinUserIds'];
    final wins = <String, Set<String>>{};
    if (winsRaw is Map) {
      for (final e in winsRaw.entries) {
        final list = e.value;
        wins[e.key as String] = {
          if (list is List)
            for (final uid in list)
              if (uid is String) uid,
        };
      }
    }
    final statusRaw = data['status'] as String?;
    final status = ResultProcessingStatus.values.firstWhere(
      (s) => s.name == statusRaw,
      orElse: () => ResultProcessingStatus.official,
    );
    return ProcessingLedger(
      challengeId: challengeId,
      contentHash: hash,
      userDeltas: deltas,
      scopeWinUserIds: wins,
      status: status,
    );
  }

  UserStatsState _statsFromMap(Map<String, dynamic>? data) {
    if (data == null) return const UserStatsState();
    return UserStatsState(
      challengeCount: (data['challengeCount'] as num?)?.toInt() ?? 0,
      winCount: (data['winCount'] as num?)?.toInt() ?? 0,
      totalUnits: (data['totalUnits'] as num?)?.toInt() ?? 0,
      bestScore: (data['bestScore'] as num?)?.toInt() ?? 0,
      recordCount: (data['recordCount'] as num?)?.toInt() ?? 0,
      restaurantIds: {
        for (final id in data['restaurantIds'] as List? ?? const [])
          if (id is String) id,
      },
      categoryIds: {
        for (final id in data['categoryIds'] as List? ?? const [])
          if (id is String) id,
      },
    );
  }

  ScopeEntryState? _entryFromMap(String userId, Map<String, dynamic>? data) {
    if (data == null) return null;
    final achieved = data['achievedAt'];
    return ScopeEntryState(
      userId: userId,
      username: data['username'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      avatar: AvatarConfig.fromData(
        style: data['avatarStyle'],
        seed: data['avatarSeed'],
        options: data['avatarOptions'],
      ),
      bestScore: (data['amount'] as num?)?.toInt() ?? 0,
      wins: (data['wins'] as num?)?.toInt() ?? 0,
      achievedAt: achieved is Timestamp
          ? achieved.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      challengeId: data['challengeId'] as String? ?? '',
    );
  }

  ScopeRecordState? _recordFromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final amount = (data['topAmount'] as num?)?.toInt() ?? 0;
    if (amount <= 0 && (data['topHolders'] as List? ?? const []).isEmpty) {
      return null;
    }
    return ScopeRecordState(
      score: amount,
      holders: [
        for (final raw in data['topHolders'] as List? ?? const [])
          if (raw is Map)
            RecordHolder(
              userId: raw['userId'] as String? ?? '',
              username: raw['username'] as String? ?? '',
              displayName: raw['displayName'] as String? ?? '',
              avatar: AvatarConfig.fromData(
                style: raw['avatarStyle'],
                seed: raw['avatarSeed'],
                options: raw['avatarOptions'],
              ),
              challengeId: raw['challengeId'] as String? ?? '',
              achievedAt: raw['achievedAt'] is Timestamp
                  ? (raw['achievedAt'] as Timestamp).toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0),
            ),
      ],
    );
  }

  Map<String, Object?> _avatarFields(AvatarConfig avatar) => {
        'avatarStyle': avatar.style,
        'avatarSeed': avatar.seed,
        'avatarOptions': avatar.options,
      };
}

extension on ChallengeResult {
  ChallengeResult copyWithOfficial({
    required List<String> winnerIds,
    required ResultProcessingStatus processingStatus,
  }) =>
      ChallengeResult(
        challengeId: challengeId,
        hostUserId: hostUserId,
        categoryId: categoryId,
        restaurantId: restaurantId,
        title: title,
        startedAt: startedAt,
        finishedAt: finishedAt,
        entries: entries,
        winnerIds: winnerIds,
        processingStatus: processingStatus,
      );
}
