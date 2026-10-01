import 'dart:async';

import '../../../../core/error/result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_statistics.dart';
import '../../domain/entities/username_availability.dart';
import '../../domain/failures/profile_failure.dart';
import '../../domain/repositories/profile_repository.dart';

/// Implementación en memoria (modo local y tests) con las mismas reglas de
/// unicidad que la de Firestore. Las operaciones son síncronas dentro del
/// event loop, así que son atómicas.
class InMemoryProfileRepository implements ProfileRepository {
  final _profiles = <String, UserProfile>{};
  final _usernames = <String, String>{};
  final _controller = StreamController<String>.broadcast();

  /// Solo para inspección en tests.
  Map<String, String> get usernameIndex => Map.unmodifiable(_usernames);

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    StreamSubscription<String>? subscription;
    late final StreamController<UserProfile?> output;
    output = StreamController<UserProfile?>(
      onListen: () {
        output.add(_profiles[uid]);
        subscription = _controller.stream
            .where((changed) => changed == uid)
            .listen((_) => output.add(_profiles[uid]));
      },
      onCancel: () => subscription?.cancel(),
    );
    return output.stream;
  }

  @override
  Future<Result<UsernameAvailability>> checkUsernameAvailability(
    String username, {
    String? currentUid,
  }) async {
    final owner = _usernames[username];
    if (owner == null) return const Result.success(UsernameAvailable());
    return Result.success(
      owner == currentUid ? const UsernameOwned() : const UsernameTaken(),
    );
  }

  @override
  Future<Result<UserProfile>> createProfile(NewProfile profile) async {
    if (_profiles.containsKey(profile.uid)) {
      return const Result.failure(ProfileFailure.alreadyExists());
    }
    final owner = _usernames[profile.username];
    if (owner != null && owner != profile.uid) {
      return const Result.failure(ProfileFailure.usernameTaken());
    }
    final now = DateTime.now();
    final created = UserProfile(
      uid: profile.uid,
      username: profile.username,
      displayName: profile.displayName,
      avatar: profile.avatar,
      bio: profile.bio,
      createdAt: now,
      updatedAt: now,
    );
    _usernames[profile.username] = profile.uid;
    _profiles[profile.uid] = created;
    _controller.add(profile.uid);
    return Result.success(created);
  }

  @override
  Future<Result<void>> updateProfile(String uid, ProfileChanges changes) async {
    final current = _profiles[uid];
    if (current == null) {
      return const Result.failure(ProfileFailure.notFound());
    }
    final newUsername = changes.username;
    if (newUsername != null && newUsername != current.username) {
      final owner = _usernames[newUsername];
      if (owner != null && owner != uid) {
        return const Result.failure(ProfileFailure.usernameTaken());
      }
      _usernames
        ..remove(current.username)
        ..[newUsername] = uid;
    }
    _profiles[uid] = current.copyWith(
      username: newUsername,
      displayName: changes.displayName,
      bio: changes.bio,
      avatar: changes.avatar,
      updatedAt: DateTime.now(),
    );
    _controller.add(uid);
    return const Result.success(null);
  }

  Future<void> dispose() => _controller.close();
}

/// Sin backend no hay actividad registrada: siempre cero.
class InMemoryUserStatisticsRepository implements UserStatisticsRepository {
  @override
  Stream<UserStatistics> watchStatistics(String uid) =>
      Stream.value(UserStatistics.empty);
}
