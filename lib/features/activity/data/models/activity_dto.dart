import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../domain/entities/activity_visibility.dart';
import '../../domain/entities/social_activity.dart';
import '../../domain/entities/social_activity_type.dart';
import '../../domain/services/feed_merger.dart';

abstract final class ActivityDto {
  static SocialActivity? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final type = SocialActivityType.tryParse(data['type']);
    final visibility = ActivityVisibility.tryParse(data['visibility']);
    final actorUserId = data['actorUserId'] as String?;
    final createdAt = readTimestamp(data['createdAt']);
    if (type == null ||
        visibility == null ||
        actorUserId == null ||
        actorUserId.isEmpty ||
        createdAt == null) {
      return null;
    }
    return SocialActivity(
      id: id,
      type: type,
      actorUserId: actorUserId,
      actorUsername: data['actorUsername'] as String? ?? '',
      actorDisplayName: data['actorDisplayName'] as String? ?? '',
      actorAvatar: AvatarConfig.fromData(
        style: data['actorAvatarStyle'],
        seed: data['actorAvatarSeed'],
        options: data['actorAvatarOptions'],
      ),
      visibility: visibility,
      createdAt: createdAt,
      challengeId: data['challengeId'] as String?,
      categoryId: data['categoryId'] as String?,
      categoryName: data['categoryName'] as String?,
      categoryIcon: data['categoryIcon'] as String?,
      restaurantId: data['restaurantId'] as String?,
      restaurantName: data['restaurantName'] as String?,
      score: (data['score'] as num?)?.toInt(),
      previousRecordScore: (data['previousRecordScore'] as num?)?.toInt(),
      scopeKey: data['scopeKey'] as String?,
    );
  }

  static Map<String, Object?> toMap(SocialActivity a, {bool forCreate = false}) {
    return {
      'type': a.type.name,
      'actorUserId': a.actorUserId,
      'actorUsername': a.actorUsername,
      'actorDisplayName': a.actorDisplayName,
      'actorAvatarStyle': a.actorAvatar.style,
      'actorAvatarSeed': a.actorAvatar.seed,
      'actorAvatarOptions': a.actorAvatar.options,
      'visibility': a.visibility.name,
      'createdAt': forCreate
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(a.createdAt.toUtc()),
      'challengeId': a.challengeId,
      'categoryId': a.categoryId,
      'categoryName': a.categoryName,
      'categoryIcon': a.categoryIcon,
      'restaurantId': a.restaurantId,
      'restaurantName': a.restaurantName,
      'score': a.score,
      'previousRecordScore': a.previousRecordScore,
      'scopeKey': a.scopeKey,
    };
  }

  /// Campos permitidos al cliente para `friendJoinedChallenge`.
  static Map<String, Object?> toJoinCreateMap(SocialActivity a) {
    final map = <String, Object?>{
      'type': SocialActivityType.friendJoinedChallenge.name,
      'actorUserId': a.actorUserId,
      'actorUsername': a.actorUsername,
      'actorDisplayName': a.actorDisplayName,
      'actorAvatarStyle': a.actorAvatar.style,
      'actorAvatarSeed': a.actorAvatar.seed,
      'actorAvatarOptions': a.actorAvatar.options,
      'visibility': a.visibility.name,
      'createdAt': FieldValue.serverTimestamp(),
      'challengeId': a.challengeId,
      'categoryId': a.categoryId,
    };
    // Incluir opcionales solo si tienen valor (Rules hasOnly los admite).
    if (a.categoryName != null) map['categoryName'] = a.categoryName;
    if (a.categoryIcon != null) map['categoryIcon'] = a.categoryIcon;
    if (a.restaurantId != null) map['restaurantId'] = a.restaurantId;
    if (a.restaurantName != null) map['restaurantName'] = a.restaurantName;
    return map;
  }

  static String? encodeCursor(SocialActivity last) =>
      ActivityCursor.encode(last.createdAt, last.id);

  static ({DateTime createdAt, String id})? decodeCursor(String? cursor) =>
      ActivityCursor.decode(cursor);
}
