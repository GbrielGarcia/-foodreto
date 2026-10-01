import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/failures/challenge_failure.dart';
import '../../domain/usecases/challenge_usecases.dart';
import '../../domain/value_objects/invite_code.dart';
import '../providers/challenge_controllers.dart';
import '../providers/challenge_providers.dart';
import '../widgets/challenge_widgets.dart';

/// Destino de `/join/:code` (enlace compartido o código manual). El router ya
/// garantizó sesión y perfil; al terminar, el usuario vuelve aquí.
class JoinChallengePage extends ConsumerWidget {
  const JoinChallengePage({super.key, required this.code});

  final String code;

  void _close(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(AppRoutes.home);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalized = InviteCode.normalize(code);
    final valid = InviteCode.isValid(normalized);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unirme a un reto'),
        leading: BackButton(onPressed: () => _close(context)),
      ),
      body: !valid
          ? EmptyStateView(
              emoji: '🤔',
              title: 'Código no válido',
              message:
                  'Revisa el código: son ${InviteCode.length} letras o números.',
              actionLabel: 'Volver al inicio',
              onAction: () => context.go(AppRoutes.home),
            )
          : switch (ref.watch(challengeByCodeProvider(normalized))) {
              AsyncData(:final value) => _JoinPreview(challenge: value),
              AsyncError(:final error) => _JoinError(
                failure: error,
                onRetry: () =>
                    ref.invalidate(challengeByCodeProvider(normalized)),
              ),
              _ => const LoadingStateView(),
            },
    );
  }
}

class _JoinError extends StatelessWidget {
  const _JoinError({required this.failure, required this.onRetry});

  final Object failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (failure is ChallengeFailure) {
      return EmptyStateView(
        emoji: '🔍',
        title: (failure as ChallengeFailure).message,
        message: 'Pide a quien te invitó que te comparta el código de nuevo.',
        actionLabel: 'Volver al inicio',
        onAction: () => context.go(AppRoutes.home),
      );
    }
    return ErrorStateView(
      message: 'No pudimos buscar el reto. Revisa tu conexión.',
      onRetry: onRetry,
    );
  }
}

class _JoinPreview extends ConsumerWidget {
  const _JoinPreview({required this.challenge});

  final Challenge challenge;

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final joined = await ref
        .read(joinChallengeControllerProvider.notifier)
        .join(challenge);
    if (!context.mounted) return;
    final failure = ref.read(joinChallengeControllerProvider).failure;
    if (joined ||
        (failure is ChallengeFailure && failure.code == 'already-joined')) {
      context.pushReplacement(AppRoutes.challengePath(challenge.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uid = ref.watch(currentUidProvider);
    final save = ref.watch(joinChallengeControllerProvider);

    if (challenge.isParticipant(uid)) {
      // Enlace de un reto en el que ya estás: directo a la sala.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.pushReplacement(AppRoutes.challengePath(challenge.id));
        }
      });
      return const LoadingStateView();
    }

    final blocker = uid == null ? null : joinBlocker(challenge, uid);
    final failure = save.failure ?? blocker;

    return CenteredContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Te invitaron a',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      ChallengeStatusChip(status: challenge.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ChallengeHeader(challenge: challenge, large: true),
                  if (challenge.description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(challenge.description),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${challenge.participantIds.length} de '
                    '${challenge.maxParticipants} participantes · '
                    'Código ${challenge.inviteCode}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (failure != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                failure.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: blocker != null
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (blocker == null)
            FilledButton(
              onPressed: save.isSaving ? null : () => _join(context, ref),
              child: Text(save.isSaving ? 'ENTRANDO…' : 'UNIRME'),
            )
          else
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('VOLVER AL INICIO'),
            ),
        ],
      ),
    );
  }
}
