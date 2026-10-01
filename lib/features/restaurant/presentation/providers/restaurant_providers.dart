import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../activity/domain/entities/social_activity.dart';
import '../../../activity/presentation/providers/activity_providers.dart';
import '../../../challenge/domain/entities/challenge.dart';
import '../../../challenge/presentation/providers/challenge_providers.dart';
import '../../../leaderboard/domain/entities/food_record.dart';
import '../../../leaderboard/domain/entities/ranking_entry.dart';
import '../../../leaderboard/domain/entities/ranking_scope.dart';
import '../../../leaderboard/presentation/providers/leaderboard_providers.dart';
import '../../data/repositories/firestore_restaurant_repository.dart';
import '../../data/repositories/in_memory_restaurant_repository.dart';
import '../../data/services/geolocator_location_service.dart';
import '../../domain/entities/restaurant.dart';
import '../../domain/repositories/restaurant_repository.dart';
import '../../domain/services/geo_distance.dart';
import '../../domain/services/location_service.dart';
import '../../domain/services/map_provider.dart';
import '../widgets/flutter_osm_map.dart';
import '../widgets/google_maps_map.dart';

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return switch (ref.watch(appConfigProvider).backendMode) {
    BackendMode.firebase => FirestoreRestaurantRepository(
        ref.watch(firestoreProvider),
      ),
    BackendMode.local => InMemoryRestaurantRepository(),
  };
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return GeolocatorLocationService();
});

/// Google Maps si hay API key; si no, OSM (0 costo Maps).
final mapProviderViewProvider = Provider<MapProviderView>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.usesGoogleMaps) {
    return const GoogleMapsMapFacade();
  }
  return const FlutterOsmMapProvider();
});

final restaurantProvider = FutureProvider.autoDispose
    .family<Restaurant?, String>((ref, id) async {
  final result = await ref.watch(restaurantRepositoryProvider).getById(id);
  return result.fold(
    onSuccess: (restaurant) => restaurant,
    onFailure: (failure) => throw failure,
  );
});

final restaurantBySlugProvider = FutureProvider.autoDispose
    .family<Restaurant?, String>((ref, slug) async {
  final result = await ref.watch(restaurantRepositoryProvider).getBySlug(slug);
  return result.fold(
    onSuccess: (restaurant) => restaurant,
    onFailure: (failure) => throw failure,
  );
});

/// Resultados de busqueda por nombre (wizard crear reto).
final restaurantSearchProvider = FutureProvider.autoDispose
    .family<List<Restaurant>, String>((ref, query) async {
  final result =
      await ref.watch(restaurantRepositoryProvider).searchByName(query);
  return result.fold(
    onSuccess: (restaurants) => restaurants,
    onFailure: (failure) => throw failure,
  );
});

class ExploreFilters {
  const ExploreFilters({
    this.query = '',
    this.city,
    this.categoryId,
    this.onlyWithLocation = false,
  });

  final String query;
  final String? city;
  final String? categoryId;
  final bool onlyWithLocation;

  ExploreFilters copyWith({
    String? query,
    String? city,
    bool clearCity = false,
    String? categoryId,
    bool clearCategory = false,
    bool? onlyWithLocation,
  }) =>
      ExploreFilters(
        query: query ?? this.query,
        city: clearCity ? null : (city ?? this.city),
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        onlyWithLocation: onlyWithLocation ?? this.onlyWithLocation,
      );
}

class ExploreViewState {
  const ExploreViewState({
    required this.restaurants,
    this.userLocation,
    this.permission = LocationPermissionStatus.unknown,
    this.nextCursor,
    this.filters = const ExploreFilters(),
    this.loadingMore = false,
    this.selectedRestaurantId,
  });

  final List<Restaurant> restaurants;
  final UserLocationSnapshot? userLocation;
  final LocationPermissionStatus permission;
  final String? nextCursor;
  final ExploreFilters filters;
  final bool loadingMore;
  final String? selectedRestaurantId;

  bool get hasMore => nextCursor != null;

  LatLngPoint get mapCenter {
    final u = userLocation;
    if (u != null) return u.point;
    final withLoc = restaurants.where((r) => r.hasLocation);
    if (withLoc.isNotEmpty) {
      return LatLngPoint(withLoc.first.latitude!, withLoc.first.longitude!);
    }
    return const LatLngPoint(
      ExploreDefaults.defaultLatitude,
      ExploreDefaults.defaultLongitude,
    );
  }

  List<RestaurantMapMarker> get markers => [
        for (final r in restaurants)
          if (r.hasLocation) RestaurantMapMarker.fromRestaurant(r),
      ];

  double? distanceKm(Restaurant r) {
    final u = userLocation;
    if (u == null || !r.hasLocation) return null;
    return GeoDistance.kmBetween(
      lat1: u.latitude,
      lon1: u.longitude,
      lat2: r.latitude!,
      lon2: r.longitude!,
    );
  }

  ExploreViewState copyWith({
    List<Restaurant>? restaurants,
    UserLocationSnapshot? userLocation,
    bool clearUserLocation = false,
    LocationPermissionStatus? permission,
    String? nextCursor,
    bool clearCursor = false,
    ExploreFilters? filters,
    bool? loadingMore,
    String? selectedRestaurantId,
    bool clearSelected = false,
  }) =>
      ExploreViewState(
        restaurants: restaurants ?? this.restaurants,
        userLocation:
            clearUserLocation ? null : (userLocation ?? this.userLocation),
        permission: permission ?? this.permission,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        filters: filters ?? this.filters,
        loadingMore: loadingMore ?? this.loadingMore,
        selectedRestaurantId: clearSelected
            ? null
            : (selectedRestaurantId ?? this.selectedRestaurantId),
      );
}

