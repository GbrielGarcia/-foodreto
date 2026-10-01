import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/food_category.dart';

/// Tarjeta de categoría para grids y carruseles.
class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.category, this.compact = false});

  final FoodCategory category;

  /// Versión pequeña para el carrusel del Inicio.
  final bool compact;

  static const _pastels = [
    AppColors.blush,
    AppColors.sage,
    AppColors.lilac,
    AppColors.creamHigh,
  ];

  Color get _tint => _pastels[category.order.abs() % _pastels.length];

  bool get _isDrink {
    const drinks = {
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
    return drinks.contains(category.slug);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emojiSize = compact ? 34.0 : 44.0;

    return Material(
      color: _tint,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.categoryPath(category.slug)),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.ink.withValues(alpha: 0.06),
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!compact && _isDrink)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.paper.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Bebida',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.flameDeep,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Hero(
                      tag: 'category-${category.slug}',
                      child: Text(
                        category.icon,
                        style: TextStyle(fontSize: emojiSize),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  category.name,
                  style:
                      (compact
                              ? theme.textTheme.labelLarge
                              : theme.textTheme.titleSmall)
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (!compact)
                  Text(
                    category.defaultUnit.plural,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
