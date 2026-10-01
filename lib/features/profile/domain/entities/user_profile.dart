import '../../../../core/avatar/avatar_config.dart';

enum ProfileVisibility { public, private }

/// Perfil público del usuario (`users/{uid}`).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.avatar,
    this.bio = '',
    this.visibility = ProfileVisibility.public,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;

  /// Siempre en minúsculas, sin `@`.
  final String username;
  final String displayName;
  final AvatarConfig avatar;
  final String bio;
  final ProfileVisibility visibility;
  final bool isActive;

  /// `null` mientras el servidor no confirma la escritura.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const maxBioLength = 160;

  UserProfile copyWith({
    String? username,
    String? displayName,
    AvatarConfig? avatar,
    String? bio,
    ProfileVisibility? visibility,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      visibility: visibility ?? this.visibility,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Datos para crear el perfil en el onboarding.
class NewProfile {
  const NewProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.avatar,
    this.email,
    this.bio = '',
  });

  final String uid;
  final String username;
  final String displayName;
  final AvatarConfig avatar;
  final String? email;
  final String bio;
}

/// Cambios permitidos sobre el propio perfil. `null` = sin cambio.
class ProfileChanges {
  const ProfileChanges({
    this.username,
    this.displayName,
    this.bio,
    this.avatar,
    this.visibility,
  });

  final String? username;
  final String? displayName;
  final String? bio;
  final AvatarConfig? avatar;
  final ProfileVisibility? visibility;

  bool get isEmpty =>
      username == null &&
      displayName == null &&
      bio == null &&
      avatar == null &&
      visibility == null;
}
