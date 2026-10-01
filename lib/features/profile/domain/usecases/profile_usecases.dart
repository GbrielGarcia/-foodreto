import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/validators.dart';
import '../entities/user_profile.dart';
import '../entities/user_statistics.dart';
import '../entities/username_availability.dart';
import '../failures/profile_failure.dart';
import '../repositories/profile_repository.dart';
import '../value_objects/username.dart';

class WatchUserProfile {
  const WatchUserProfile(this._repository);
  final ProfileRepository _repository;

  Stream<UserProfile?> call(String uid) => _repository.watchProfile(uid);
}

class WatchUserStatistics {
  const WatchUserStatistics(this._repository);
  final UserStatisticsRepository _repository;

  Stream<UserStatistics> call(String uid) => _repository.watchStatistics(uid);
}

class CheckUsernameAvailability {
  const CheckUsernameAvailability(this._repository);
  final ProfileRepository _repository;

  Future<Result<UsernameAvailability>> call(
    String input, {
    String? currentUid,
  }) async {
    final error = Username.validate(input);
    if (error != null) return Result.success(UsernameInvalid(error));
    return _repository.checkUsernameAvailability(
      Username.normalize(input),
      currentUid: currentUid,
    );
  }
}

/// Onboarding: crea el perfil reservando el @username (`createUsername()`).
class CreateProfileWithUsername {
  const CreateProfileWithUsername(this._repository);
  final ProfileRepository _repository;

  Future<Result<UserProfile>> call(NewProfile profile) async {
    final normalized = NewProfile(
      uid: profile.uid,
      username: Username.normalize(profile.username),
      displayName: profile.displayName.trim(),
      avatar: profile.avatar,
      email: profile.email,
      bio: profile.bio.trim(),
    );
    final invalid = _validate(
      username: normalized.username,
      displayName: normalized.displayName,
      bio: normalized.bio,
      avatar: normalized.avatar,
    );
    if (invalid != null) return Result.failure(invalid);
    return _repository.createProfile(normalized);
  }
}

class UpdateProfile {
  const UpdateProfile(this._repository);
  final ProfileRepository _repository;

  Future<Result<void>> call(String uid, ProfileChanges changes) async {
    final normalized = ProfileChanges(
      username: changes.username == null
          ? null
          : Username.normalize(changes.username!),
      displayName: changes.displayName?.trim(),
      bio: changes.bio?.trim(),
      avatar: changes.avatar,
    );
    if (normalized.isEmpty) return const Result.success(null);
    final invalid = _validate(
      username: normalized.username,
      displayName: normalized.displayName,
      bio: normalized.bio,
      avatar: normalized.avatar,
    );
    if (invalid != null) return Result.failure(invalid);
    return _repository.updateProfile(uid, normalized);
  }
}

/// Cambia solo el @username (`updateUsername()`).
class UpdateUsername {
  const UpdateUsername(this._updateProfile);
  final UpdateProfile _updateProfile;

  Future<Result<void>> call(String uid, String username) =>
      _updateProfile(uid, ProfileChanges(username: username));
}

ProfileFailure? _validate({
  String? username,
  String? displayName,
  String? bio,
  AvatarConfig? avatar,
}) {
  if (username != null) {
    final error = Username.validate(username);
    if (error != null) {
      return ProfileFailure.invalidData(Username.message(error));
    }
  }
  if (displayName != null) {
    final error = Validators.displayName(displayName);
    if (error != null) return ProfileFailure.invalidData(error);
  }
  if (bio != null && bio.length > UserProfile.maxBioLength) {
    return const ProfileFailure.invalidData(
      'La descripción admite hasta ${UserProfile.maxBioLength} caracteres.',
    );
  }
  if (avatar != null &&
      (!AvatarConfig.isValidStyle(avatar.style) ||
          !AvatarConfig.isValidSeed(avatar.seed))) {
    return const ProfileFailure.invalidData('Ese avatar no es válido.');
  }
  return null;
}
