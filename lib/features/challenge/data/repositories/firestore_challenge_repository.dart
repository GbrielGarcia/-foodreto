import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/firebase/firestore_collections.dart';
import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../../activity/data/models/activity_dto.dart';
import '../../../activity/domain/services/official_activity_builder.dart';
import '../../../leaderboard/data/services/firestore_official_result_applier.dart';
import '../../../notifications/domain/entities/notification_type.dart';
import '../../../notifications/domain/services/notification_ids.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../social/domain/entities/friendship.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/challenge_event.dart';
import '../../domain/entities/challenge_participant.dart';
import '../../domain/entities/challenge_result.dart';
import '../../domain/entities/result_processing_status.dart';
import '../../domain/failures/challenge_failure.dart';
import '../../domain/repositories/challenge_repository.dart';
import '../../domain/usecases/challenge_usecases.dart';
import '../../domain/value_objects/invite_code.dart';
import '../datasources/challenge_remote_data_source.dart';
import '../models/challenge_dto.dart';

/// Retos en Firestore. Todas las operaciones que dependen del estado actual
/// (unirse, salir, iniciar, finalizar) son transacciones: si otro cliente
/// cambia el reto a la vez, Firestore reintenta con los datos nuevos. Las
/// reglas vuelven a validar cada escritura.
class FirestoreChallengeRepository implements ChallengeRepository {
  FirestoreChallengeRepository(
    this._source, {
    FirestoreOfficialResultApplier? officialApplier,
    String Function()? newInviteCode,
  }) : _newInviteCode = newInviteCode ?? InviteCode.generate,
       _officialApplier = officialApplier;

  final ChallengeRemoteDataSource _source;
  final String Function() _newInviteCode;

  /// Null = Cloud Functions materializa (`onChallengeResultCreated`).
  final FirestoreOfficialResultApplier? _officialApplier;

  static const _codeAttempts = 5;

