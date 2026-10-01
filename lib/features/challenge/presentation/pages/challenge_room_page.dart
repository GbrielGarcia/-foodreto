import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/challenge.dart';
import '../providers/challenge_controllers.dart';
import '../providers/challenge_providers.dart';
import '../widgets/challenge_active_screen.dart';
import '../widgets/challenge_lobby_screen.dart';
import '../widgets/challenge_result_screen.dart';

/// Sala del reto. Escucha el documento del reto y muestra la pantalla que
/// corresponde a su estado, así todos pasan de la espera al contador y al
/// resultado a la vez, sin recargar.
class ChallengeRoomPage extends ConsumerWidget {
  const ChallengeRoomPage({super.key, required this.challengeId});

  final String challengeId;

  void _close(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(AppRoutes.challenges);

  Future<void> _confirmAndRun(
    BuildContext context,
    WidgetRef ref,
    RoomAction action,
  ) async {
    final (title, message, confirm) = switch (action) {
      RoomAction.cancel => (
        '¿Cancelar reto?',
        'Nadie podrá seguir contando y no se guardará ningún resultado.',
        'Cancelar reto',
      ),
      RoomAction.leave => (
        '¿Salir del reto?',
        'Podrás volver a entrar con el código mientras no haya empezado.',
        'Salir',
      ),
      _ => ('', '', ''),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await ref
        .read(roomActionsControllerProvider(challengeId).notifier)
        .run(action);
    if (done && action == RoomAction.leave && context.mounted) {
      context.go(AppRoutes.challenges);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final async = ref.watch(challengeProvider(challengeId));
    final challenge = async.value;

    ref.listen(roomActionsControllerProvider(challengeId), (_, next) {
      final failure = next.failure;
      if (failure == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
      ref
          .read(roomActionsControllerProvider(challengeId).notifier)
          .clearError();
    });

    final isMember = challenge?.isParticipant(uid) ?? false;
    final isHost = challenge?.isHost(uid) ?? false;
    final status = challenge?.status;
    final canCancel =
        isHost && (status?.canTransitionTo(ChallengeStatus.cancelled) ?? false);
    final canLeave = isMember && !isHost && status == ChallengeStatus.waiting;

    final Widget body = switch (async) {
      AsyncData(value: null) => EmptyStateView(
        key: const ValueKey('missing'),
        emoji: '🔍',
        title: 'Este reto no existe.',
        message: 'Puede que el enlace esté incompleto.',
        actionLabel: 'Ver mis retos',
        onAction: () => context.go(AppRoutes.challenges),
      ),
      AsyncData(value: final Challenge c) when !c.isParticipant(uid) =>
        EmptyStateView(
          key: const ValueKey('outsider'),
          emoji: '🔒',
          title: 'No formas parte de este reto',
          message: c.status.acceptsParticipants
              ? 'Entra con el código para ver la sala.'
              : 'Solo sus participantes pueden verlo.',
          actionLabel: c.status.acceptsParticipants ? 'Unirme' : null,
          onAction: c.status.acceptsParticipants
              ? () => context.pushReplacement(AppRoutes.joinPath(c.inviteCode))
              : null,
        ),
      AsyncData(value: final Challenge c) => switch (c.status) {
        ChallengeStatus.waiting => ChallengeLobbyScreen(
          key: const ValueKey('waiting'),
          challenge: c,
        ),
        ChallengeStatus.active => ChallengeActiveScreen(
          key: const ValueKey('active'),
          challenge: c,
        ),
        ChallengeStatus.finished => ChallengeResultScreen(
          key: const ValueKey('finished'),
          challenge: c,
        ),
        ChallengeStatus.cancelled => EmptyStateView(
          key: const ValueKey('cancelled'),
          emoji: '🚫',
          title: 'Reto cancelado',
          message:
              'El anfitrión canceló este reto. No se guardó ningún resultado.',
          actionLabel: 'Ver mis retos',
          onAction: () => context.go(AppRoutes.challenges),
        ),
        ChallengeStatus.draft => const EmptyStateView(
          key: ValueKey('draft'),
          emoji: '📝',
          title: 'Este reto aún no está publicado',
          message: 'Vuelve cuando el anfitrión lo abra.',
        ),
      },
      AsyncError() => ErrorStateView(
        key: const ValueKey('error'),
        message: 'No pudimos abrir el reto. Revisa tu conexión.',
        onRetry: () => ref.invalidate(challengeProvider(challengeId)),
      ),
      _ => const LoadingStateView(key: ValueKey('loading')),
    };

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => _close(context)),
        title: Text(switch (status) {
          ChallengeStatus.waiting => 'Sala de espera',
          ChallengeStatus.active => 'Reto en curso',
          ChallengeStatus.finished => 'Resultado',
          _ => 'Reto',
        }),
        actions: [
          if (canCancel || canLeave)
            PopupMenuButton<RoomAction>(
              tooltip: 'Más opciones',
              onSelected: (action) => _confirmAndRun(context, ref, action),
              itemBuilder: (context) => [
                if (canLeave)
                  const PopupMenuItem(
                    value: RoomAction.leave,
                    child: Text('Salir del reto'),
                  ),
                if (canCancel)
                  const PopupMenuItem(
                    value: RoomAction.cancel,
                    child: Text('Cancelar reto'),
                  ),
              ],
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: body,
      ),
    );
  }
}
