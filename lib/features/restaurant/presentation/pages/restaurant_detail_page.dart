import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../activity/presentation/widgets/activity_tile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../category/domain/entities/food_category.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../../profile/domain/value_objects/username.dart';
import '../../domain/entities/restaurant.dart';
import '../../domain/services/geo_distance.dart';
import '../../domain/services/map_provider.dart';
import '../providers/restaurant_providers.dart';

/// Ficha publica del local. Layout full-bleed + panel de acciones.
class RestaurantDetailPage extends ConsumerWidget {
  const RestaurantDetailPage({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(restaurantProvider(restaurantId));
    final categories =
        ref.watch(categoriesProvider).value ?? const <FoodCategory>[];
    final map = ref.watch(mapProviderViewProvider);
    final uid = ref.watch(currentUserProvider)?.id;

    return async.when(
      loading: () => const Scaffold(body: LoadingStateView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyStateView(
          emoji: '\u26a0\ufe0f',
          title: 'No se pudo cargar',
          message: e.toString(),
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(restaurantProvider(restaurantId)),
        ),
      ),
      data: (restaurant) {
        if (restaurant == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyStateView(
              emoji: '\u{1F50D}',
              title: 'Local no encontrado',
              message: 'Puede estar inactivo o no existir.',
            ),
          );
        }

        final challenges =
            ref.watch(restaurantPublicChallengesProvider(restaurantId));
        final activities =
            ref.watch(restaurantPublicActivitiesProvider(restaurantId));
        final canManage = uid != null && restaurant.canOwnerManage(uid);
        final locationLine = [
          if (restaurant.address.isNotEmpty) restaurant.address,
          if (restaurant.city.isNotEmpty) restaurant.city,
          if (restaurant.country.isNotEmpty) restaurant.country,
        ].join(' \u00b7 ');
        final catLabels = <String>[
          for (final id in restaurant.categoryIds)
            for (final c in categories)
              if (c.id == id) '${c.icon} ${c.name}',
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFFFF8F4),
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 280,
                backgroundColor: AppColors.flameDeep,
                foregroundColor: Colors.white,
                iconTheme: const IconThemeData(color: Colors.white),
                actions: [
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => context.push(
                        AppRoutes.editEstablishmentPath(restaurantId),
                      ),
                    ),
                  if (restaurant.hasLocation)
                    IconButton(
                      tooltip: 'Google Maps',
                      icon: const Icon(Icons.directions_rounded),
                      onPressed: () => _openGoogleMaps(
                        lat: restaurant.latitude!,
                        lng: restaurant.longitude!,
                        label: restaurant.name,
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _Hero(
                    restaurant: restaurant,
                    locationLine: locationLine,
                  ),
                ),
              ),
              // Panel principal con esquinas redondeadas hacia arriba.
              SliverToBoxAdapter(
                child: Container(
                  transform: Matrix4.translationValues(0, -18, 0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF8F4),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    28,
                    20,
                    restaurant.whatsapp.isNotEmpty ? 100 : 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Avatar + nombre compacto
                      Row(
                        children: [
                          _Avatar(restaurant: restaurant, size: 64),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  restaurant.name,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.ink,
                                    height: 1.1,
                                  ),
                                ),
                                if (locationLine.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    locationLine,
                                    style: const TextStyle(
                                      color: AppColors.inkMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (restaurant.description.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          restaurant.description,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                      if (catLabels.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final label in catLabels)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.flame.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.flameDeep,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      // CTA principal
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.flame,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => context.push(AppRoutes.create),
                        icon: const Icon(Icons.local_fire_department_rounded),
                        label: const Text(
                          'CREAR RETO AQUI',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.flameDeep,
                                minimumSize: const Size.fromHeight(48),
                                side: BorderSide(
                                  color: AppColors.flame.withValues(alpha: 0.4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => context.push(
                                AppRoutes.restaurantRankingPath(restaurantId),
                              ),
                              icon: const Icon(Icons.emoji_events_outlined),
                              label: const Text('Ranking'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1A73E8),
                                minimumSize: const Size.fromHeight(48),
                                side: const BorderSide(
                                  color: Color(0xFF1A73E8),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: restaurant.hasLocation
                                  ? () => _openGoogleMaps(
                                        lat: restaurant.latitude!,
                                        lng: restaurant.longitude!,
                                        label: restaurant.name,
                                      )
                                  : null,
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Maps'),
                            ),
                          ),
                        ],
                      ),
                      if (_hasQuickLinks(restaurant)) ...[
                        const SizedBox(height: 18),
                        _ContactStrip(restaurant: restaurant),
                      ],
                      if (restaurant.hasLocation) ...[
                        const SizedBox(height: 28),
                        const _BlockTitle('COMO LLEGAR'),
                        const SizedBox(height: 10),
                        _DirectionsMap(
                          restaurant: restaurant,
                          map: map,
                          onOpen: () => _openGoogleMaps(
                            lat: restaurant.latitude!,
                            lng: restaurant.longitude!,
                            label: restaurant.name,
                          ),
                        ),
                      ],
                      if (restaurant.galleryUrls.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const _BlockTitle('GALERIA'),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 150,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: restaurant.galleryUrls.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                restaurant.galleryUrls[i],
                                width: 200,
                                height: 150,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      _BlockTitle(
                        'RANKING',
                        action: 'Ver todo',
                        onAction: () => context.push(
                          AppRoutes.restaurantRankingPath(restaurantId),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (restaurant.categoryIds.isEmpty)
                        const _EmptyBox(
                          icon: Icons.emoji_events_outlined,
                          title: 'Sin categor\u00edas',
                          message:
                              'Este local a\u00fan no tiene categor\u00edas de reto.',
                        )
                      else
                        for (final catId in restaurant.categoryIds)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CategoryRankTile(
                              restaurantId: restaurantId,
                              categoryId: catId,
                              categoryLabel: () {
                                for (final c in categories) {
                                  if (c.id == catId) {
                                    return '${c.icon} ${c.name}';
                                  }
                                }
                                return catId;
                              }(),
                            ),
                          ),
                      const SizedBox(height: 28),
                      const _BlockTitle('RETOS'),
                      const SizedBox(height: 10),
                      challenges.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const _EmptyBox(
                          icon: Icons.sports_esports_outlined,
                          title: 'No se pudieron cargar',
                          message: 'Intenta m\u00e1s tarde.',
                        ),
                        data: (items) {
                          if (items.isEmpty) {
                            return const _EmptyBox(
                              icon: Icons.local_fire_department_outlined,
                              title: 'Sin retos p\u00fablicos',
                              message:
                                  'Cuando alguien cree un reto aqu\u00ed, aparecer\u00e1.',
                            );
                          }
                          return Column(
                            children: [
                              for (final c in items.take(8))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ListCard(
                                    icon: Icons.flag_rounded,
                                    title: c.title.isNotEmpty
                                        ? c.title
                                        : 'Reto ${c.categoryId}',
                                    subtitle:
                                        '${c.participantIds.length} participantes',
                                    onTap: () => context.push(
                                      AppRoutes.challengePath(c.id),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      const _BlockTitle('ACTIVIDAD'),
                      const SizedBox(height: 10),
                      activities.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const _EmptyBox(
                          icon: Icons.history,
                          title: 'Sin actividad',
                          message: 'No se pudo cargar el feed del local.',
                        ),
                        data: (items) {
                          if (items.isEmpty) {
                            return const _EmptyBox(
                              icon: Icons.history,
                              title: 'Sin actividad todav\u00eda',
                              message:
                                  'Los r\u00e9cords y retos del local saldr\u00e1n aqu\u00ed.',
                            );
                          }
                          return Column(
                            children: [
                              for (final a in items)
                                ActivityTile(activity: a),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: restaurant.whatsapp.isEmpty
              ? null
              : FloatingActionButton(
                  heroTag: 'restaurant-whatsapp-$restaurantId',
                  backgroundColor: AppColors.whatsapp,
                  foregroundColor: Colors.white,
                  tooltip: 'WhatsApp',
                  onPressed: () {
                    final n =
                        restaurant.whatsapp.replaceAll(RegExp(r'[^\d+]'), '');
                    _openUrl('https://wa.me/${n.replaceFirst('+', '')}');
                  },
                  child: const _WhatsAppLogo(),
                ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.restaurant, required this.locationLine});

  final Restaurant restaurant;
  final String locationLine;

  @override
  Widget build(BuildContext context) {
    final url = restaurant.imageUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: AppColors.flameDeep,
              child: Icon(Icons.storefront, size: 72, color: Colors.white54),
            ),
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.flame, AppColors.flameDeep, Color(0xFF5A2A26)],
              ),
            ),
            child: Center(
              child: Icon(Icons.storefront_rounded, size: 80, color: Colors.white38),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0x00000000),
                Color(0xE61A1210),
              ],
              stops: [0, 0.35, 1],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 36,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.flame,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'LOCAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                restaurant.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              if (locationLine.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  locationLine,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.restaurant, required this.size});
  final Restaurant restaurant;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        color: AppColors.blush,
        image: restaurant.displayAvatarUrl != null
            ? DecorationImage(
                image: NetworkImage(restaurant.displayAvatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: restaurant.displayAvatarUrl == null
          ? const Icon(Icons.storefront, color: AppColors.flameDeep)
          : null,
    );
  }
}

class _ContactStrip extends StatelessWidget {
  const _ContactStrip({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, IconData icon, Color color, VoidCallback onTap})>[
      if (restaurant.phone.isNotEmpty)
        (
          label: 'Llamar',
          icon: Icons.phone_rounded,
          color: const Color(0xFF2E7D57),
          onTap: () => _openUrl('tel:${restaurant.phone}'),
        ),
      if (restaurant.websiteUrl.isNotEmpty)
        (
          label: 'Web',
          icon: Icons.language_rounded,
          color: const Color(0xFF3D6FA8),
          onTap: () => _openUrl(restaurant.websiteUrl),
        ),
      if (restaurant.instagramUrl.isNotEmpty)
        (
          label: 'IG',
          icon: Icons.camera_alt_rounded,
          color: const Color(0xFFC13584),
          onTap: () => _openUrl(restaurant.instagramUrl),
        ),
      if (restaurant.facebookUrl.isNotEmpty)
        (
          label: 'FB',
          icon: Icons.facebook_rounded,
          color: const Color(0xFF1877F2),
          onTap: () => _openUrl(restaurant.facebookUrl),
        ),
      if (restaurant.tiktokUrl.isNotEmpty)
        (
          label: 'TikTok',
          icon: Icons.music_note_rounded,
          color: AppColors.ink,
          onTap: () => _openUrl(restaurant.tiktokUrl),
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            ActionChip(
              avatar: Icon(item.icon, size: 18, color: item.color),
              label: Text(item.label),
              onPressed: item.onTap,
              backgroundColor: Colors.white,
              side: BorderSide(color: item.color.withValues(alpha: 0.25)),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _DirectionsMap extends StatelessWidget {
  const _DirectionsMap({
    required this.restaurant,
    required this.map,
    required this.onOpen,
  });

  final Restaurant restaurant;
  final MapProviderView map;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: IgnorePointer(
                child: map.build(
                  center: LatLngPoint(
                    restaurant.latitude!,
                    restaurant.longitude!,
                  ),
                  zoom: 15,
                  markers: [RestaurantMapMarker.fromRestaurant(restaurant)],
                  onMarkerTap: (_) {},
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xFF1A73E8),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: const Row(
                children: [
                  Icon(Icons.directions_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Abrir en Google Maps',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockTitle extends StatelessWidget {
  const _BlockTitle(this.title, {this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.flame,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: AppColors.ink,
            ),
          ),
        ),
        if (action != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DFD8)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: AppColors.flame),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: CircleAvatar(
            backgroundColor: AppColors.flame.withValues(alpha: 0.12),
            child: Icon(icon, color: AppColors.flameDeep),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

bool _hasQuickLinks(Restaurant restaurant) =>
    restaurant.phone.isNotEmpty ||
    restaurant.websiteUrl.isNotEmpty ||
    restaurant.instagramUrl.isNotEmpty ||
    restaurant.facebookUrl.isNotEmpty ||
    restaurant.tiktokUrl.isNotEmpty;

Future<void> _openUrl(String raw) async {
  final uri = Uri.tryParse(raw);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _openGoogleMaps({
  required double lat,
  required double lng,
  String? label,
}) async {
  final query = label == null || label.isEmpty
      ? '$lat,$lng'
      : Uri.encodeComponent('$lat,$lng($label)');
  final web = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$lat%2C$lng',
  );
  final geo = Uri.parse('geo:$lat,$lng?q=$query');
  if (await canLaunchUrl(geo)) {
    final ok = await launchUrl(geo, mode: LaunchMode.externalApplication);
    if (ok) return;
  }
  await launchUrl(web, mode: LaunchMode.externalApplication);
}

class _CategoryRankTile extends ConsumerWidget {
  const _CategoryRankTile({
    required this.restaurantId,
    required this.categoryId,
    required this.categoryLabel,
  });

  final String restaurantId;
  final String categoryId;
  final String categoryLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(
      restaurantCategoryRecordProvider((
        restaurantId: restaurantId,
        categoryId: categoryId,
      )),
    );
    final ranking = ref.watch(
      restaurantCategoryRankingProvider((
        restaurantId: restaurantId,
        categoryId: categoryId,
      )),
    );

    final recordText = record.when(
      loading: () => 'Cargando...',
      error: (_, _) => 'Sin r\u00e9cord',
      data: (r) {
        if (r == null || !r.hasHolders) return 'Sin r\u00e9cord a\u00fan';
        return 'R\u00e9cord ${Username.display(r.holders.first.username)} \u00b7 ${r.score}';
      },
    );
    final topText = ranking.when(
      loading: () => null,
      error: (_, _) => null,
      data: (page) {
        if (page.entries.isEmpty) return null;
        final top = page.entries.first;
        return 'L\u00edder ${Username.display(top.username)} \u00b7 ${top.bestScore}';
      },
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
          AppRoutes.restaurantRankingPath(
            restaurantId,
            categoryId: categoryId,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8DFD8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(recordText, style: const TextStyle(color: AppColors.inkMuted)),
                    if (topText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        topText,
                        style: const TextStyle(
                          color: AppColors.flameDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhatsAppLogo extends StatelessWidget {
  const _WhatsAppLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 28),
      painter: _WhatsAppPainter(),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path();
    // Simplified WhatsApp bubble + phone glyph.
    final w = size.width;
    final h = size.height;
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.05, w * 0.84, h * 0.72),
        Radius.circular(w * 0.28),
      ),
    );
    path.moveTo(w * 0.28, h * 0.72);
    path.lineTo(w * 0.18, h * 0.95);
    path.lineTo(w * 0.42, h * 0.78);
    path.close();
    canvas.drawPath(path, paint);

    final phone = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;
    final phonePath = Path()
      ..moveTo(w * 0.32, h * 0.28)
      ..cubicTo(w * 0.32, h * 0.22, w * 0.38, h * 0.18, w * 0.44, h * 0.2)
      ..lineTo(w * 0.5, h * 0.24)
      ..cubicTo(w * 0.54, h * 0.26, w * 0.54, h * 0.32, w * 0.5, h * 0.34)
      ..lineTo(w * 0.46, h * 0.38)
      ..cubicTo(w * 0.52, h * 0.48, w * 0.6, h * 0.54, w * 0.7, h * 0.58)
      ..lineTo(w * 0.74, h * 0.54)
      ..cubicTo(w * 0.76, h * 0.5, w * 0.82, h * 0.5, w * 0.84, h * 0.54)
      ..lineTo(w * 0.88, h * 0.6)
      ..cubicTo(w * 0.9, h * 0.66, w * 0.86, h * 0.72, w * 0.8, h * 0.72)
      ..cubicTo(w * 0.55, h * 0.72, w * 0.32, h * 0.52, w * 0.32, h * 0.28);
    canvas.drawPath(phonePath, phone);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