class ExploreController extends AsyncNotifier<ExploreViewState> {
  static const _pageSize = 30;
  Timer? _debounce;

  @override
  Future<ExploreViewState> build() async {
    ref.onDispose(() => _debounce?.cancel());
    return _load(const ExploreFilters());
  }

  Future<ExploreViewState> _load(ExploreFilters filters) async {
    final repo = ref.read(restaurantRepositoryProvider);

    if (filters.query.trim().isNotEmpty) {
      final result = await repo.searchRestaurants(
        query: filters.query,
        limit: _pageSize,
      );
      return result.fold(
        onSuccess: (list) {
          var items = list;
          if (filters.city != null) {
            final c = filters.city!.toLowerCase();
            items = items.where((r) => r.city.toLowerCase() == c).toList();
          }
          if (filters.categoryId != null) {
            items = items
                .where((r) => r.categoryIds.contains(filters.categoryId))
                .toList();
          }
          if (filters.onlyWithLocation) {
            items = items.where((r) => r.hasLocation).toList();
          }
          return ExploreViewState(restaurants: items, filters: filters);
        },
        onFailure: (f) => throw f,
      );
    }

    final result = await repo.getRestaurantsPage(
      limit: _pageSize,
      city: filters.city,
      categoryId: filters.categoryId,
    );
    return result.fold(
      onSuccess: (page) {
        var items = page.items;
        if (filters.onlyWithLocation) {
          items = items.where((r) => r.hasLocation).toList();
        }
        return ExploreViewState(
          restaurants: items,
          nextCursor: page.nextCursor,
          filters: filters,
        );
      },
      onFailure: (f) => throw f,
    );
  }

  void setQuery(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final current = state.asData?.value;
      final filters =
          (current?.filters ?? const ExploreFilters()).copyWith(query: query);
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _load(filters));
    });
  }

  Future<void> setCategory(String? categoryId) async {
    final current = state.asData?.value;
    final filters = (current?.filters ?? const ExploreFilters()).copyWith(
      categoryId: categoryId,
      clearCategory: categoryId == null,
    );
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(filters));
  }

  Future<void> setCity(String? city) async {
    final current = state.asData?.value;
    final filters = (current?.filters ?? const ExploreFilters()).copyWith(
      city: city,
      clearCity: city == null || city.isEmpty,
    );
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(filters));
  }

  Future<void> refresh() async {
    final filters = state.asData?.value.filters ?? const ExploreFilters();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(filters));
  }

  Future<void> requestLocation() async {
    final current = state.asData?.value;
    if (current == null) return;
    final loc = await ref.read(locationServiceProvider).getCurrentLocation();
    final permission =
        await ref.read(locationServiceProvider).checkPermission();
    var restaurants = [...current.restaurants];
    if (loc != null) {
      restaurants.sort((a, b) {
        final da = current.copyWith(userLocation: loc).distanceKm(a) ?? 1e9;
        final db = current.copyWith(userLocation: loc).distanceKm(b) ?? 1e9;
        return da.compareTo(db);
      });
    }
    state = AsyncData(
      current.copyWith(
        restaurants: restaurants,
        userLocation: loc,
        clearUserLocation: loc == null,
        permission: permission,
      ),
    );
  }

  void selectRestaurant(String? id) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        selectedRestaurantId: id,
        clearSelected: id == null,
      ),
    );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    if (current.filters.query.trim().isNotEmpty) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref.read(restaurantRepositoryProvider).getRestaurantsPage(
            limit: _pageSize,
            cursor: current.nextCursor,
            city: current.filters.city,
            categoryId: current.filters.categoryId,
          );
      page.fold(
        onSuccess: (p) {
          final seen = {for (final r in current.restaurants) r.id};
          state = AsyncData(
            current.copyWith(
              restaurants: [
                ...current.restaurants,
                for (final r in p.items)
                  if (seen.add(r.id)) r,
              ],
              nextCursor: p.nextCursor,
              loadingMore: false,
            ),
          );
        },
        onFailure: (f) => throw f,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final exploreControllerProvider =
    AsyncNotifierProvider.autoDispose<ExploreController, ExploreViewState>(
  ExploreController.new,
);

final restaurantPublicChallengesProvider = FutureProvider.autoDispose
    .family<List<Challenge>, String>((ref, restaurantId) async {
  final result = await ref.watch(challengeRepositoryProvider).listPublicByRestaurant(
        restaurantId: restaurantId,
      );
  return result.fold(
    onSuccess: (c) => c,
    onFailure: (_) => const <Challenge>[],
  );
});

final restaurantPublicActivitiesProvider = FutureProvider.autoDispose
    .family<List<SocialActivity>, String>((ref, restaurantId) async {
  final page = await ref
      .watch(activityRepositoryProvider)
      .getRestaurantActivities(restaurantId: restaurantId, limit: 10);
  return page.items;
});

final restaurantCategoryRecordProvider = FutureProvider.autoDispose
    .family<FoodRecord?, ({String restaurantId, String categoryId})>(
        (ref, args) {
  final scope = RankingScopes.restaurantCategory(
    args.restaurantId,
    args.categoryId,
  );
  return ref.watch(getRecordProvider)(scope);
});

final restaurantCategoryRankingProvider = FutureProvider.autoDispose.family<
    RankingPage,
    ({String restaurantId, String categoryId})>((ref, args) {
  final scope = RankingScopes.restaurantCategory(
    args.restaurantId,
    args.categoryId,
  );
  return ref.watch(leaderboardRepositoryProvider).getRanking(scopeKey: scope);
});