  @override
  Future<Result<Challenge>> createChallenge(
    NewChallenge data,
    UserProfile host,
  ) async {
    final challengeRef = _source.challenges.doc();
    try {
      for (var attempt = 0; attempt < _codeAttempts; attempt++) {
        final code = _newInviteCode();
        final codeRef = _source.inviteCodes.doc(code);
        final reserved = await _source.db.runTransaction((tx) async {
          // Si otro reto reserva el mismo codigo a la vez, la transaccion se
          // reintenta y aqui ya lo ve ocupado.
          if ((await tx.get(codeRef)).exists) return false;
          tx
            ..set(
              challengeRef,
              ChallengeDto.toCreateMap(
                data: data,
                hostUserId: host.uid,
                inviteCode: code,
              ),
            )
            ..set(codeRef, {
              'challengeId': challengeRef.id,
              'createdAt': FieldValue.serverTimestamp(),
            })
            ..set(
              _source.participant(challengeRef.id, host.uid),
              ParticipantDto.toCreateMap(host, role: ParticipantRole.host),
            );
          return true;
        });
        if (reserved) {
          var challenge = Challenge(
            id: challengeRef.id,
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
          );
          // Spark: avisar a amigos al crear un reto visible (sin Functions).
          if (data.visibility != ChallengeVisibility.private) {
            await _writeJoinActivityBestEffort(
              challengeId: challenge.id,
              user: host,
              visibility: data.visibility,
              categoryId: data.categoryId,
              restaurantId: data.restaurantId,
            );
            await _notifyFriendsOfJoin(
              challengeId: challenge.id,
              user: host,
              asHost: true,
            );
          }
          if (data.sameDevicePlay) {
            final partnerIds = data.resolvedPartnerIds;
            if (partnerIds.isEmpty) {
              return const Result.failure(
                ChallengeFailure.invalidData('Falta el companero del reto.'),
              );
            }
            final addedIds = <String>[host.uid];
            for (final partnerId in partnerIds) {
              final partner = await _loadProfile(partnerId);
              if (partner == null) {
                return const Result.failure(
                  ChallengeFailure.invalidData(
                    'No encontramos el perfil de un companero.',
                  ),
                );
              }
              final added = await addSameDevicePartner(challenge.id, partner);
              if (added case Err(:final failure)) {
                return Result.failure(failure);
              }
              addedIds.add(partner.uid);
            }
            final started = await start(challenge.id, host.uid);
            if (started case Err(:final failure)) {
              return Result.failure(failure);
            }
            challenge = Challenge(
              id: challenge.id,
              hostUserId: challenge.hostUserId,
              categoryId: challenge.categoryId,
              restaurantId: challenge.restaurantId,
              title: challenge.title,
              description: challenge.description,
              inviteCode: challenge.inviteCode,
              visibility: challenge.visibility,
              status: ChallengeStatus.active,
              maxParticipants: challenge.maxParticipants,
              participantIds: addedIds,
              sameDevicePlay: true,
              sameDevicePartnerId: partnerIds.first,
              startedAt: DateTime.now(),
            );
          }
          return Result.success(challenge);
        }
      }
      return const Result.failure(ChallengeFailure.codeUnavailable());
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<Challenge?>> findByInviteCode(String code) async {
    try {
      final reservation = await _source.inviteCodes.doc(code).get();
      final id = reservation.data()?['challengeId'];
      if (id is! String) return const Result.success(null);
      final snapshot = await _source.challenge(id).get();
      return Result.success(ChallengeDto.fromMap(id, snapshot.data()));
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  @override
  Stream<Challenge?> watchChallenge(String challengeId) => _source
      .challenge(challengeId)
      .snapshots()
      .map((s) => ChallengeDto.fromMap(challengeId, s.data()));

  @override
  Stream<List<Challenge>> watchUserChallenges(String uid) => _source.challenges
      .where('participantIds', arrayContains: uid)
      .limit(50)
      .snapshots()
      .map(
        (query) => sortByRecent([
          for (final doc in query.docs)
            ?ChallengeDto.fromMap(doc.id, doc.data()),
        ]),
      );

  @override
  Future<Result<List<Challenge>>> listPublicByRestaurant({
    required String restaurantId,
    int limit = 20,
  }) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _source.challenges
            .where('restaurantId', isEqualTo: restaurantId)
            .where('visibility', isEqualTo: ChallengeVisibility.public.name)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
      } on FirebaseException catch (e) {
        if (e.code == 'failed-precondition') {
          snap = await _source.challenges
              .where('restaurantId', isEqualTo: restaurantId)
              .where('visibility', isEqualTo: ChallengeVisibility.public.name)
              .limit(limit)
              .get();
        } else {
          rethrow;
        }
      }
      final items = [
        for (final doc in snap.docs)
          if (ChallengeDto.fromMap(doc.id, doc.data()) case final c?) c,
      ]..sort((a, b) {
          final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });
      return Result.success(items);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<List<Challenge>>> listOpenPublicChallenges({
    int limit = 20,
  }) async {
    try {
      // Sin orderBy: evita indice compuesto; ordenamos en cliente.
      final snap = await _source.challenges
          .where('visibility', isEqualTo: ChallengeVisibility.public.name)
          .limit(limit * 3)
          .get();
      final items = [
        for (final doc in snap.docs)
          if (ChallengeDto.fromMap(doc.id, doc.data()) case final c?)
            if (!c.status.isClosed) c,
      ]..sort((a, b) {
          final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });
      return Result.success(items.take(limit).toList());
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<void>> join(String challengeId, UserProfile user) async {
    // Snapshot del participante debe coincidir con users/{uid} (Rules).
    final canonical = await _canonicalProfile(user);
    ChallengeVisibility? joinedVisibility;
    String? categoryId;
    String? restaurantId;
    final result = await _transaction(challengeId, (tx, challenge) {
      final blocker = joinBlocker(challenge, canonical.uid);
      if (blocker != null) throw _Fail(blocker);
      joinedVisibility = challenge.visibility;
      categoryId = challenge.categoryId;
      restaurantId = challenge.restaurantId;
      tx
        ..update(_source.challenge(challengeId), {
          'participantIds': [...challenge.participantIds, canonical.uid],
          'updatedAt': FieldValue.serverTimestamp(),
        })
        ..set(
          _source.participant(challengeId, canonical.uid),
          ParticipantDto.toCreateMap(
            canonical,
            role: ParticipantRole.participant,
          ),
        );
    });
    if (result.isSuccess &&
        joinedVisibility != null &&
        joinedVisibility != ChallengeVisibility.private) {
      // Fuera de la transaccion: si la activity falla, el join ya quedo.
      await _writeJoinActivityBestEffort(
        challengeId: challengeId,
        user: canonical,
        visibility: joinedVisibility!,
        categoryId: categoryId ?? '',
        restaurantId: restaurantId,
      );
      await _notifyFriendsOfJoin(challengeId: challengeId, user: canonical);
    }
    return result;
  }

  /// Lee el perfil canonico de Firestore para que isValidParticipant no falle
  /// por un displayName/avatar desfasado en el cliente.
  Future<UserProfile> _canonicalProfile(UserProfile fallback) async {
    try {
      final snap = await _source.db
          .collection(FirestoreCollections.users)
          .doc(fallback.uid)
          .get();
      final data = snap.data();
      if (data == null) return fallback;
      return UserProfile(
        uid: fallback.uid,
        username: data['username'] as String? ?? fallback.username,
        displayName: data['displayName'] as String? ?? fallback.displayName,
        bio: data['bio'] as String? ?? fallback.bio,
        avatar: AvatarConfig.fromData(
          style: data['avatarStyle'],
          seed: data['avatarSeed'],
          options: data['avatarOptions'],
        ),
        visibility: ProfileVisibility.values.firstWhere(
          (v) => v.name == data['visibility'],
          orElse: () => fallback.visibility,
        ),
        isActive: data['isActive'] as bool? ?? fallback.isActive,
        createdAt: fallback.createdAt,
        updatedAt: fallback.updatedAt,
      );
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _writeJoinActivityBestEffort({
    required String challengeId,
    required UserProfile user,
    required ChallengeVisibility visibility,
    required String categoryId,
    String? restaurantId,
  }) async {
    try {
      final activity = JoinActivityFactory.create(
        challengeId: challengeId,
        userId: user.uid,
        username: user.username,
        displayName: user.displayName,
        avatar: user.avatar,
        challengeVisibility: visibility,
        profileVisibility: user.visibility,
        categoryId: categoryId,
        restaurantId: restaurantId,
      );
      if (activity == null) return;
      final ref = _source.db
          .collection(FirestoreCollections.activities)
          .doc(activity.id);
      final existing = await ref.get();
      if (existing.exists) return;
      await ref.set(ActivityDto.toJoinCreateMap(activity));
    } catch (e, st) {
      // ignore: avoid_print
      print('FoodReto: join activity failed: $e\n$st');
    }
  }

  Future<void> _notifyFriendsOfJoin({
    required String challengeId,
    required UserProfile user,
    bool asHost = false,
  }) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _source.db
            .collection(FirestoreCollections.friendships)
            .where('userIds', arrayContains: user.uid)
            .where('status', isEqualTo: 'accepted')
            .limit(30)
            .get();
      } on FirebaseException catch (e) {
        // Sin indice compuesto: fallback y filtramos status en cliente.
        if (e.code != 'failed-precondition') rethrow;
        snap = await _source.db
            .collection(FirestoreCollections.friendships)
            .where('userIds', arrayContains: user.uid)
            .limit(50)
            .get();
      }

      final accepted = [
        for (final doc in snap.docs)
          if (doc.data()['status'] == 'accepted') doc,
      ];
      if (accepted.isEmpty) return;

      final batch = _source.db.batch();
      var writes = 0;
      final title = asHost ? 'Nuevo reto' : 'Amigo en un reto';
      final body = asHost
          ? '@${user.username} creo un reto. Unete!'
          : '@${user.username} se unio a un reto';
      for (final doc in accepted) {
        final ids = [
          for (final id in doc.data()['userIds'] as List? ?? const [])
            if (id is String) id,
        ];
        for (final friendId in ids) {
          if (friendId == user.uid) continue;
          final nId = 'friendJoined_${challengeId}_${user.uid}_$friendId';
          final nRef = _source.db
              .collection(FirestoreCollections.notifications)
              .doc(nId);
          if ((await nRef.get()).exists) continue;
          batch.set(nRef, {
            'recipientUserId': friendId,
            'type': 'friendJoinedChallenge',
            'actorUserId': user.uid,
            'actorUsername': user.username,
            'actorDisplayName': user.displayName,
            'actorAvatarStyle': user.avatar.style,
            'actorAvatarSeed': user.avatar.seed,
            'actorAvatarOptions': user.avatar.options,
            'title': title,
            'body': body,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'challengeId': challengeId,
            'targetRoute': '/challenges/$challengeId',
          });
          writes += 1;
          if (writes >= 25) break;
        }
        if (writes >= 25) break;
      }
      if (writes > 0) await batch.commit();
    } catch (e, st) {
      // ignore: avoid_print
      print('FoodReto: notifyFriendsOfJoin failed: $e\n$st');
    }
  }

  @override
  Future<Result<void>> leave(String challengeId, String uid) {
    return _transaction(challengeId, (tx, challenge) {
      if (!challenge.isParticipant(uid)) {
        throw const _Fail(ChallengeFailure.notParticipant());
      }
      if (challenge.isHost(uid)) {
        throw const _Fail(ChallengeFailure.hostCannotLeave());
      }
      if (!challenge.status.acceptsParticipants) {
        throw const _Fail(ChallengeFailure.invalidTransition());
      }
      tx
        ..update(_source.challenge(challengeId), {
          'participantIds': [
            for (final id in challenge.participantIds)
              if (id != uid) id,
          ],
          'updatedAt': FieldValue.serverTimestamp(),
        })
        ..delete(_source.participant(challengeId, uid));
    });
  }

  @override
  Future<Result<void>> start(String challengeId, String uid) {
    return _transaction(challengeId, (tx, challenge) {
      _checkHostTransition(challenge, uid, ChallengeStatus.active);
      tx.update(_source.challenge(challengeId), {
        'status': ChallengeStatus.active.name,
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<Result<void>> cancel(String challengeId, String uid) {
    return _transaction(challengeId, (tx, challenge) {
      _checkHostTransition(challenge, uid, ChallengeStatus.cancelled);
      tx.update(_source.challenge(challengeId), {
        'status': ChallengeStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<Result<void>> addSameDevicePartner(
    String challengeId,
    UserProfile partner,
  ) async {
    final canonical = await _canonicalProfile(partner);
    return _transaction(challengeId, (tx, challenge) {
      if (!challenge.sameDevicePlay) {
        throw const _Fail(
          ChallengeFailure.invalidData('Este reto no es de mismo celular.'),
        );
      }
      if (challenge.status != ChallengeStatus.waiting) {
        throw const _Fail(ChallengeFailure.invalidTransition());
      }
      if (challenge.participantIds.contains(canonical.uid)) {
        throw const _Fail(
          ChallengeFailure.invalidData('El companero ya fue anadido.'),
        );
      }
      if (challenge.isFull) {
        throw const _Fail(ChallengeFailure.full());
      }
      if (canonical.uid == challenge.hostUserId) {
        throw const _Fail(
          ChallengeFailure.invalidData('No puedes anadirte a ti mismo.'),
        );
      }
      tx
        ..update(_source.challenge(challengeId), {
          'participantIds': [...challenge.participantIds, canonical.uid],
          'sameDevicePartnerId': canonical.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        ..set(
          _source.participant(challengeId, canonical.uid),
          ParticipantDto.toCreateMap(
            canonical,
            role: ParticipantRole.participant,
          ),
        );
    });
  }

  @override
  Future<Result<void>> confirmPartnerResult({
    required String challengeId,
    required String uid,
    required bool accept,
  }) {
    return _transaction(challengeId, (tx, challenge) {
      if (!challenge.sameDevicePlay ||
          challenge.partnerResultStatus != PartnerResultStatus.pending ||
          !challenge.participantIds.contains(uid) ||
          challenge.isHost(uid) ||
          challenge.status != ChallengeStatus.finished) {
        throw const _Fail(ChallengeFailure.invalidTransition());
      }
      tx.update(_source.challenge(challengeId), {
        'partnerResultStatus': accept
            ? PartnerResultStatus.confirmed.name
            : PartnerResultStatus.rejected.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Lee el perfil canonico de Firestore para que isValidParticipant no falle
  /// por un displayName/avatar desfasado en el cliente.
  Future<UserProfile?> _loadProfile(String uid) async {
    try {
      final snap = await _source.db
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get();
      final data = snap.data();
      if (data == null) return null;
      return UserProfile(
        uid: uid,
        username: data['username'] as String? ?? '',
        displayName: data['displayName'] as String? ?? '',
        bio: data['bio'] as String? ?? '',
        avatar: AvatarConfig.fromData(
          style: data['avatarStyle'],
          seed: data['avatarSeed'],
          options: data['avatarOptions'],
        ),
        visibility: ProfileVisibility.values.firstWhere(
          (v) => v.name == data['visibility'],
          orElse: () => ProfileVisibility.public,
        ),
        isActive: data['isActive'] as bool? ?? true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _areFriends(String a, String b) async {
    try {
      final snap = await _source.db
          .collection(FirestoreCollections.friendships)
          .doc(Friendship.idFor(a, b))
          .get();
      return snap.data()?['status'] == FriendshipStatus.accepted.name;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Result<ChallengeResult>> finish(String challengeId, String uid) async {
    for (var attempt = 1; ; attempt++) {
      final result = await _finishOnce(challengeId, uid);
      final retry =
          result is Err<ChallengeResult> &&
          result.failure.code == 'permission-denied' &&
          attempt < _finishAttempts;
      if (!retry) {
        return switch (result) {
          Success(:final value) => () async {
            final official = await _applyOfficial(value);
            // Despues de materializar: notificar confirmacion (rules exigen finished).
            try {
              final snap = await _source.challenge(challengeId).get();
              final challenge =
                  ChallengeDto.fromMap(challengeId, snap.data());
              if (challenge != null &&
                  challenge.sameDevicePlay &&
                  challenge.partnerResultStatus ==
                      PartnerResultStatus.pending) {
                await _notifyPartnersConfirm(
                  challenge: challenge,
                  hostUid: uid,
                );
              }
            } catch (e, st) {
              // ignore: avoid_print
              print('FoodReto: notify confirm post-finish: $e\n$st');
            }
            return official;
          }(),
          Err() => result,
        };
      }
    }
  }

  Future<Result<ChallengeResult>> _applyOfficial(ChallengeResult result) async {
    final applier = _officialApplier;
    if (applier == null) {
      // Functions: onChallengeResultCreated hace el trabajo. Sin doble write.
      return Result.success(result);
    }
    try {
      final challengeSnap =
          await _source.challenge(result.challengeId).get();
      final visibility = ChallengeVisibility.fromId(
        challengeSnap.data()?['visibility'],
      );
      final withWinners = ChallengeResult(
        challengeId: result.challengeId,
        hostUserId: result.hostUserId,
        categoryId: result.categoryId,
        restaurantId: result.restaurantId,
        title: result.title,
        startedAt: result.startedAt,
        finishedAt: result.finishedAt ?? DateTime.now().toUtc(),
        entries: result.entries,
        winnerIds: winnerIdsFromEntries(result.entries),
        processingStatus: ResultProcessingStatus.pending,
      );
      final diff = await applier.apply(
        result: withWinners,
        visibility: visibility,
      );
      return Result.success(
        ChallengeResult(
          challengeId: withWinners.challengeId,
          hostUserId: withWinners.hostUserId,
          categoryId: withWinners.categoryId,
          restaurantId: withWinners.restaurantId,
          title: withWinners.title,
          startedAt: withWinners.startedAt,
          finishedAt: withWinners.finishedAt,
          entries: withWinners.entries,
          winnerIds: diff.winnerIds,
          processingStatus: ResultProcessingStatus.official,
        ),
      );
    } catch (e, st) {
      // El reto ya finalizo; el ranking puede backfillearse despues.
      // ignore: avoid_print
      print('FoodReto: applyOfficial failed for ${result.challengeId}: $e\n$st');
      return Result.success(result);
    }
  }

  /// Expone el applier para backfill desde providers (modo Spark).
  FirestoreOfficialResultApplier? get officialApplier => _officialApplier;

  static const _finishAttempts = 3;

  Future<Result<ChallengeResult>> _finishOnce(
    String challengeId,
    String uid,
  ) async {
    try {
      // Amistad fuera de la tx: decide si algun companero amigo debe confirmar.
      final preview = await _source.challenge(challengeId).get();
      final previewChallenge =
          ChallengeDto.fromMap(challengeId, preview.data());
      var needsPartnerConfirm = false;
      if (previewChallenge != null && previewChallenge.sameDevicePlay) {
        // Amigos: pedir confirmacion. Si la amistad no resuelve, igual
        // pedimos confirmacion cuando hay companeros (mismo celular).
        for (final otherId in previewChallenge.participantIds) {
          if (otherId == uid) continue;
          if (await _areFriends(uid, otherId)) {
            needsPartnerConfirm = true;
            break;
          }
        }
        if (!needsPartnerConfirm &&
            previewChallenge.participantIds.length > 1 &&
            previewChallenge.visibility == ChallengeVisibility.friends) {
          needsPartnerConfirm = true;
        }
      }

      final result = await _source.db.runTransaction((tx) async {
        final snapshot = await tx.get(_source.challenge(challengeId));
        final challenge = ChallengeDto.fromMap(challengeId, snapshot.data());
        if (challenge == null) throw const _Fail(ChallengeFailure.notFound());
        _checkHostTransition(challenge, uid, ChallengeStatus.finished);

        // Leer los contadores dentro de la transaccion: si alguien registra
        // un evento mientras tanto, Firestore reintenta con el valor nuevo.
        // Tras el commit las reglas rechazan cualquier evento (ya no esto
        // `active`), aso que el resultado no puede quedar desfasado.
        final participants = <ChallengeParticipant>[];
        for (final id in challenge.participantIds) {
          final p = await tx.get(_source.participant(challengeId, id));
          final participant = ParticipantDto.fromMap(id, p.data());
          if (participant == null) {
            throw const _Fail(ChallengeFailure.invalidTransition());
          }
          participants.add(participant);
        }

        final challengeUpdate = <String, Object?>{
          'status': ChallengeStatus.finished.name,
          'finishedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (needsPartnerConfirm) {
          challengeUpdate['partnerResultStatus'] =
              PartnerResultStatus.pending.name;
        }

        tx
          ..update(_source.challenge(challengeId), challengeUpdate)
          ..set(
            _source.results.doc(challengeId),
            ResultDto.toCreateMap(
              challenge,
              participants,
              snapshot.data()?['startedAt'],
            ),
          );

        return (
          ChallengeResult(
            challengeId: challengeId,
            hostUserId: challenge.hostUserId,
            categoryId: challenge.categoryId,
            restaurantId: challenge.restaurantId,
            title: challenge.title,
            startedAt: challenge.startedAt,
            entries: [
              for (final p in participants)
                ResultEntry(
                  userId: p.userId,
                  username: p.username,
                  displayName: p.displayName,
                  avatar: p.avatar,
                  count: p.currentCount,
                ),
            ],
          ),
          challenge,
          needsPartnerConfirm,
        );
      });

      final (challengeResult, _, _) = result;
      return Result.success(challengeResult);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<void> _notifyPartnersConfirm({
    required Challenge challenge,
    required String hostUid,
  }) async {
    final host = await _loadProfile(hostUid);
    for (final partnerId in challenge.participantIds) {
      if (partnerId == hostUid) continue;
      try {
        // Id propio (no choca con "Reto finalizado" oficial).
        // No hacer get() previo: el host no puede leer notifs de otros
        // (rules) y el fallo silenciaba el create.
        final nId = NotificationIds.sameDeviceConfirm(
          challenge.id,
          partnerId,
        );
        await _source.db
            .collection(FirestoreCollections.notifications)
            .doc(nId)
            .set({
          'recipientUserId': partnerId,
          'type': NotificationType.challengeCompleted.name,
          'actorUserId': hostUid,
          'actorUsername': host?.username ?? '',
          'actorDisplayName': host?.displayName ?? '',
          'actorAvatarStyle': host?.avatar.style ?? 'lorelei',
          'actorAvatarSeed': host?.avatar.seed ?? hostUid,
          'actorAvatarOptions': host?.avatar.options ?? <String, String>{},
          'title': 'Confirma el reto',
          'body':
              '${host?.displayName ?? 'Tu amigo'} finalizo el reto que jugaron '
              'en el mismo celular. Abre y acepta o rechaza el resultado.',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'challengeId': challenge.id,
          'targetRoute': '/challenges/${challenge.id}',
        });
      } catch (e, st) {
        // ignore: avoid_print
        print(
          'FoodReto: no se pudo notificar confirmacion a $partnerId: $e\n$st',
        );
      }
    }
  }

  @override
  Stream<ChallengeResult?> watchResult(String challengeId) => _source.results
      .doc(challengeId)
      .snapshots()
      .map((s) => ResultDto.fromMap(challengeId, s.data()));

  Future<Result<void>> _transaction(
    String challengeId,
    void Function(Transaction tx, Challenge challenge) body,
  ) async {
    try {
      await _source.db.runTransaction((tx) async {
        final snapshot = await tx.get(_source.challenge(challengeId));
        final challenge = ChallengeDto.fromMap(challengeId, snapshot.data());
        if (challenge == null) throw const _Fail(ChallengeFailure.notFound());
        body(tx, challenge);
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  static void _checkHostTransition(
    Challenge challenge,
    String uid,
    ChallengeStatus next,
  ) {
    if (!challenge.isHost(uid)) throw const _Fail(ChallengeFailure.notHost());
    if (!challenge.status.canTransitionTo(next)) {
      throw const _Fail(ChallengeFailure.invalidTransition());
    }
  }
}

class FirestoreChallengeParticipantRepository
    implements ChallengeParticipantRepository {
  const FirestoreChallengeParticipantRepository(this._source);

  final ChallengeRemoteDataSource _source;

  @override
  Stream<List<ChallengeParticipant>> watchParticipants(String challengeId) =>
      _source
          .participants(challengeId)
          .snapshots()
          .map(
            (query) => sortParticipants([
              for (final doc in query.docs)
                ?ParticipantDto.fromMap(doc.id, doc.data()),
            ]),
          );
}

/// +1 / ?1 como `WriteBatch` (no transaccion) para que la cacho local de
/// Firestore aplique el cambio al instante (latency compensation): la UI no
/// espera a la red. Si el servidor rechaza el batch, el SDK revierte la cacho
/// y el contador vuelve solo a su valor real.
class FirestoreChallengeEventRepository implements ChallengeEventRepository {
  const FirestoreChallengeEventRepository(this._source);

  final ChallengeRemoteDataSource _source;

  @override
  Future<Result<void>> recordEvent(
    String challengeId,
    ChallengeEvent event,
  ) async {
    final eventRef = _source.events(challengeId).doc(event.clientEventId);
    try {
      await (_source.db.batch()
            ..set(eventRef, EventDto.toMap(event))
            ..update(_source.participant(challengeId, event.userId), {
              'currentCount': FieldValue.increment(event.delta),
              'lastEventId': event.clientEventId,
            }))
          .commit();
      return const Result.success(null);
    } catch (e) {
      // Un reintento de un evento ya aplicado lo rechazan las reglas (los
      // eventos son create-only). Si el evento existe, ya esto contado: exito.
      if (e is FirebaseException && e.code == 'permission-denied') {
        try {
          final existing = await eventRef.get();
          if (existing.data()?['userId'] == event.userId) {
            return const Result.success(null);
          }
        } catch (_) {
          // Sin acceso o sin red: se informa el error original.
        }
      }
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<List<ChallengeEvent>>> getEvents(String challengeId) async {
    try {
      final query = await _source.events(challengeId).get();
      return Result.success([
        for (final doc in query.docs) ?EventDto.fromMap(doc.id, doc.data()),
      ]);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }
}

/// Mas recientes primero; los recion creados (sin fecha del servidor) arriba.
List<Challenge> sortByRecent(List<Challenge> challenges) =>
    challenges..sort((a, b) {
      final ad = a.createdAt, bd = b.createdAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return -1;
      if (bd == null) return 1;
      return bd.compareTo(ad);
    });

/// Host primero y despuos por orden de llegada.
List<ChallengeParticipant> sortParticipants(List<ChallengeParticipant> list) =>
    list..sort((a, b) {
      if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
      final ad = a.joinedAt, bd = b.joinedAt;
      if (ad == null && bd == null) return a.userId.compareTo(b.userId);
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });

Failure _mapError(Object error) =>
    error is _Fail ? error.failure : mapFirestoreError(error);

class _Fail implements Exception {
  const _Fail(this.failure);
  final ChallengeFailure failure;
}
