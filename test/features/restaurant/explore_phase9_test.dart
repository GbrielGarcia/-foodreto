import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/error/failure.dart';
import 'package:foodreto/core/error/result.dart';
import 'package:foodreto/core/utils/text_normalizer.dart';
import 'package:foodreto/features/challenge/data/repositories/in_memory_challenge_backend.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge.dart';
import 'package:foodreto/features/restaurant/data/models/restaurant_dto.dart';
import 'package:foodreto/features/restaurant/data/repositories/in_memory_restaurant_repository.dart';
import 'package:foodreto/features/restaurant/data/services/geolocator_location_service.dart';
import 'package:foodreto/features/restaurant/domain/entities/establishment_status.dart';
import 'package:foodreto/features/restaurant/domain/entities/restaurant.dart';
import 'package:foodreto/features/restaurant/domain/repositories/restaurant_repository.dart';
import 'package:foodreto/features/restaurant/domain/services/geo_distance.dart';
import 'package:foodreto/features/restaurant/domain/services/location_service.dart';
import 'package:foodreto/features/restaurant/presentation/providers/restaurant_providers.dart';

import '../challenge/challenge_fixtures.dart';

Restaurant _r({
  required String id,
  required String name,
  String city = 'Quito',
  List<String> categoryIds = const [],
  double? lat,
  double? lng,
  bool active = true,
  DateTime? createdAt,
}) {
  return Restaurant(
    id: id,
    name: name,
    slug: TextNormalizer.slugify(name),
    normalizedName: TextNormalizer.normalize(name),
    city: city,
    country: 'EC',
    categoryIds: categoryIds,
    latitude: lat,
    longitude: lng,
    isActive: active,
    createdAt: createdAt,
  );
}

T _value<T>(Result<T> r) =>
    r.fold(onSuccess: (v) => v, onFailure: (f) => throw f);

