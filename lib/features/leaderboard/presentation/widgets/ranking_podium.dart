import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../profile/domain/value_objects/username.dart';
import '../../domain/entities/ranking_entry.dart';

/// Podio 2o · 1o · 3o + lista del resto.
class RankingPodiumList extends StatelessWidget {
  const RankingPodiumList({
    super.key,
    required this.entries,
    this.header,
  });

  final List<RankingEntry> entries;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final top = entries.take(3).toList();
    final rest =
        entries.length > 3 ? entries.sublist(3) : const <RankingEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[
          header!,
          const SizedBox(height: AppSpacing.md),
        ],
        _Podium(top: top),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'CLASIFICACIÓN',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final e in rest) _RankingRow(entry: e),
        ],
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top});

  final List<RankingEntry> top;

  @override
  Widget build(BuildContext context) {
    // Orden visual: 2o | 1o | 3o (por indice de lista).
    final first = top.isNotEmpty ? top[0] : null;
    final second = top.length > 1 ? top[1] : null;
    final third = top.length > 2 ? top[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.cream, AppColors.creamSoft, AppColors.blush],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.flame.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _PodiumSlot(
              entry: second,
              place: second?.position ?? 2,
              height: 88,
              accent: AppColors.silver,
              medal: '\u{1F948}',
            ),
          ),
          Expanded(
            child: _PodiumSlot(
              entry: first,
              place: first?.position ?? 1,
              height: 118,
              accent: AppColors.gold,
              medal: '\u{1F947}',
              highlight: true,
            ),
          ),
          Expanded(
            child: _PodiumSlot(
              entry: third,
              place: third?.position ?? 3,
              height: 72,
              accent: AppColors.bronze,
              medal: '\u{1F949}',
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.entry,
    required this.place,
    required this.height,
    required this.accent,
    required this.medal,
    this.highlight = false,
  });

  final RankingEntry? entry;
  final int place;
  final double height;
  final Color accent;
  final String medal;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entry;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (e != null) ...[
          Text(medal, style: TextStyle(fontSize: highlight ? 28 : 22)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () =>
                context.push(AppRoutes.publicProfilePath(e.userId)),
            child: UserAvatar(avatar: e.avatar, size: highlight ? 56 : 44),
          ),
          const SizedBox(height: 6),
          Text(
            e.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: highlight ? 13 : 12,
            ),
          ),
          Text(
            '${e.bestScore}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.flameDeep,
            ),
          ),
          Text(
            '${e.wins} victorias',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ] else
          SizedBox(height: highlight ? 120 : 96),
        Container(
          height: height,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: highlight ? 0.35 : 0.22),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            '$place\u00ba',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.entry});

  final RankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () =>
              context.push(AppRoutes.publicProfilePath(entry.userId)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${entry.position ?? '\u2013'}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                UserAvatar(avatar: entry.avatar, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        Username.display(entry.username),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${entry.bestScore}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${entry.wins} victorias',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
