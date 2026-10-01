import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/super_admin_providers.dart';
import '../../../category/domain/entities/food_category.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../domain/entities/restaurant.dart';
import '../../domain/services/geo_distance.dart';
import '../../domain/services/location_service.dart';
import '../../domain/services/map_provider.dart';
import '../providers/restaurant_providers.dart';

class ExplorePage extends ConsumerWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final explore = ref.watch(exploreControllerProvider);
    final categories =
        ref.watch(categoriesProvider).value ?? const <FoodCategory>[];
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final mapHeight = width < 600 ? 200.0 : 300.0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: explore.when(
                loading: () => const LoadingStateView(
                  message: 'Cargando restaurantes...',
                ),
                error: (e, _) => EmptyStateView(
                  emoji: '\u26a0\ufe0f',
                  title: 'No pudimos cargar los restaurantes.',
                  message: 'Intentar nuevamente.',
                  actionLabel: 'Intentar nuevamente',
                  onAction: () =>
                      ref.read(exploreControllerProvider.notifier).refresh(),
                ),
                data: (state) {
                  if (wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ExploreHeader(theme: theme, count: state.restaurants.length),
                        const _AdminNavBanner(),
                        const SizedBox(height: AppSpacing.sm),
                        const _SearchField(),
                        const SizedBox(height: AppSpacing.sm),
                        const _QuickLinks(),
                        const SizedBox(height: AppSpacing.sm),
                        _CategoryFilters(
                          categories: categories,
                          state: state,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _LocationBanner(state: state),
                        const SizedBox(height: AppSpacing.md),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 3, child: _MapPanel(state: state)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                flex: 2,
                                child: _ListPanel(state: state),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels >=
                          n.metrics.maxScrollExtent - 200) {
                        ref
                            .read(exploreControllerProvider.notifier)
                            .loadMore();
                      }
                      return false;
                    },
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ExploreHeader(
                                theme: theme,
                                count: state.restaurants.length,
                              ),
                              const _AdminNavBanner(),
                              const SizedBox(height: AppSpacing.sm),
                              const _SearchField(),
                              const SizedBox(height: AppSpacing.sm),
                              const _QuickLinks(),
                              const SizedBox(height: AppSpacing.sm),
                              _CategoryFilters(
                                categories: categories,
                                state: state,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _LocationBanner(state: state),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                height: mapHeight,
                                child: _MapPanel(state: state),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Cerca de ti',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                          ),
                        ),
                        if (state.restaurants.isEmpty)
                          const SliverToBoxAdapter(
                            child: EmptyStateView(
                              compact: true,
                              emoji: '\u{1F50D}',
                              title:
                                  'No encontramos restaurantes aqu\u00ed.',
                              message:
                                  'Prueba otra ciudad o categor\u00eda.',
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                            sliver: SliverList.separated(
                              itemCount: state.restaurants.length +
                                  (state.loadingMore ? 1 : 0),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                if (i >= state.restaurants.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(AppSpacing.md),
                                    child: Center(
                                      child: SizedBox.square(
                                        dimension: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return _RestaurantCard(
                                  restaurant: state.restaurants[i],
                                  state: state,
                                  categories: categories,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader({required this.theme, required this.count});
  final ThemeData theme;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cream, AppColors.blush],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.flame.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explorar',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count > 0
                ? '$count locales · retos, rankings y mapas'
                : 'Descubre restaurantes, retos y récords.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextField(
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search_rounded),
        hintText: 'Buscar restaurante o ciudad…',
      ),
      onChanged: (q) =>
          ref.read(exploreControllerProvider.notifier).setQuery(q),
    );
  }
}

class _AdminNavBanner extends ConsumerWidget {
  const _AdminNavBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final superAdmin = ref.watch(isSuperAdminProvider);
    return superAdmin.when(
      data: (isAdmin) {
        if (!isAdmin) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.sm),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go(AppRoutes.admin),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Panel administración'),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _QuickLinks extends ConsumerWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentUserProvider) != null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (signedIn) ...[
            _QuickChip(
              icon: Icons.add_business_rounded,
              label: 'Registrar local',
              onTap: () => context.push(AppRoutes.createEstablishment),
            ),
            const SizedBox(width: 8),
            _QuickChip(
              icon: Icons.storefront_rounded,
              label: 'Mis locales',
              onTap: () => context.push(AppRoutes.myEstablishments),
            ),
            const SizedBox(width: 8),
          ],
          _QuickChip(
            icon: Icons.grid_view_rounded,
            label: 'Categorías',
            onTap: () => context.push(AppRoutes.categories),
          ),
          const SizedBox(width: 8),
          _QuickChip(
            icon: Icons.local_fire_department_rounded,
            label: 'Retos',
            onTap: () => context.go(AppRoutes.challenges),
          ),
          const SizedBox(width: 8),
          _QuickChip(
            icon: Icons.emoji_events_rounded,
            label: 'Rankings',
            onTap: () => context.go(AppRoutes.rankings),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _CategoryFilters extends ConsumerWidget {
  const _CategoryFilters({required this.categories, required this.state});

  final List<FoodCategory> categories;
  final ExploreViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Todas'),
              selected: state.filters.categoryId == null,
              onSelected: (_) =>
                  ref.read(exploreControllerProvider.notifier).setCategory(null),
            ),
          ),
          for (final c in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${c.icon} ${c.name}'),
                selected: state.filters.categoryId == c.id,
                onSelected: (selected) => ref
                    .read(exploreControllerProvider.notifier)
                    .setCategory(selected ? c.id : null),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocationBanner extends ConsumerWidget {
  const _LocationBanner({required this.state});
  final ExploreViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (state.userLocation != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.sage.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.near_me_rounded, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ordenado por cercanía',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.permission == LocationPermissionStatus.deniedForever
                ? 'Ubicación denegada. Puedes explorar igual.'
                : 'Activa tu ubicación para encontrar locales cercanos.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () =>
                ref.read(exploreControllerProvider.notifier).requestLocation(),
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('Usar ubicación'),
          ),
        ],
      ),
    );
  }
}

class _MapPanel extends ConsumerWidget {
  const _MapPanel({required this.state});
  final ExploreViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(mapProviderViewProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: map.build(
        center: state.mapCenter,
        zoom: ExploreDefaults.defaultZoom,
        markers: state.markers,
        userLocation: state.userLocation?.point,
        onMarkerTap: (m) {
          ref
              .read(exploreControllerProvider.notifier)
              .selectRestaurant(m.restaurantId);
          _showPreview(context, ref, m);
        },
      ),
    );
  }

  void _showPreview(
    BuildContext context,
    WidgetRef ref,
    RestaurantMapMarker m,
  ) {
    Restaurant? full;
    for (final r in state.restaurants) {
      if (r.id == m.restaurantId) {
        full = r;
        break;
      }
    }
    final categories =
        ref.read(categoriesProvider).value ?? const <FoodCategory>[];
    final km = full == null ? null : state.distanceKm(full);
    final catLabels = <String>[];
    for (final id in (full?.categoryIds ?? m.categoryIds).take(4)) {
      for (final c in categories) {
        if (c.id == id) {
          catLabels.add('${c.icon} ${c.name}');
          break;
        }
      }
    }
    final locationLine = [
      if ((full?.address ?? m.address).isNotEmpty) full?.address ?? m.address,
      if ((full?.city ?? m.city).isNotEmpty) full?.city ?? m.city,
      if ((full?.country ?? m.country).isNotEmpty) full?.country ?? m.country,
    ].join(' · ');
    final description = full?.description ?? m.description;
    final avatar = full?.displayAvatarUrl ?? m.displayAvatarUrl;
    final phone = full?.phone ?? m.phone;
    final whatsapp = full?.whatsapp ?? m.whatsapp;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: avatar != null
                          ? Image.network(
                              avatar,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => ColoredBox(
                                color: AppColors.blush,
                                child: Center(
                                  child: Text(
                                    m.name.isNotEmpty
                                        ? m.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                      color: AppColors.flameDeep,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : ColoredBox(
                              color: AppColors.blush,
                              child: Center(
                                child: Text(
                                  m.name.isNotEmpty
                                      ? m.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 24,
                                    color: AppColors.flameDeep,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (locationLine.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  locationLine,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (km != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'A ${GeoDistance.formatKm(km)}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.flameDeep,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (catLabels.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in catLabels)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(label),
                      ),
                  ],
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (phone.isNotEmpty || whatsapp.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    if (phone.isNotEmpty)
                      ActionChip(
                        avatar: const Icon(Icons.phone_rounded, size: 18),
                        label: const Text('Llamar'),
                        onPressed: () => launchUrl(
                          Uri.parse('tel:$phone'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    if (whatsapp.isNotEmpty)
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.whatsapp,
                          foregroundColor: Colors.white,
                        ),
                        tooltip: 'WhatsApp',
                        icon: const Icon(Icons.chat_rounded),
                        onPressed: () {
                          final n =
                              whatsapp.replaceAll(RegExp(r'[^\d+]'), '');
                          launchUrl(
                            Uri.parse(
                              'https://wa.me/${n.replaceFirst('+', '')}',
                            ),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.restaurantPath(m.restaurantId));
                },
                child: const Text('Ver restaurante'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ListPanel extends ConsumerWidget {
  const _ListPanel({required this.state});
  final ExploreViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <FoodCategory>[];
    if (state.restaurants.isEmpty) {
      return const EmptyStateView(
        compact: true,
        emoji: '\u{1F50D}',
        title: 'No encontramos restaurantes aquí.',
        message: 'Prueba otra ciudad o categoría.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cerca de ti',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                ref.read(exploreControllerProvider.notifier).loadMore();
              }
              return false;
            },
            child: ListView.separated(
              itemCount:
                  state.restaurants.length + (state.loadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i >= state.restaurants.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return _RestaurantCard(
                  restaurant: state.restaurants[i],
                  state: state,
                  categories: categories,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.restaurant,
    required this.state,
    required this.categories,
  });

  final Restaurant restaurant;
  final ExploreViewState state;
  final List<FoodCategory> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final km = state.distanceKm(restaurant);
    final selected = state.selectedRestaurantId == restaurant.id;
    final catLabels = <String>[];
    for (final id in restaurant.categoryIds.take(3)) {
      for (final c in categories) {
        if (c.id == id) {
          catLabels.add('${c.icon} ${c.name}');
          break;
        }
      }
    }

    return Material(
      color: selected
          ? AppColors.creamHigh
          : theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.restaurantPath(restaurant.id)),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.flame.withValues(alpha: 0.35)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: restaurant.displayAvatarUrl != null
                        ? Image.network(
                            restaurant.displayAvatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _AvatarFallback(
                              name: restaurant.name,
                            ),
                          )
                        : _AvatarFallback(name: restaurant.name),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (restaurant.city.isNotEmpty) restaurant.city,
                          if (km != null) GeoDistance.formatKm(km),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (catLabels.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          catLabels.join('  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.flameDeep,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.blush,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: AppColors.flameDeep,
          ),
        ),
      ),
    );
  }
}
