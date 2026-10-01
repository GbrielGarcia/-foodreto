import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../category/domain/entities/unit_type.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/challenge_result.dart';
import '../providers/challenge_controllers.dart';
import '../providers/challenge_providers.dart';
import '../share/result_share_card.dart';
import '../share/share_result_image.dart';
import 'challenge_widgets.dart';
import 'participant_tile.dart';

/// Resultado del reto. Rankings/records oficiales los materializa el backend.
class ChallengeResultScreen extends ConsumerWidget {
  const ChallengeResultScreen({super.key, required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(challengeResultProvider(challenge.id));
    return switch (result) {
      AsyncData(value: final ChallengeResult value) => _ResultBody(
        challenge: challenge,
        result: value,
      ),
      AsyncError() => ErrorStateView(
        message: 'No pudimos cargar el resultado.',
        onRetry: () => ref.invalidate(challengeResultProvider(challenge.id)),
      ),
      // `null` un instante: el reto ya figura terminado y el resultado llega
      // en el mismo commit, pero son dos listeners distintos.
      _ => const LoadingStateView(message: 'Calculando resultado…'),
    };
  }
}

class _ResultBody extends ConsumerStatefulWidget {
  const _ResultBody({required this.challenge, required this.result});

  final Challenge challenge;
  final ChallengeResult result;

  @override
  ConsumerState<_ResultBody> createState() => _ResultBodyState();
}

class _ResultBodyState extends ConsumerState<_ResultBody> {
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final result = widget.result;
    final theme = Theme.of(context);
    final uid = ref.watch(currentUidProvider);
    final category = watchChallengeCategory(ref, challenge.categoryId);
    final restaurant = watchRestaurantName(ref, challenge.restaurantId);
    final unit = category?.defaultUnit ?? UnitType.units;
    final standings = result.standings;
    final tie =
        standings.length > 1 && standings[0].position == standings[1].position;
    final duration = _duration(result.startedAt, result.finishedAt);
    final title = challenge.displayTitle(category?.name);

    return CenteredContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, s, child) =>
                Transform.scale(scale: s, child: child),
            child: const Text(
              '🏆',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 64),
            ),
          ),
          Text(
            'Reto terminado',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          if (standings.isNotEmpty && standings.first.entry.count > 0)
            Text(
              tie
                  ? '¡Empate en el primer puesto!'
                  : '¡${standings.first.entry.displayName} gana!',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          ChallengeHeader(challenge: challenge),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Resultados'),
          for (final (i, ranked) in standings.indexed)
            FadeSlideIn(
              index: i,
              child: ParticipantTile(
                avatar: ranked.entry.avatar,
                displayName: ranked.entry.displayName,
                username: ranked.entry.username,
                isMe: ranked.entry.userId == uid,
                isHost: ranked.entry.userId == result.hostUserId,
                highlight: ranked.entry.userId == uid,
                leading: SizedBox(
                  width: 32,
                  child: Text(
                    ranked.medal.isEmpty ? '${ranked.position}º' : ranked.medal,
                    textAlign: TextAlign.center,
                    style: ranked.medal.isEmpty
                        ? theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          )
                        : const TextStyle(fontSize: 24),
                  ),
                ),
                trailing: Text(
                  '${ranked.entry.count} ${unit.label(ranked.entry.count)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            [
              'Entre todos: ${result.total} ${unit.label(result.total)}',
              ?duration,
            ].join(' · '),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (challenge.sameDevicePlay &&
              challenge.partnerResultStatus == PartnerResultStatus.pending &&
              challenge.isParticipant(uid) &&
              !challenge.isHost(uid)) ...[
            const SizedBox(height: AppSpacing.lg),
            Card(
              color: AppColors.creamSoft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Text(
                      'Confirma el resultado del reto que jugaron en el mismo celular.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => ref
                                .read(
                                  confirmPartnerResultControllerProvider(
                                    challenge.id,
                                  ).notifier,
                                )
                                .confirm(accept: false),
                            child: const Text('Rechazar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => ref
                                .read(
                                  confirmPartnerResultControllerProvider(
                                    challenge.id,
                                  ).notifier,
                                )
                                .confirm(accept: true),
                            child: const Text('Confirmar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else if (challenge.sameDevicePlay &&
              challenge.partnerResultStatus == PartnerResultStatus.pending) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Esperando confirmacion del companero...',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (challenge.partnerResultStatus ==
              PartnerResultStatus.confirmed) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Resultado confirmado por el companero.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.flameDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else if (challenge.partnerResultStatus ==
              PartnerResultStatus.rejected) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'El companero rechazo el resultado.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _sharing
                ? null
                : () => _shareResult(
                    title: title,
                    categoryEmoji: category?.icon ?? '🍽️',
                    restaurantName: restaurant,
                    unit: unit,
                    standings: standings,
                    tie: tie,
                    duration: duration,
                  ),
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: Text(_sharing ? 'GENERANDO…' : 'COMPARTIR IMAGEN'),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: _sharing
                ? null
                : () => context.push(
                    AppRoutes.createPath(categoryId: challenge.categoryId),
                  ),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('CREAR OTRO RETO'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _sharing ? null : () => context.go(AppRoutes.challenges),
            child: const Text('VER MIS RETOS'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareResult({
    required String title,
    required String categoryEmoji,
    required String? restaurantName,
    required UnitType unit,
    required List<RankedEntry> standings,
    required bool tie,
    required String? duration,
  }) async {
    setState(() => _sharing = true);
    try {
      final result = widget.result;
      final card = ChallengeResultShareCard(
        title: title,
        categoryEmoji: categoryEmoji,
        standings: standings,
        scoreLabel: (count) => '$count ${unit.label(count)}',
        totalLabel: 'Entre todos: ${result.total} ${unit.label(result.total)}',
        restaurantName: restaurantName,
        durationLabel: duration,
        tied: tie,
      );
      final winnerBit = standings.isEmpty
          ? 'Reto terminado'
          : tie
          ? 'Empate en el primer puesto'
          : '${standings.first.entry.displayName} gana';
      final caption = [
        '$categoryEmoji $title',
        if (restaurantName != null && restaurantName.isNotEmpty)
          '📍 $restaurantName',
        winnerBit,
        'Compite en FoodReto',
      ].join('\n');

      if (!mounted) return;
      await shareChallengeResultImage(
        context,
        card: card,
        caption: caption,
        subject: 'Resultado · $title',
        fileStem: 'foodreto-${widget.challenge.id}',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  static String? _duration(DateTime? start, DateTime? end) {
    if (start == null || end == null || !end.isAfter(start)) return null;
    final minutes = end.difference(start).inMinutes;
    if (minutes < 1) return 'menos de 1 minuto';
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} h ${minutes % 60} min';
  }
}
