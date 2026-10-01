import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../category/domain/entities/unit_type.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/challenge_participant.dart';
import '../providers/challenge_controllers.dart';
import '../providers/challenge_providers.dart';
import 'challenge_widgets.dart';
import 'participant_tile.dart';

/// Reto en curso: contador(es) y marcador en vivo.
class ChallengeActiveScreen extends ConsumerWidget {
  const ChallengeActiveScreen({super.key, required this.challenge});

  final Challenge challenge;

  Future<void> _confirmFinish(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('\u00bfFinalizar reto?'),
        content: const Text(
          'Despues de finalizar no podras continuar registrando unidades.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(roomActionsControllerProvider(challenge.id).notifier)
          .run(RoomAction.finish);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uid = ref.watch(currentUidProvider);
    final category = watchChallengeCategory(ref, challenge.categoryId);
    final restaurant = watchRestaurantName(ref, challenge.restaurantId);
    final unit = category?.defaultUnit ?? UnitType.units;
    final participants = ref.watch(challengeParticipantsProvider(challenge.id));
    final actions = ref.watch(roomActionsControllerProvider(challenge.id));
    final startedAt = challenge.startedAt;

    final header = Column(
      children: [
        Text(category?.icon ?? '\u{1F37D}', style: const TextStyle(fontSize: 44)),
        Text(
          (category?.name ?? challenge.displayTitle(null)).toUpperCase(),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        Text(
          [
            if (challenge.title.isNotEmpty) challenge.title,
            if (restaurant != null) restaurant,
            if (startedAt != null) 'En curso desde las ${_hhmm(startedAt)}',
          ].join(' \u00b7 '),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return switch (participants) {
      AsyncData(:final value) => () {
        final me = value.where((p) => p.userId == uid).firstOrNull;
        final board = [...value]
          ..sort((a, b) => b.currentCount.compareTo(a.currentCount));
        final sameDeviceHost =
            challenge.sameDevicePlay && challenge.isHost(uid) && value.length > 1;

        final Widget counters;
        if (me == null) {
          counters = const SizedBox.shrink();
        } else if (sameDeviceHost) {
          counters = Column(
            children: [
              for (final p in value) ...[
                if (p != value.first) const SizedBox(height: AppSpacing.md),
                _MyCounter(
                  challengeId: challenge.id,
                  me: p,
                  unit: unit,
                  label: p.displayName,
                  forUserId: p.userId == uid ? null : p.userId,
                  compact: value.length > 2,
                ),
              ],
            ],
          );
        } else {
          counters = _MyCounter(challengeId: challenge.id, me: me, unit: unit);
        }

        final others = _Scoreboard(
          board: board,
          uid: uid,
          unit: unit,
          challengeId: challenge.id,
          sameDevicePlay: challenge.sameDevicePlay,
        );

        return CenteredContent(
          maxWidth: 960,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (sameDeviceHost) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Mismo celular: suma para cada uno. Sin internet se guarda '
                  'y sincroniza al volver.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth >= 760
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: counters),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(flex: 4, child: others),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          counters,
                          const SizedBox(height: AppSpacing.lg),
                          others,
                        ],
                      ),
              ),
              if (challenge.isHost(uid)) ...[
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton.icon(
                  onPressed: actions.isBusy
                      ? null
                      : () => _confirmFinish(context, ref),
                  icon: const Icon(Icons.flag_rounded),
                  label: Text(
                    actions.running == RoomAction.finish
                        ? 'FINALIZANDO...'
                        : 'FINALIZAR RETO',
                  ),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'El anfitrion finalizara el reto.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      }(),
      AsyncError() => ErrorStateView(
        message: 'Se perdio la conexion con el reto.',
        onRetry: () =>
            ref.invalidate(challengeParticipantsProvider(challenge.id)),
      ),
      _ => const LoadingStateView(),
    };
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _MyCounter extends ConsumerWidget {
  const _MyCounter({
    required this.challengeId,
    required this.me,
    required this.unit,
    this.forUserId,
    this.label = 'TU MARCA',
    this.compact = false,
  });

  final String challengeId;
  final ChallengeParticipant me;
  final UnitType unit;
  final String? forUserId;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final counter = ref.watch(counterControllerProvider(challengeId));
    final notifier = ref.read(counterControllerProvider(challengeId).notifier);
    final pendingDelta = ref
            .watch(
              pendingCounterDeltaForUserProvider((
                challengeId: challengeId,
                userId: forUserId ?? me.userId,
              )),
            )
            .value ??
        0;
    final count = me.currentCount + pendingDelta;
    final canDecrement = count > 0;
    final hasPendingSync = pendingDelta != 0;

    void plus() {
      HapticFeedback.lightImpact();
      notifier.increment(forUserId: forUserId);
    }

    void minus() {
      if (!canDecrement) return;
      HapticFeedback.selectionClick();
      notifier.decrement(forUserId: forUserId);
    }

    final status = switch (counter) {
      CounterState(:final failure?) => _StatusLine(
        key: const ValueKey('error'),
        icon: Icons.error_outline_rounded,
        color: scheme.error,
        text: failure.code == 'network'
            ? 'Sin conexion: el cambio quedo pendiente.'
            : failure.message,
      ),
      CounterState(isSyncing: true) || _ when hasPendingSync => const _StatusLine(
        key: ValueKey('sync'),
        text: 'Guardando...',
        spinner: true,
      ),
      _ when count == 0 => _StatusLine(
        key: const ValueKey('hint'),
        text: 'Pulsa + por cada ${unit.singular}.',
      ),
      _ => const _StatusLine(
        key: ValueKey('ok'),
        icon: Icons.cloud_done_outlined,
        text: 'Guardado',
      ),
    };

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: compact ? 48 : 56,
                  child: IconButton.filledTonal(
                    tooltip: 'Restar una ${unit.singular}',
                    onPressed: canDecrement ? minus : null,
                    icon: const Icon(Icons.remove_rounded, size: 28),
                  ),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 48 : null,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                SizedBox.square(
                  dimension: compact ? 64 : 88,
                  child: IconButton.filled(
                    tooltip: 'Sumar una ${unit.singular}',
                    onPressed: plus,
                    icon: Icon(Icons.add_rounded, size: compact ? 32 : 44),
                  ),
                ),
              ],
            ),
            Text(
              unit.label(count),
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: status,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    super.key,
    required this.text,
    this.icon,
    this.color,
    this.spinner = false,
  });

  final String text;
  final IconData? icon;
  final Color? color;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (spinner)
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: 16, color: tint),
        const SizedBox(width: AppSpacing.xs + 2),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: tint),
          ),
        ),
      ],
    );
  }
}

/// Todos los participantes ordenados por cantidad, en vivo.
class _Scoreboard extends ConsumerWidget {
  const _Scoreboard({
    required this.board,
    required this.uid,
    required this.unit,
    required this.challengeId,
    this.sameDevicePlay = false,
  });

  final List<ChallengeParticipant> board;
  final String? uid;
  final UnitType unit;
  final String challengeId;
  final bool sameDevicePlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Marcador'),
        for (final p in board)
          Builder(
            builder: (context) {
              final pending = sameDevicePlay
                  ? (ref
                          .watch(
                            pendingCounterDeltaForUserProvider((
                              challengeId: challengeId,
                              userId: p.userId,
                            )),
                          )
                          .value ??
                      0)
                  : (p.userId == uid
                      ? (ref
                              .watch(pendingCounterDeltaProvider(challengeId))
                              .value ??
                          0)
                      : 0);
              final count = p.currentCount + pending;
              return ParticipantTile(
                key: ValueKey(p.userId),
                avatar: p.avatar,
                displayName: p.displayName,
                username: p.username,
                isMe: p.userId == uid,
                isHost: p.isHost,
                highlight: p.userId == uid,
                trailing: Text(
                  '$count ${unit.label(count)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
