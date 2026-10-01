import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/food_category.dart';
import '../providers/category_providers.dart';

class CategoryPage extends ConsumerWidget {
  const CategoryPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryProvider(slug));

    return Scaffold(
      appBar: AppBar(),
      body: switch (category) {
        AsyncData(value: final FoodCategory c) => _CategoryContent(category: c),
        AsyncData() => EmptyStateView(
          emoji: '🤔',
          title: 'Categoría no encontrada',
          message: 'Puede que el enlace esté mal escrito.',
          actionLabel: 'Ver categorías',
          onAction: () => context.go(AppRoutes.categories),
        ),
        AsyncError() => ErrorStateView(
          message: 'No pudimos cargar la categoría.',
          onRetry: () => ref.invalidate(categoryProvider(slug)),
        ),
        _ => const LoadingStateView(),
      },
    );
  }
}

class _CategoryContent extends StatelessWidget {
  const _CategoryContent({required this.category});
  final FoodCategory category;

  static const _drinks = {
    'cerveza',
    'micheladas',
    'cocteles',
    'tequila',
    'mezcal',
    'vino',
    'shots',
    'cafe',
    'ron',
    'whisky',
    'vodka',
    'margaritas',
    'mojitos',
    'sangria',
    'limonada',
    'jugos',
    'smoothies',
    'refrescos',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = category.defaultUnit.plural;
    final isDrink = _drinks.contains(category.slug);

    return CenteredContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDrink
                    ? const [AppColors.lilac, AppColors.cream]
                    : const [AppColors.blush, AppColors.creamSoft],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Column(
              children: [
                if (isDrink)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Bebida',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.flameDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                Hero(
                  tag: 'category-${category.slug}',
                  child: Text(category.icon, style: const TextStyle(fontSize: 88)),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  category.name,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Se cuenta en $unit',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () =>
                context.push(AppRoutes.createPath(categoryId: category.id)),
            icon: const Icon(Icons.local_fire_department_rounded),
            label: Text('RETO DE ${category.name.toUpperCase()}'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.rankings),
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('Ver ranking'),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Récord actual'),
          EmptyStateView(
            compact: true,
            emoji: '👑',
            title: 'Sin récord todavía',
            message:
                'Quien complete el primer reto público de '
                '${category.name.toLowerCase()} se lo lleva.',
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Restaurantes'),
          const EmptyStateView(
            compact: true,
            emoji: '📍',
            title: 'Aún no hay locales con retos',
            message: 'Los restaurantes aparecerán cuando alguien compita aquí.',
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Retos públicos'),
          EmptyStateView(
            compact: true,
            emoji: category.icon,
            title: 'Nadie ha publicado un reto',
            message: 'Invita a tus amigos y estrena esta categoría.',
          ),
        ],
      ),
    );
  }
}
