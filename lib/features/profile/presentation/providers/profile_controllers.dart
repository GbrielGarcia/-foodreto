import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/error/failure.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/failures/profile_failure.dart';
import 'profile_providers.dart';

enum SaveStatus { idle, saving, saved, error }

class SaveState {
  const SaveState(this.status, [this.failure]);

  static const idle = SaveState(SaveStatus.idle);

  final SaveStatus status;
  final Failure? failure;

  bool get isSaving => status == SaveStatus.saving;
}

/// Crea el perfil en el onboarding. Al terminar, el router redirige solo
/// porque `currentUserProfileProvider` emite el nuevo perfil.
class OnboardingController extends Notifier<SaveState> {
  @override
  SaveState build() => SaveState.idle;

  Future<bool> createProfile({
    required String username,
    required String displayName,
    required AvatarConfig avatar,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const SaveState(SaveStatus.error, ProfileFailure.notFound());
      return false;
    }
    state = const SaveState(SaveStatus.saving);
    final result = await ref.read(createProfileProvider)(
      NewProfile(
        uid: user.id,
        username: username,
        displayName: displayName,
        avatar: avatar,
        email: user.email,
      ),
    );
    if (!ref.mounted) return result.isSuccess;
    state = result.fold(
      onSuccess: (_) => const SaveState(SaveStatus.saved),
      onFailure: (failure) => SaveState(SaveStatus.error, failure),
    );
    return result.isSuccess;
  }
}

final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, SaveState>(
      OnboardingController.new,
    );

/// Guarda cambios del propio perfil y expone Guardando / Guardado / Error.
class EditProfileController extends Notifier<SaveState> {
  @override
  SaveState build() => SaveState.idle;

  Future<bool> save(ProfileChanges changes) async {
    final uid = ref.read(currentUserProvider)?.id;
    if (uid == null) {
      state = const SaveState(SaveStatus.error, ProfileFailure.notFound());
      return false;
    }
    state = const SaveState(SaveStatus.saving);
    final result = await ref.read(updateProfileProvider)(uid, changes);
    if (!ref.mounted) return result.isSuccess;
    state = result.fold(
      onSuccess: (_) => const SaveState(SaveStatus.saved),
      onFailure: (failure) => SaveState(SaveStatus.error, failure),
    );
    return result.isSuccess;
  }

  /// Vuelve a "sin cambios guardados" cuando el usuario edita de nuevo.
  void markDirty() {
    if (state.status != SaveStatus.idle && !state.isSaving) {
      state = SaveState.idle;
    }
  }
}

final editProfileControllerProvider =
    NotifierProvider.autoDispose<EditProfileController, SaveState>(
      EditProfileController.new,
    );
