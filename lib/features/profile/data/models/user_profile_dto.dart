import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_statistics.dart';

/// Conversión entre `users/{uid}` y [UserProfile].
///
/// El correo no se guarda aquí: `users/{uid}` será legible públicamente
/// cuando existan perfiles públicos, y Firestore no restringe lecturas por
/// campo. Va en `users/{uid}/private/account`.
abstract final class UserProfileDto {
  /// `null` si el documento no existe o no tiene username (perfil incompleto).
  static UserProfile? fromMap(String uid, Map<String, dynamic>? data) {
    if (data == null) return null;
    final username = data['username'];
    if (username is! String || username.isEmpty) return null;
    final displayName = data['displayName'];
    final bio = data['bio'];
    return UserProfile(
      uid: uid,
      username: username,
      displayName: displayName is String ? displayName : username,
      bio: bio is String ? bio : '',
      avatar: AvatarConfig.fromData(
        style: data['avatarStyle'],
        seed: data['avatarSeed'],
        options: data['avatarOptions'],
      ),
      visibility: data['visibility'] == 'private'
          ? ProfileVisibility.private
          : ProfileVisibility.public,
      isActive: data['isActive'] != false,
      createdAt: readTimestamp(data['createdAt']),
      updatedAt: readTimestamp(data['updatedAt']),
    );
  }

  static Map<String, Object> toCreateMap(NewProfile profile) => {
    'uid': profile.uid,
    'username': profile.username,
    'displayName': profile.displayName,
    'displayNameLower': profile.displayName.toLowerCase(),
    'bio': profile.bio,
    ...profile.avatar.toData(),
    'visibility': ProfileVisibility.public.name,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static Map<String, Object> toUpdateMap(ProfileChanges changes) => {
    if (changes.username != null) 'username': changes.username!,
    if (changes.displayName != null) 'displayName': changes.displayName!,
    if (changes.displayName != null)
      'displayNameLower': changes.displayName!.toLowerCase(),
    if (changes.bio != null) 'bio': changes.bio!,
    if (changes.avatar != null) ...changes.avatar!.toData(),
    if (changes.visibility != null) 'visibility': changes.visibility!.name,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

abstract final class UserStatisticsDto {
  static UserStatistics fromMap(Map<String, dynamic>? data) {
    if (data == null) return UserStatistics.empty;
    int count(String key) {
      final value = data[key];
      return value is num && value >= 0 ? value.toInt() : 0;
    }

    return UserStatistics(
      challengeCount: count('challengeCount'),
      winCount: count('winCount'),
      recordCount: count('recordCount'),
      totalUnits: count('totalUnits'),
      bestScore: count('bestScore'),
      restaurantCount: count('restaurantCount'),
      categoryCount: count('categoryCount'),
      updatedAt: readTimestamp(data['updatedAt']),
    );
  }
}
