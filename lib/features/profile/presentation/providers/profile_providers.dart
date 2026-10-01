import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/router/auth_redirect.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_profile_repository.dart';
import '../../data/repositories/in_memory_profile_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_statistics.dart';
import '../../domain/entities/username_availability.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/profile_usecases.dart';

// ---------------------------------------------------------------------------
// Repositorios y casos de uso
// ---------------------------------------------------------------------------

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  switch (ref.watch(appConfigProvider).backendMode) {
    case BackendMode.firebase:
      return FirestoreProfileRepository(ref.watch(firestoreProvider));
    case BackendMode.local:
      final repository = InMemoryProfileRepository();
      ref.onDispose(repository.dispose);
      return repository;
  }
});

final userStatisticsRepositoryProvider = Provider<UserStatisticsRepository>((
  ref,
) {
  return switch (ref.watch(appConfigProvider).backendMode) {
    BackendMode.firebase => FirestoreUserStatisticsRepository(
      ref.watch(firestoreProvider),
    ),
    BackendMode.local => InMemoryUserStatisticsRepository(),
  };
});

final checkUsernameAvailabilityProvider = Provider(
  (ref) => CheckUsernameAvailability(ref.watch(profileRepositoryProvider)),
);

final createProfileProvider = Provider(
  (ref) => CreateProfileWithUsername(ref.watch(profileRepositoryProvider)),
);

final updateProfileProvider = Provider(
  (ref) => UpdateProfile(ref.watch(profileRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Lecturas
// ---------------------------------------------------------------------------

final _currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider.select((auth) => auth.value?.id)),
);

/// Perfil del usuario autenticado; `null` si no hay sesión o no completó
/// el onboarding.
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(_currentUidProvider);
  if (uid == null) return Stream.value(null);
  return WatchUserProfile(ref.watch(profileRepositoryProvider))(uid);
});

/// Perfil de cualquier usuario por uid (perfiles públicos en fases futuras).
final userProfileProvider = StreamProvider.autoDispose
    .family<UserProfile?, String>((ref, uid) {
      return WatchUserProfile(ref.watch(profileRepositoryProvider))(uid);
    });

final userStatisticsProvider = StreamProvider.autoDispose<UserStatistics>((
  ref,
) {
  final uid = ref.watch(_currentUidProvider);
  if (uid == null) return Stream.value(UserStatistics.empty);
  return WatchUserStatistics(ref.watch(userStatisticsRepositoryProvider))(uid);
});

/// Disponibilidad de un @username, con espera breve para no consultar en
/// cada pulsación. El parámetro es el texto tal como lo escribió el usuario.
final usernameAvailabilityProvider = FutureProvider.autoDispose
    .family<UsernameAvailability, String>((ref, input) async {
      var disposed = false;
      ref.onDispose(() => disposed = true);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (disposed) throw const _Superseded();

      final result = await ref.read(checkUsernameAvailabilityProvider)(
        input,
        currentUid: ref.read(_currentUidProvider),
      );
      return result.fold(
        onSuccess: (availability) => availability,
        onFailure: (failure) => throw failure,
      );
    }, retry: (_, _) => null);

class _Superseded implements Exception {
  const _Superseded();
}

// ---------------------------------------------------------------------------
// Estado del perfil para el router
// ---------------------------------------------------------------------------

final profileStatusProvider = Provider<ProfileStatus>((ref) {
  final uid = ref.watch(_currentUidProvider);
  if (uid == null) return ProfileStatus.unknown;
  final profile = ref.watch(currentUserProfileProvider);
  if (profile.isLoading) return ProfileStatus.unknown;
  // Un error de lectura no debe bloquear la app en el splash; las pantallas
  // muestran el error con opción de reintentar.
  if (profile.hasError) return ProfileStatus.complete;
  final value = profile.value;
  if (value == null) return ProfileStatus.missing;
  return value.uid == uid ? ProfileStatus.complete : ProfileStatus.unknown;
});
