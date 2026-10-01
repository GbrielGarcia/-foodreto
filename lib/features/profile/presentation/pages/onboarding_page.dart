import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/value_objects/username.dart';
import '../providers/profile_controllers.dart';
import '../providers/profile_providers.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/username_field.dart';

/// Completa el perfil tras registrarse: avatar, nombre y @username.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _username;
  AvatarConfig _avatar = AvatarConfig.random();

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _name = TextEditingController(text: user?.displayName ?? '');
    _username = TextEditingController(
      text: Username.suggest(
        displayName: user?.displayName,
        email: user?.email,
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await showAvatarPicker(context, initial: _avatar);
    if (picked != null && mounted) setState(() => _avatar = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(onboardingControllerProvider.notifier)
        .createProfile(
          username: _username.text,
          displayName: _name.text,
          avatar: _avatar,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final save = ref.watch(onboardingControllerProvider);
    ref.listen(onboardingControllerProvider, (_, next) {
      if (next.status == SaveStatus.error && next.failure != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.failure!.message)));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: CenteredContent(
          maxWidth: 480,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Crea tu perfil',
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Así te verán tus amigos en los retos y rankings.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickAvatar,
                        child: UserAvatar(
                          avatar: _avatar,
                          size: 120,
                          ring: true,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: IconButton.filled(
                          tooltip: 'Cambiar avatar',
                          onPressed: _pickAvatar,
                          icon: const Icon(Icons.edit_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
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
                const SizedBox(height: AppSpacing.xl),
                ListenableBuilder(
                  listenable: _username,
                  builder: (context, _) {
                    final usable =
                        Username.isValid(_username.text) &&
                        isUsernameUsable(
                          ref.watch(
                            usernameAvailabilityProvider(_username.text),
                          ),
                        );
                    return FilledButton(
                      onPressed: usable && !save.isSaving ? _submit : null,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: save.isSaving
                            ? const Text('GUARDANDO…', key: ValueKey('saving'))
                            : const Text('EMPEZAR', key: ValueKey('go')),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: save.isSaving
                      ? null
                      : () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                  child: const Text('Usar otra cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
