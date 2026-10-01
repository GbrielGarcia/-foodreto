import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/food_category.dart';
import '../providers/category_providers.dart';
import '../widgets/category_card.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  String _query = '';
  var _filter = _CatFilter.all;

  List<FoodCategory> _filterList(List<FoodCategory> categories) {
    final q = TextNormalizer.normalize(_query);
    var list = categories;
    if (_filter == _CatFilter.food) {
      list = list.where((c) => !_drinkSlugs.contains(c.slug)).toList();
    } else if (_filter == _CatFilter.drinks) {
      list = list.where((c) => _drinkSlugs.contains(c.slug)).toList();
    }
    if (q.isEmpty) return list;
    return list
        .where((c) => TextNormalizer.normalize(c.name).contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Categorías',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Elige comida o bebida y crea tu reto.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          hintText: 'Buscar alitas, cerveza, tacos…',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final f in _CatFilter.values)
                            ChoiceChip(
                              label: Text(f.label),
                              selected: _filter == f,
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: switch (categories) {
                    AsyncData(:final value) => _Grid(
                      categories: _filterList(value),
                      query: _query,
                      isCatalogEmpty: value.isEmpty,
                    ),
                    AsyncError() => ErrorStateView(
                      message: 'No pudimos cargar las categorías.',
                      onRetry: () => ref.invalidate(categoriesProvider),
                    ),
                    _ => const LoadingStateView(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _drinkSlugs = {
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

enum _CatFilter {
  all('Todas'),
  food('Comida'),
  drinks('Bebidas');

  const _CatFilter(this.label);
  final String label;
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.categories,
    required this.query,
    required this.isCatalogEmpty,
  });

  final List<FoodCategory> categories;
  final String query;
  final bool isCatalogEmpty;

  @override
  Widget build(BuildContext context) {
    if (isCatalogEmpty) {
      return const EmptyStateView(
        emoji: '🍽️',
        title: 'Aún no hay categorías',
        message: 'El menú se está preparando. Vuelve en un momento.',
      );
    }
    if (categories.isEmpty) {
      return EmptyStateView(
        emoji: '🔎',
        title: 'No encontramos "${query.trim()}"',
        message: 'Prueba otra búsqueda o cambia el filtro.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.92,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) =>
          CategoryCard(category: categories[index]),
    );
  }
}
