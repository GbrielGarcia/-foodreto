import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/challenge_result.dart';

/// Tarjeta fija 4:5 para Stories / feed. Tema crema claro (misma marca que la app).
class ChallengeResultShareCard extends StatelessWidget {
  const ChallengeResultShareCard({
    super.key,
    required this.title,
    required this.categoryEmoji,
    required this.standings,
    required this.scoreLabel,
    required this.totalLabel,
    this.restaurantName,
    this.durationLabel,
    this.tied = false,
  });

  /// Ancho logico -> ~1080px a pixelRatio 3.
  static const double cardWidth = 360;
  static const double cardHeight = 450;

  final String title;
  final String categoryEmoji;
  final List<RankedEntry> standings;
  final String Function(int count) scoreLabel;
  final String totalLabel;
  final String? restaurantName;
  final String? durationLabel;
  final bool tied;

  @override
  Widget build(BuildContext context) {
    final top = standings.take(3).toList();
    final winners = standings.isEmpty
        ? const <RankedEntry>[]
        : [
            for (final s in standings)
              if (s.position == standings.first.position) s,
          ];
    final winnerLine = winners.isEmpty
        ? 'Reto terminado'
        : tied
        ? '¡Empate!'
        : '¡${winners.first.entry.displayName} gana!';

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.cream,
            AppColors.creamSoft,
            AppColors.blush,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.flame.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -36,
            right: -28,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.flame.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 72,
            left: -44,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sage.withValues(alpha: 0.55),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.flame.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Text(
                        'FOODRETO',
                        style: TextStyle(
                          color: AppColors.flame,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      categoryEmoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  '\u{1F3C6}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 42),
                ),
                const SizedBox(height: 6),
                Text(
                  winnerLine,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.flameDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (restaurantName != null && restaurantName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '\u{1F4CD} $restaurantName',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: top.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          children: [
                            for (final (i, ranked) in top.indexed)
                              _ShareStandingRow(
                                ranked: ranked,
                                score: scoreLabel(ranked.entry.count),
                                isFirst: i == 0,
                              ),
                          ],
                        ),
                ),
                Text(
                  [
                    totalLabel,
                    ?durationLabel,
                  ].join(' \u00b7 '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.flame,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Compite en FoodReto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStandingRow extends StatelessWidget {
  const _ShareStandingRow({
    required this.ranked,
    required this.score,
    required this.isFirst,
  });

  final RankedEntry ranked;
  final String score;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final name = ranked.entry.displayName.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isFirst ? AppColors.creamHigh : AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFirst
              ? AppColors.gold.withValues(alpha: 0.55)
              : AppColors.ink.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              ranked.medal.isEmpty ? '${ranked.position}\u00ba' : ranked.medal,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ranked.medal.isEmpty ? 13 : 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.blush,
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.flameDeep,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ranked.entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            score,
            style: TextStyle(
              color: isFirst ? AppColors.flameDeep : AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
