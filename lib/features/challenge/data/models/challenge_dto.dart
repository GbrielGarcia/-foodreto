import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/challenge_event.dart';
import '../../domain/entities/challenge_participant.dart';
import '../../domain/entities/challenge_result.dart';
import '../../domain/entities/result_processing_status.dart';

/// Conversión entre Firestore y el dominio. Los nombres de campo deben
/// coincidir con `firestore.rules`.
abstract final class ChallengeDto {
  static Challenge? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final host = data['hostUserId'];
    final category = data['categoryId'];
    final code = data['inviteCode'];
    if (host is! String || category is! String || code is! String) return null;
    return Challenge(
      id: id,
      hostUserId: host,
      categoryId: category,
      restaurantId: data['restaurantId'] as String?,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      inviteCode: code,
      visibility: ChallengeVisibility.fromId(data['visibility']),
      status: ChallengeStatus.fromId(data['status']),
      maxParticipants:
          (data['maxParticipants'] as num?)?.toInt() ??
          Challenge.defaultMaxParticipants,
      participantIds: [
        for (final uid in data['participantIds'] as List? ?? const [])
          if (uid is String) uid,
      ],
      sameDevicePlay: data['sameDevicePlay'] == true,
      sameDevicePartnerId: data['sameDevicePartnerId'] as String?,
      partnerResultStatus: PartnerResultStatus.fromId(
        data['partnerResultStatus'],
      ),
      createdAt: readTimestamp(data['createdAt']),
      startedAt: readTimestamp(data['startedAt']),
      finishedAt: readTimestamp(data['finishedAt']),
      updatedAt: readTimestamp(data['updatedAt']),
    );
  }

  static Map<String, Object?> toCreateMap({
    required NewChallenge data,
    required String hostUserId,
    required String inviteCode,
  }) => {
    'hostUserId': hostUserId,
    'categoryId': data.categoryId,
    'restaurantId': data.restaurantId,
    'title': data.title,
    'description': data.description,
    'inviteCode': inviteCode,
    'visibility': data.visibility.name,
    'status': ChallengeStatus.waiting.name,
    'maxParticipants': data.maxParticipants,
    'participantIds': [hostUserId],
    'sameDevicePlay': data.sameDevicePlay,
    'sameDevicePartnerId': null,
    'partnerResultStatus': PartnerResultStatus.notRequired.name,
    'createdAt': FieldValue.serverTimestamp(),
    'startedAt': null,
    'finishedAt': null,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

abstract final class ParticipantDto {
  static ChallengeParticipant? fromMap(String uid, Map<String, dynamic>? data) {
    if (data == null) return null;
    return ChallengeParticipant(
      userId: uid,
      username: data['username'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      avatar: _avatar(data),
      role: ParticipantRole.fromId(data['role']),
      currentCount: (data['currentCount'] as num?)?.toInt() ?? 0,
      lastEventId: data['lastEventId'] as String?,
      joinedAt: readTimestamp(data['joinedAt']),
    );
  }

  static Map<String, Object?> toCreateMap(
    UserProfile profile, {
    required ParticipantRole role,
  }) => {
    'userId': profile.uid,
    'username': profile.username,
    'displayName': profile.displayName,
    ...profile.avatar.toData(),
    'role': role.name,
    'status': 'joined',
    'currentCount': 0,
    'lastEventId': null,
    'joinedAt': FieldValue.serverTimestamp(),
  };
}

abstract final class EventDto {
  static ChallengeEvent? fromMap(String id, Map<String, dynamic>? data) {
    final type = ChallengeEventType.fromId(data?['type']);
    final user = data?['userId'];
    if (type == null || user is! String) return null;
    return ChallengeEvent(
      clientEventId: id,
      userId: user,
      type: type,
      createdAt: readTimestamp(data?['createdAt']),
    );
  }

  static Map<String, Object> toMap(ChallengeEvent event) => {
    'clientEventId': event.clientEventId,
    'userId': event.userId,
    'type': event.type.name,
    'amount': ChallengeEvent.amount,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

abstract final class ResultDto {
  static ChallengeResult? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final statusRaw = data['processingStatus'] as String?;
    final status = ResultProcessingStatus.values.firstWhere(
      (s) => s.name == statusRaw,
      orElse: () => ResultProcessingStatus.pending,
    );
    return ChallengeResult(
      challengeId: id,
      hostUserId: data['hostUserId'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      restaurantId: data['restaurantId'] as String?,
      title: data['title'] as String? ?? '',
      startedAt: readTimestamp(data['startedAt']),
      finishedAt: readTimestamp(data['finishedAt']),
      processingStatus: status,
      winnerIds: [
        for (final id in data['winnerIds'] as List? ?? const [])
          if (id is String) id,
      ],
      entries: [
        for (final raw in data['participants'] as List? ?? const [])
          if (raw is Map)
            ResultEntry(
              userId: raw['userId'] as String? ?? '',
              username: raw['username'] as String? ?? '',
              displayName: raw['displayName'] as String? ?? '',
              avatar: _avatar(raw),
              count: (raw['count'] as num?)?.toInt() ?? 0,
            ),
      ],
    );
  }

  /// [participants] en el mismo orden que `challenge.participantIds`: las
  /// reglas comparan posición a posición.
  static Map<String, Object?> toCreateMap(
    Challenge challenge,
    List<ChallengeParticipant> participants,
    Object? startedAt,
  ) => {
    'challengeId': challenge.id,
    'hostUserId': challenge.hostUserId,
    'categoryId': challenge.categoryId,
    'restaurantId': challenge.restaurantId,
    'title': challenge.title,
    'participantIds': challenge.participantIds,
    'participants': [
      for (final p in participants)
        {
          'userId': p.userId,
          'username': p.username,
          'displayName': p.displayName,
          ...p.avatar.toData(),
          'count': p.currentCount,
        },
    ],
    'startedAt': startedAt,
    'finishedAt': FieldValue.serverTimestamp(),
    'createdAt': FieldValue.serverTimestamp(),
  };
}

AvatarConfig _avatar(Map<dynamic, dynamic> data) => AvatarConfig.fromData(
  style: data['avatarStyle'],
  seed: data['avatarSeed'],
  options: data['avatarOptions'],
);
