import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/value_objects/username.dart';
import '../providers/profile_controllers.dart';
import '../providers/profile_providers.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/username_field.dart';

class EditProfilePage extends ConsumerWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: switch (profile) {
        AsyncData(value: final UserProfile p) => _EditProfileForm(profile: p),
        AsyncError() => ErrorStateView(
          message: 'No pudimos cargar tu perfil.',
          onRetry: () => ref.invalidate(currentUserProfileProvider),
        ),
        _ => const LoadingStateView(),
      },
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.displayName);
  late final _username = TextEditingController(text: widget.profile.username);
  late final _bio = TextEditingController(text: widget.profile.bio);
  late AvatarConfig _avatar = widget.profile.avatar;
  late var _visibility = widget.profile.visibility;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  ProfileChanges _changes() {
    final p = widget.profile;
    final username = Username.normalize(_username.text);
    return ProfileChanges(
      username: username != p.username ? username : null,
      displayName: _name.text.trim() != p.displayName ? _name.text : null,
      bio: _bio.text.trim() != p.bio ? _bio.text : null,
      avatar: _avatar != p.avatar ? _avatar : null,
      visibility: _visibility != p.visibility ? _visibility : null,
    );
  }

  void _edited() =>
      ref.read(editProfileControllerProvider.notifier).markDirty();

  Future<void> _pickAvatar() async {
    final picked = await showAvatarPicker(context, initial: _avatar);
    if (picked != null && mounted) {
      setState(() => _avatar = picked);
      _edited();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(editProfileControllerProvider.notifier).save(_changes());
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(editProfileControllerProvider);
    final theme = Theme.of(context);

    return CenteredContent(
      maxWidth: 560,
      child: Form(
        key: _formKey,
        onChanged: _edited,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: UserAvatar(
                avatar: _avatar,
                size: 120,
                ring: true,
                heroTag: 'avatar-${widget.profile.uid}',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton.icon(
                onPressed: _pickAvatar,
                icon: const Icon(Icons.palette_outlined),
                label: const Text('Cambiar avatar'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: Validators.displayName,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            UsernameField(controller: _username),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _bio,
              maxLength: UserProfile.maxBioLength,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción corta (opcional)',
                hintText: 'Rey de las alitas 🍗',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Perfil público'),
              subtitle: const Text(
                'Si está apagado, otros no verán tus estadísticas.',
              ),
              value: _visibility == ProfileVisibility.public,
              onChanged: (v) {
                setState(
                  () => _visibility = v
                      ? ProfileVisibility.public
                      : ProfileVisibility.private,
                );
                _edited();
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            ListenableBuilder(
              listenable: Listenable.merge([_name, _username, _bio]),
              builder: (context, _) {
                final changes = _changes();
                final usernameOk =
                    changes.username == null ||
                    (Username.isValid(_username.text) &&
                        isUsernameUsable(
                          ref.watch(
                            usernameAvailabilityProvider(_username.text),
                          ),
                        ));
                final canSave =
                    !changes.isEmpty && usernameOk && !save.isSaving;
                return FilledButton(
                  onPressed: canSave ? _save : null,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: switch (save.status) {
                      SaveStatus.saving => const Row(
                        key: ValueKey('saving'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text('GUARDANDO…'),
                        ],
                      ),
                      _ => const Text('GUARDAR', key: ValueKey('save')),
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, child: child),
              ),
              child: switch (save.status) {
                SaveStatus.saved => _StatusBanner(
                  key: const ValueKey('saved'),
                  icon: Icons.check_circle_rounded,
                  color: AppColors.mint,
                  text: 'Guardado correctamente',
                ),
                SaveStatus.error => _StatusBanner(
                  key: const ValueKey('error'),
                  icon: Icons.error_outline_rounded,
                  color: theme.colorScheme.error,
                  text: 'Error al guardar. ${save.failure?.message ?? ''}'
                      .trim(),
                ),
                _ => const SizedBox.shrink(key: ValueKey('none')),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
