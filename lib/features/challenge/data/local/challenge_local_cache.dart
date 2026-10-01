import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/challenge_participant.dart';

/// Escribe snapshots remotos en Drift (caché). No es fuente de verdad.
class ChallengeLocalCache {
  ChallengeLocalCache(this._db);

  final AppDatabase _db;

  Future<void> upsertChallenge(Challenge challenge) async {
    await _db
        .into(_db.challengesLocal)
        .insertOnConflictUpdate(
          ChallengesLocalCompanion.insert(
            id: challenge.id,
            hostUserId: challenge.hostUserId,
            categoryId: challenge.categoryId,
            restaurantId: Value(challenge.restaurantId),
            title: Value(challenge.title),
            description: Value(challenge.description),
            inviteCode: challenge.inviteCode,
            visibility: challenge.visibility.name,
            status: challenge.status.name,
            maxParticipants: challenge.maxParticipants,
            participantIdsJson: Value(jsonEncode(challenge.participantIds)),
            createdAt: Value(challenge.createdAt),
            startedAt: Value(challenge.startedAt),
            finishedAt: Value(challenge.finishedAt),
            updatedAt: Value(challenge.updatedAt),
            syncedAt: DateTime.now(),
          ),
        );
  }

  Future<void> upsertParticipants(
    String challengeId,
    List<ChallengeParticipant> participants,
  ) async {
    await _db.batch((batch) {
      for (final p in participants) {
        batch.insert(
          _db.participantsLocal,
          ParticipantsLocalCompanion.insert(
            challengeId: challengeId,
            userId: p.userId,
            username: p.username,
            displayName: p.displayName,
            avatarStyle: Value(p.avatar.style),
            avatarSeed: Value(p.avatar.seed),
            role: p.role.name,
            currentCount: Value(p.currentCount),
            lastEventId: Value(p.lastEventId),
            joinedAt: Value(p.joinedAt),
            updatedAt: DateTime.now(),
          ),
          onConflict: DoUpdate(
            (old) => ParticipantsLocalCompanion(
              username: Value(p.username),
              displayName: Value(p.displayName),
              avatarStyle: Value(p.avatar.style),
              avatarSeed: Value(p.avatar.seed),
              role: Value(p.role.name),
              currentCount: Value(p.currentCount),
              lastEventId: Value(p.lastEventId),
              joinedAt: Value(p.joinedAt),
              updatedAt: Value(DateTime.now()),
            ),
          ),
        );
      }
    });
  }

  Future<Challenge?> readChallenge(String id) async {
    final row = await (_db.select(
      _db.challengesLocal,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final ids = (jsonDecode(row.participantIdsJson) as List)
        .whereType<String>()
        .toList();
    return Challenge(
      id: row.id,
      hostUserId: row.hostUserId,
      categoryId: row.categoryId,
      restaurantId: row.restaurantId,
      title: row.title,
      description: row.description,
      inviteCode: row.inviteCode,
      visibility: ChallengeVisibility.fromId(row.visibility),
      status: ChallengeStatus.fromId(row.status),
      maxParticipants: row.maxParticipants,
      participantIds: ids,
      createdAt: row.createdAt,
      startedAt: row.startedAt,
      finishedAt: row.finishedAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<List<ChallengeParticipant>> readParticipants(String challengeId) async {
    final rows = await (_db.select(
      _db.participantsLocal,
    )..where((t) => t.challengeId.equals(challengeId))).get();
    return [
      for (final row in rows)
        ChallengeParticipant(
          userId: row.userId,
          username: row.username,
          displayName: row.displayName,
          avatar: AvatarConfig(
            style: row.avatarStyle ?? 'adventurer',
            seed: row.avatarSeed ?? row.userId,
          ),
          role: ParticipantRole.fromId(row.role),
          currentCount: row.currentCount,
          lastEventId: row.lastEventId,
          joinedAt: row.joinedAt,
        ),
    ];
  }
}