void main() {
  group('RestaurantDto', () {
    test('serializa coordenadas y campos opcionales', () {
      final r = RestaurantDto.fromMap('r1', {
        'name': 'Wing House',
        'city': 'Quito',
        'country': 'ec',
        'description': 'Alitas',
        'address': 'Av. 1',
        'imageUrl': 'https://example.com/a.jpg',
        'categoryIds': ['alitas', 'hamburguesas'],
        'nameLower': 'wing house',
        'latitude': -0.18,
        'longitude': -78.46,
        'isActive': true,
      })!;
      expect(r.nameLower, 'wing house');
      expect(r.hasLocation, isTrue);
      expect(r.latitude, -0.18);
      expect(r.longitude, -78.46);
      expect(r.categoryIds, ['alitas', 'hamburguesas']);
      expect(r.description, 'Alitas');
      expect(r.imageUrl, 'https://example.com/a.jpg');
    });

    test('rechaza datos invalidos', () {
      expect(RestaurantDto.fromMap('x', null), isNull);
      expect(RestaurantDto.fromMap('x', {}), isNull);
      expect(RestaurantDto.fromMap('x', {'name': '  '}), isNull);
    });

    test('sin coordenadas hasLocation es false', () {
      final r = RestaurantDto.fromMap('r1', {
        'name': 'Solo Nombre',
        'city': 'Quito',
        'country': 'EC',
      })!;
      expect(r.hasLocation, isFalse);
    });
  });

  group('GeoDistance', () {
    test('haversine ~0 para mismo punto', () {
      expect(
        GeoDistance.kmBetween(
          lat1: -0.18,
          lon1: -78.46,
          lat2: -0.18,
          lon2: -78.46,
        ),
        closeTo(0, 0.001),
      );
    });

    test('formato m / km', () {
      expect(GeoDistance.formatKm(0.25), '250 m');
      expect(GeoDistance.formatKm(1.2), '1.2 km');
      expect(GeoDistance.formatKm(15.4), '15 km');
    });
  });

  group('RestaurantRepository', () {
    late InMemoryRestaurantRepository repo;

    setUp(() {
      repo = InMemoryRestaurantRepository([
        _r(
          id: '1',
          name: 'Wing House',
          city: 'Quito',
          categoryIds: ['alitas'],
          lat: -0.18,
          lng: -78.46,
          createdAt: DateTime(2024, 1, 2),
        ),
        _r(
          id: '2',
          name: 'Sushi Bar',
          city: 'Guayaquil',
          categoryIds: ['sushi'],
          createdAt: DateTime(2024, 1, 1),
        ),
        _r(
          id: '3',
          name: 'Inactivo',
          city: 'Quito',
          active: false,
        ),
      ]);
    });

    test('getById solo activos', () async {
      expect(_value(await repo.getById('1'))?.id, '1');
      expect(_value(await repo.getById('3')), isNull);
    });

    test('paginacion', () async {
      final page = _value(await repo.getRestaurantsPage(limit: 1));
      expect(page.items, hasLength(1));
      expect(page.items.first.id, '1');
      expect(page.nextCursor, '1');
      final page2 =
          _value(await repo.getRestaurantsPage(limit: 1, cursor: '1'));
      expect(page2.items.first.id, '2');
      expect(page2.nextCursor, isNull);
    });

    test('filtro ciudad y categoria', () async {
      final byCity = _value(await repo.getRestaurantsPage(city: 'Quito'));
      expect(byCity.items.map((e) => e.id), ['1']);
      final byCat =
          _value(await repo.getRestaurantsPage(categoryId: 'sushi'));
      expect(byCat.items.map((e) => e.id), ['2']);
    });

    test('searchRestaurants por nombre y ciudad', () async {
      final byName = _value(await repo.searchRestaurants(query: 'wing'));
      expect(byName.map((e) => e.id), ['1']);
      final byCity = _value(await repo.searchRestaurants(query: 'guaya'));
      expect(byCity.map((e) => e.id), ['2']);
    });
  });

  group('FakeLocationService / map state', () {
    test('ubicacion concedida', () async {
      final svc = FakeLocationService(
        permission: LocationPermissionStatus.granted,
        snapshot: const UserLocationSnapshot(
          latitude: -0.2,
          longitude: -78.5,
          permission: LocationPermissionStatus.granted,
        ),
      );
      expect(await svc.checkPermission(), LocationPermissionStatus.granted);
      final loc = await svc.getCurrentLocation();
      expect(loc?.latitude, -0.2);
    });

    test('ubicacion denegada', () async {
      final svc = FakeLocationService(
        permission: LocationPermissionStatus.denied,
        snapshot: const UserLocationSnapshot(
          latitude: -0.2,
          longitude: -78.5,
          permission: LocationPermissionStatus.granted,
        ),
      );
      expect(await svc.getCurrentLocation(), isNull);
    });

    test('servicio deshabilitado', () async {
      final svc = FakeLocationService(
        permission: LocationPermissionStatus.serviceDisabled,
      );
      expect(
        await svc.checkPermission(),
        LocationPermissionStatus.serviceDisabled,
      );
      expect(await svc.getCurrentLocation(), isNull);
    });

    test('ExploreViewState usa default si no hay ubicacion', () {
      const state = ExploreViewState(restaurants: []);
      expect(state.mapCenter.latitude, ExploreDefaults.defaultLatitude);
      expect(state.userLocation, isNull);
    });

    test('ExploreViewState distancia local', () {
      final r = _r(id: '1', name: 'A', lat: -0.18, lng: -78.46);
      final state = ExploreViewState(
        restaurants: [r],
        userLocation: const UserLocationSnapshot(
          latitude: -0.18,
          longitude: -78.46,
          permission: LocationPermissionStatus.granted,
        ),
      );
      expect(state.distanceKm(r), closeTo(0, 0.01));
      expect(state.markers, hasLength(1));
    });
  });

  group('ExploreController', () {
    test('loading success empty', () async {
      final repo = InMemoryRestaurantRepository([
        _r(id: '1', name: 'Wing House', createdAt: DateTime(2024)),
      ]);
      final container = ProviderContainer(
        overrides: [
          restaurantRepositoryProvider.overrideWithValue(repo),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(exploreControllerProvider.future);
      expect(state.restaurants, hasLength(1));

      await container
          .read(exploreControllerProvider.notifier)
          .setCategory('no-existe');
      final filtered =
          container.read(exploreControllerProvider).requireValue;
      expect(filtered.restaurants, isEmpty);
    });

    test('error si el repo falla', () async {
      final container = ProviderContainer(
        overrides: [
          restaurantRepositoryProvider.overrideWithValue(_FailingRepo()),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(exploreControllerProvider.future),
        throwsA(anything),
      );
    });
  });

  group('Privacy retos publicos', () {
    test('listPublicByRestaurant no incluye privados', () async {
      final backend = InMemoryChallengeBackend();
      final pub = _value(
        await backend.createChallenge(
          const NewChallenge(
            categoryId: 'alitas',
            title: 'Publico',
            restaurantId: 'rest1',
            visibility: ChallengeVisibility.public,
          ),
          ana,
        ),
      );
      await backend.createChallenge(
        const NewChallenge(
          categoryId: 'alitas',
          title: 'Privado',
          restaurantId: 'rest1',
          visibility: ChallengeVisibility.private,
        ),
        ana,
      );
      final list =
          _value(await backend.listPublicByRestaurant(restaurantId: 'rest1'));
      expect(list.map((c) => c.id), [pub.id]);
      expect(
        list.every((c) => c.visibility == ChallengeVisibility.public),
        isTrue,
      );
    });
  });
}

class _FailingRepo implements RestaurantRepository {
  @override
  Future<Result<Restaurant?>> getById(String id) async =>
      const Result.success(null);

  @override
  Future<Result<Restaurant?>> getBySlug(String slug) async =>
      const Result.success(null);

  @override
  Future<Result<List<Restaurant>>> searchByName(
    String query, {
    int limit = 20,
  }) async =>
      const Result.success([]);

  @override
  Future<Result<RestaurantPage>> getRestaurantsPage({
    int limit = 20,
    String? cursor,
    String? city,
    String? categoryId,
  }) async =>
      const Result.failure(UnexpectedFailure('boom'));

  @override
  Future<Result<List<Restaurant>>> searchRestaurants({
    required String query,
    int limit = 20,
  }) async =>
      const Result.failure(UnexpectedFailure('boom'));

  @override
  Future<Result<String>> createRequest(CreateEstablishmentRequest request) async =>
      const Result.success('x');

  @override
  Future<Result<List<Restaurant>>> listMine(String uid) async =>
      const Result.success([]);

  @override
  Future<Result<RestaurantPage>> listByStatus(
    EstablishmentStatus status, {
    int limit = 20,
    String? cursor,
  }) async =>
      const Result.success(RestaurantPage(items: []));

  @override
  Future<Result<void>> updateOwnerFields({
    required String id,
    required String ownerUid,
    required OwnerEstablishmentUpdate update,
  }) async =>
      const Result.success(null);

  @override
  Future<Result<List<Restaurant>>> findPossibleDuplicates(
    String nameLower,
    String city,
  ) async =>
      const Result.success([]);
}
