import 'dart:async';

import '../../../../core/error/result.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/challenge_event.dart';
import '../../domain/entities/challenge_participant.dart';
import '../../domain/entities/challenge_result.dart';
import '../../domain/failures/challenge_failure.dart';
import '../../../activity/data/repositories/in_memory_activity_repository.dart';
import '../../../activity/domain/services/official_activity_builder.dart';
import '../../../leaderboard/data/repositories/in_memory_leaderboard_repository.dart';
import '../../../notifications/data/repositories/in_memory_notification_repository.dart';
import '../../../notifications/domain/services/official_notification_builder.dart';
import '../../domain/entities/result_processing_status.dart';
import '../../domain/repositories/challenge_repository.dart';
import '../../domain/usecases/challenge_usecases.dart';
import '../../domain/value_objects/invite_code.dart';
import 'firestore_challenge_repository.dart'
    show sortByRecent, sortParticipants;

/// Retos en memoria (modo local y tests) con las mismas validaciones que
/// Firestore + reglas. Cada operación es síncrona dentro del event loop, así
/// que es atómica: sirve para probar concurrencia y cupos.
class InMemoryChallengeBackend
    implements
        ChallengeRepository,
        ChallengeParticipantRepository,
        ChallengeEventRepository {
  InMemoryChallengeBackend({
    String Function()? newInviteCode,
    InMemoryLeaderboardRepository? officialStats,
    InMemoryActivityRepository? activities,
    InMemoryNotificationRepository? notifications,
  }) : _newInviteCode = newInviteCode ?? InviteCode.generate,
       _officialStats = officialStats,
       _activities = activities,
       _notifications = notifications;

  final String Function() _newInviteCode;
  final InMemoryLeaderboardRepository? _officialStats;
  final InMemoryActivityRepository? _activities;
  final InMemoryNotificationRepository? _notifications;
  final _challenges = <String, Challenge>{};
  final _codes = <String, String>{};
  final _participants = <String, Map<String, ChallengeParticipant>>{};
  final _events = <String, Map<String, ChallengeEvent>>{};
  final _results = <String, ChallengeResult>{};
  final _changes = StreamController<String>.broadcast();
  var _nextId = 0;

  /// Solo para inspección en tests.
  Map<String, String> get inviteCodeIndex => Map.unmodifiable(_codes);

  @override
  Future<Result<Challenge>> createChallenge(
    NewChallenge data,
    UserProfile host,
  ) async {
    String? code;
    for (var attempt = 0; attempt < 5 && code == null; attempt++) {
      final candidate = _newInviteCode();
      if (!_codes.containsKey(candidate)) code = candidate;
    }
    if (code == null) {
      return const Result.failure(ChallengeFailure.codeUnavailable());
    }
    final id = 'c${++_nextId}';
    final now = DateTime.now();
    final challenge = Challenge(
      id: id,
      hostUserId: host.uid,
      categoryId: data.categoryId,
      restaurantId: data.restaurantId,
      title: data.title,
      description: data.description,
      inviteCode: code,
      visibility: data.visibility,
      status: ChallengeStatus.waiting,
      maxParticipants: data.maxParticipants,
      participantIds: [host.uid],
      sameDevicePlay: data.sameDevicePlay,
      createdAt: now,
      updatedAt: now,
    );
    _codes[code] = id;
    _challenges[id] = challenge;
    _participants[id] = {
      host.uid: _participantFrom(host, ParticipantRole.host, now),
    };
    _events[id] = {};
    _notify(id);

    if (data.sameDevicePlay) {
      final partnerId = data.sameDevicePartnerId;
      if (partnerId == null) {
        return const Result.failure(
          ChallengeFailure.invalidData('Falta el companero del reto.'),
        );
      }
      // En memoria el perfil del partner debe existir ya en participants map
      // via addSameDevicePartner llamado por el controlador con perfil real.
      // Aqui solo dejamos waiting; el controller/repo firebase lo completa.
    }
    return Result.success(challenge);
  }

  @override
  Future<Result<void>> addSameDevicePartner(
    String challengeId,
    UserProfile partner,
  ) async {
    final c = _challenges[challengeId];
    if (c == null) return const Result.failure(ChallengeFailure.notFound());
    if (!c.sameDevicePlay || c.status != ChallengeStatus.waiting) {
      return const Result.failure(ChallengeFailure.invalidTransition());
    }
    if (c.participantIds.contains(partner.uid)) {
      return const Result.failure(
        ChallengeFailure.invalidData('El companero ya fue anadido.'),
      );
    }
    if (c.isFull) {
      return const Result.failure(ChallengeFailure.full());
    }
    final now = DateTime.now();
    _challenges[challengeId] = Challenge(
      id: c.id,
      hostUserId: c.hostUserId,
      categoryId: c.categoryId,
      restaurantId: c.restaurantId,
      title: c.title,
      description: c.description,
      inviteCode: c.inviteCode,
      visibility: c.visibility,
      status: c.status,
      maxParticipants: c.maxParticipants,
      participantIds: [...c.participantIds, partner.uid],
      sameDevicePlay: true,
      sameDevicePartnerId: partner.uid,
      partnerResultStatus: c.partnerResultStatus,
      createdAt: c.createdAt,
      startedAt: c.startedAt,
      finishedAt: c.finishedAt,
      updatedAt: now,
    );
    _participants[challengeId]![partner.uid] =
        _participantFrom(partner, ParticipantRole.participant, now);
    _notify(challengeId);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> confirmPartnerResult({
    required String challengeId,
    required String uid,
    required bool accept,
  }) async {
    final c = _challenges[challengeId];
    if (c == null) return const Result.failure(ChallengeFailure.notFound());
    if (!c.sameDevicePlay ||
        c.partnerResultStatus != PartnerResultStatus.pending ||
        c.sameDevicePartnerId != uid ||
        c.status != ChallengeStatus.finished) {
      return const Result.failure(ChallengeFailure.invalidTransition());
    }
    _challenges[challengeId] = Challenge(
      id: c.id,
      hostUserId: c.hostUserId,
      categoryId: c.categoryId,
      restaurantId: c.restaurantId,
      title: c.title,
      description: c.description,
      inviteCode: c.inviteCode,
      visibility: c.visibility,
      status: c.status,
      maxParticipants: c.maxParticipants,
      participantIds: c.participantIds,
      sameDevicePlay: c.sameDevicePlay,
      sameDevicePartnerId: c.sameDevicePartnerId,
      partnerResultStatus: accept
          ? PartnerResultStatus.confirmed
          : PartnerResultStatus.rejected,
      createdAt: c.createdAt,
      startedAt: c.startedAt,
      finishedAt: c.finishedAt,
      updatedAt: DateTime.now(),
    );
    _notify(challengeId);
    return const Result.success(null);
  }

  @override
  Future<Result<Challenge?>> findByInviteCode(String code) async {
    final id = _codes[code];
    return Result.success(id == null ? null : _challenges[id]);
  }

  @override
  Stream<Challenge?> watchChallenge(String challengeId) =>
      _watch(challengeId, () => _challenges[challengeId]);

  @override
  Stream<List<Challenge>> watchUserChallenges(String uid) => _watch(
    null,
    () => sortByRecent([
      for (final c in _challenges.values)
        if (c.isParticipant(uid)) c,
    ]),
  );

  @override
  Future<Result<List<Challenge>>> listPublicByRestaurant({
    required String restaurantId,
    int limit = 20,
  }) async {
    final items = [
      for (final c in _challenges.values)
        if (c.restaurantId == restaurantId &&
            c.visibility == ChallengeVisibility.public)
          c,
    ]..sort((a, b) {
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
    return Result.success(items.take(limit).toList());
  }

  @override
  Future<Result<List<Challenge>>> listOpenPublicChallenges({
    int limit = 20,
  }) async {
    final items = [
      for (final c in _challenges.values)
        if (c.visibility == ChallengeVisibility.public && !c.status.isClosed) c,
    ]..sort((a, b) {
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
    return Result.success(items.take(limit).toList());
  }

  @override
  Stream<List<ChallengeParticipant>> watchParticipants(String challengeId) =>
      _watch(
        challengeId,
        () => sortParticipants([...?_participants[challengeId]?.values]),
      );

  @override
  Stream<ChallengeResult?> watchResult(String challengeId) =>
      _watch(challengeId, () => _results[challengeId]);

  @override
  Future<Result<void>> join(String challengeId, UserProfile user) async {
    final challenge = _challenges[challengeId];
    if (challenge == null) {
      return const Result.failure(ChallengeFailure.notFound());
    }
    final blocker = joinBlocker(challenge, user.uid);
    if (blocker != null) return Result.failure(blocker);
    _update(challenge, participantIds: [...challenge.participantIds, user.uid]);
    _participants[challengeId]![user.uid] = _participantFrom(
      user,
      ParticipantRole.participant,
      DateTime.now(),
    );
    if (challenge.visibility != ChallengeVisibility.private) {
      final activity = JoinActivityFactory.create(
        challengeId: challengeId,
        userId: user.uid,
        username: user.username,
        displayName: user.displayName,
        avatar: user.avatar,
        challengeVisibility: challenge.visibility,
        profileVisibility: user.visibility,
        categoryId: challenge.categoryId,
        restaurantId: challenge.restaurantId,
      );
      if (activity != null) {
        await _activities?.upsertJoinActivity(activity);
      }
    }
    _notify(challengeId);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> leave(String challengeId, String uid) async {
    final challenge = _challenges[challengeId];
    if (challenge == null) {
      return const Result.failure(ChallengeFailure.notFound());
    }
    if (!challenge.isParticipant(uid)) {
      return const Result.failure(ChallengeFailure.notParticipant());
    }
    if (challenge.isHost(uid)) {
      return const Result.failure(ChallengeFailure.hostCannotLeave());
    }
    if (!challenge.status.acceptsParticipants) {
      return const Result.failure(ChallengeFailure.invalidTransition());
    }
    _update(
      challenge,
      participantIds: [
        for (final id in challenge.participantIds)
          if (id != uid) id,
      ],
    );
    _participants[challengeId]!.remove(uid);
    _notify(challengeId);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> start(String challengeId, String uid) async =>
      _transition(challengeId, uid, ChallengeStatus.active);

  @override
  Future<Result<void>> cancel(String challengeId, String uid) async =>
      _transition(challengeId, uid, ChallengeStatus.cancelled);

  @override
  Future<Result<ChallengeResult>> finish(String challengeId, String uid) async {
    final failure = _checkTransition(
      challengeId,
      uid,
      ChallengeStatus.finished,
    );
    if (failure != null) return Result.failure(failure);
    final challenge = _challenges[challengeId]!;
    final participants = _participants[challengeId]!;
    final now = DateTime.now();
    final entries = [
      for (final id in challenge.participantIds)
        if (participants[id] case final p?)
          ResultEntry(
            userId: p.userId,
            username: p.username,
            displayName: p.displayName,
            avatar: p.avatar,
            count: p.currentCount,
          ),
    ];
    var result = ChallengeResult(
      challengeId: challengeId,
      hostUserId: challenge.hostUserId,
      categoryId: challenge.categoryId,
      restaurantId: challenge.restaurantId,
      title: challenge.title,
      startedAt: challenge.startedAt,
      finishedAt: now,
      entries: entries,
      winnerIds: winnerIdsFromEntries(entries),
      processingStatus: ResultProcessingStatus.pending,
    );
    final stats = _officialStats;
    if (stats != null) {
      final eligible = challenge.visibility == ChallengeVisibility.public;
      final diff = stats.applyResult(result, rankingEligible: eligible);
      result = ChallengeResult(
        challengeId: result.challengeId,
        hostUserId: result.hostUserId,
        categoryId: result.categoryId,
        restaurantId: result.restaurantId,
        title: result.title,
        startedAt: result.startedAt,
        finishedAt: result.finishedAt,
        entries: result.entries,
        winnerIds: diff.winnerIds,
        processingStatus: ResultProcessingStatus.official,
      );
      final acts = OfficialActivityBuilder.build(
        result: result,
        diff: diff,
        challengeVisibility: challenge.visibility,
      );
      await _activities?.upsertOfficialActivities(acts);
      final notifs = OfficialNotificationBuilder.fromResult(
        result: result,
        diff: diff,
      );
      for (final n in notifs) {
        await _notifications?.upsert(n);
      }
    }
    _update(challenge, status: ChallengeStatus.finished, finishedAt: now);
    _results[challengeId] = result;
    _notify(challengeId);
    return Result.success(result);
  }

  @override
  Future<Result<void>> recordEvent(
    String challengeId,
    ChallengeEvent event,
  ) async {
    final challenge = _challenges[challengeId];
    if (challenge == null) {
      return const Result.failure(ChallengeFailure.notFound());
    }
    final events = _events[challengeId]!;
    // Idempotencia: un ID ya registrado no vuelve a contar.
    if (events.containsKey(event.clientEventId)) {
      return const Result.success(null);
    }
    if (!challenge.status.acceptsEvents) {
      return const Result.failure(ChallengeFailure.notActive());
    }
    final participant = _participants[challengeId]![event.userId];
    if (participant == null) {
      return const Result.failure(ChallengeFailure.notParticipant());
    }
    final next = participant.currentCount + event.delta;
    if (next < 0) return const Result.failure(ChallengeFailure.negativeCount());
    events[event.clientEventId] = ChallengeEvent(
      clientEventId: event.clientEventId,
      userId: event.userId,
      type: event.type,
      createdAt: DateTime.now(),
    );
    _participants[challengeId]![event.userId] = participant.copyWith(
      currentCount: next,
      lastEventId: event.clientEventId,
    );
    _notify(challengeId);
    return const Result.success(null);
  }

  @override
  Future<Result<List<ChallengeEvent>>> getEvents(String challengeId) async =>
      Result.success([...?_events[challengeId]?.values]);

  Result<void> _transition(String id, String uid, ChallengeStatus next) {
    final failure = _checkTransition(id, uid, next);
    if (failure != null) return Result.failure(failure);
    _update(
      _challenges[id]!,
      status: next,
      startedAt: next == ChallengeStatus.active ? DateTime.now() : null,
    );
    _notify(id);
    return const Result.success(null);
  }

  ChallengeFailure? _checkTransition(
    String id,
    String uid,
    ChallengeStatus next,
  ) {
    final challenge = _challenges[id];
    if (challenge == null) return const ChallengeFailure.notFound();
    if (!challenge.isHost(uid)) return const ChallengeFailure.notHost();
    if (!challenge.status.canTransitionTo(next)) {
      return const ChallengeFailure.invalidTransition();
    }
    return null;
  }

  void _update(
    Challenge c, {
    List<String>? participantIds,
    ChallengeStatus? status,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    _challenges[c.id] = Challenge(
      id: c.id,
      hostUserId: c.hostUserId,
      categoryId: c.categoryId,
      restaurantId: c.restaurantId,
      title: c.title,
      description: c.description,
      inviteCode: c.inviteCode,
      visibility: c.visibility,
      status: status ?? c.status,
      maxParticipants: c.maxParticipants,
      participantIds: participantIds ?? c.participantIds,
      createdAt: c.createdAt,
      startedAt: startedAt ?? c.startedAt,
      finishedAt: finishedAt ?? c.finishedAt,
      updatedAt: DateTime.now(),
    );
  }

  static ChallengeParticipant _participantFrom(
    UserProfile profile,
    ParticipantRole role,
    DateTime joinedAt,
  ) => ChallengeParticipant(
    userId: profile.uid,
    username: profile.username,
    displayName: profile.displayName,
    avatar: profile.avatar,
    role: role,
    joinedAt: joinedAt,
  );

  void _notify(String challengeId) => _changes.add(challengeId);

  /// Emite el valor actual al suscribirse y de nuevo con cada cambio del
  /// reto [challengeId] (o de cualquiera si es `null`).
  Stream<T> _watch<T>(String? challengeId, T Function() read) {
    StreamSubscription<String>? subscription;
    late final StreamController<T> output;
    output = StreamController<T>(
      onListen: () {
        output.add(read());
        subscription = _changes.stream
            .where((id) => challengeId == null || id == challengeId)
            .listen((_) => output.add(read()));
      },
      onCancel: () => subscription?.cancel(),
    );
    return output.stream;
  }

  Future<void> dispose() => _changes.close();
}
