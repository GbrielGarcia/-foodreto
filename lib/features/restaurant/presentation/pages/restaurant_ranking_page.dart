import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../category/domain/entities/food_category.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../../leaderboard/domain/entities/ranking_scope.dart';
import '../../../leaderboard/presentation/providers/leaderboard_providers.dart';
import '../../../leaderboard/presentation/widgets/ranking_podium.dart';
import '../providers/restaurant_providers.dart';

/// Ranking oficial del local por categoria (`restaurant:{id}:cat:{cat}`).
class RestaurantRankingPage extends ConsumerStatefulWidget {
  const RestaurantRankingPage({
    super.key,
    required this.restaurantId,
    this.initialCategoryId,
  });

  final String restaurantId;
  final String? initialCategoryId;

  @override
  ConsumerState<RestaurantRankingPage> createState() =>
      _RestaurantRankingPageState();
}

class _RestaurantRankingPageState extends ConsumerState<RestaurantRankingPage> {
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final restaurantAsync = ref.watch(restaurantProvider(widget.restaurantId));
    final categories =
        ref.watch(categoriesProvider).value ?? const <FoodCategory>[];

    return restaurantAsync.when(
      loading: () => const Scaffold(body: LoadingStateView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyStateView(
          emoji: '\u26a0\ufe0f',
          title: 'Error',
          message: e.toString(),
        ),
      ),
      data: (restaurant) {
        if (restaurant == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyStateView(
              emoji: '\u{1F50D}',
              title: 'Local no encontrado',
              message: 'Puede estar suspendido o no existir.',
            ),
          );
        }
        final catIds = restaurant.categoryIds.isNotEmpty
            ? restaurant.categoryIds
            : [for (final c in categories.take(1)) c.id];
        final selected = _categoryId ??
            widget.initialCategoryId ??
            (catIds.isNotEmpty ? catIds.first : null);
        final scopeKey = selected == null
            ? null
            : RankingScopes.restaurantCategory(widget.restaurantId, selected);

        return Scaffold(
          appBar: AppBar(
            title: Text('Ranking · ${restaurant.name}'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Quiénes más han competido aquí (score oficial por categoría).',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (catIds.isEmpty)
                  const Expanded(
                    child: EmptyStateView(
                      compact: true,
                      emoji: '\u{1F4C2}',
                      title: 'Sin categorías',
                      message:
                          'El responsable debe asociar categorías al local.',
                    ),
                  )
                else ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final id in catIds)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(() {
                                for (final c in categories) {
                                  if (c.id == id) return '${c.icon} ${c.name}';
                                }
                                return id;
                              }()),
                              selected: selected == id,
                              onSelected: (_) =>
                                  setState(() => _categoryId = id),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: scopeKey == null
                        ? const SizedBox.shrink()
                        : _RankingList(scopeKey: scopeKey),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RankingList extends ConsumerWidget {
  const _RankingList({required this.scopeKey});
  final String scopeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(
      rankingPageProvider((scopeKey: scopeKey, cursor: null)),
    );
    return page.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyStateView(
        emoji: '\u26a0\ufe0f',
        title: 'No se pudo cargar',
        message: e.toString(),
        actionLabel: 'Reintentar',
        onAction: () =>
            ref.read(leaderboardEpochProvider.notifier).bump(),
      ),
      data: (data) {
        if (data.entries.isEmpty) {
          return const EmptyStateView(
            compact: true,
            emoji: '\u{1F3C6}',
            title: 'Sin ranking aún',
            message:
                'Finaliza retos públicos en este local para materializar scores.',
          );
        }
        return ListView(
          children: [
            RankingPodiumList(entries: data.entries),
          ],
        );
      },
    );
  }
}
