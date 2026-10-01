import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../domain/entities/ranking_scope.dart';
import '../providers/leaderboard_providers.dart';
import '../widgets/ranking_podium.dart';

/// Rankings oficiales (global / categoria). Lectura bajo demanda con cache.
class RankingsPage extends ConsumerStatefulWidget {
  const RankingsPage({super.key});

  @override
  ConsumerState<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends ConsumerState<RankingsPage> {
  var _tab = 0;
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    ref.watch(officialBackfillOnceProvider);

    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final categoryId =
        _categoryId ?? (categories.isNotEmpty ? categories.first.id : null);
    final globalScope = RankingScopes.global;
    final categoryScope =
        categoryId == null ? null : RankingScopes.category(categoryId);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Rankings',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Podio oficial. Empate: más victorias, luego fecha.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Global')),
                      ButtonSegment(value: 1, label: Text('Categoría')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                  if (_tab == 1) ...[
                    const SizedBox(height: AppSpacing.md),
                    if (categories.isEmpty)
                      const EmptyStateView(
                        compact: true,
                        emoji: '📂',
                        title: 'Sin categorías',
                        message:
                            'Cuando haya categorías verás su ranking aquí.',
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: categoryId,
                        items: [
                          for (final c in categories)
                            DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.icon} ${c.name}'),
                            ),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                        decoration:
                            const InputDecoration(labelText: 'Categoría'),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: IndexedStack(
                      index: _tab == 0 || categoryScope == null ? 0 : 1,
                      children: [
                        _RankingBody(scopeKey: globalScope),
                        if (categoryScope != null)
                          _RankingBody(scopeKey: categoryScope)
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingBody extends ConsumerWidget {
  const _RankingBody({required this.scopeKey});

  final String scopeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(
      rankingPageProvider((scopeKey: scopeKey, cursor: null)),
    );
    final mine = ref.watch(userRankingProvider(scopeKey));

    return page.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyStateView(
        emoji: e.toString().contains('failed-precondition') ? '📇' : '⚠️',
        title: e.toString().contains('failed-precondition')
            ? 'Falta un índice en Firestore'
            : 'No se pudo cargar',
        message: e.toString().contains('failed-precondition')
            ? 'El ranking necesita un índice compuesto. '
                'Ya está en firestore.indexes.json; '
                'autoriza el deploy de indexes o crea el índice '
                'desde el enlace de la consola de Firebase.'
            : e.toString(),
        actionLabel: 'Reintentar',
        onAction: () =>
            ref.read(leaderboardEpochProvider.notifier).bump(),
      ),
      data: (data) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.read(leaderboardEpochProvider.notifier).bump();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              mine.when(
                data: (pos) => pos.isRanked
                    ? Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.creamHigh,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.flame.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'Tu puesto #${pos.position} · score ${pos.bestScore}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              if (data.entries.isEmpty)
                const EmptyStateView(
                  compact: true,
                  emoji: '🏆',
                  title: 'Ranking vacío',
                  message:
                      'Aún no hay resultados oficiales procesados. '
                      'Finaliza un reto público para materializar el ranking.',
                )
              else
                RankingPodiumList(entries: data.entries),
            ],
          ),
        );
      },
    );
  }
}
