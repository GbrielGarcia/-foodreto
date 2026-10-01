import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/app/app.dart';
import 'package:foodreto/core/avatar/avatar_config.dart';
import 'package:foodreto/core/config/app_config.dart';
import 'package:foodreto/core/router/app_router.dart';
import 'package:foodreto/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:foodreto/features/auth/domain/entities/auth_user.dart';
import 'package:foodreto/features/auth/presentation/providers/auth_providers.dart';
import 'package:foodreto/features/profile/data/repositories/in_memory_profile_repository.dart';
import 'package:foodreto/features/profile/domain/entities/user_profile.dart';
import 'package:foodreto/features/profile/presentation/providers/profile_providers.dart';
import 'package:foodreto/features/restaurant/domain/services/geo_distance.dart';
import 'package:foodreto/features/restaurant/domain/services/map_provider.dart';
import 'package:foodreto/features/restaurant/presentation/providers/restaurant_providers.dart';
import 'package:foodreto/shared/widgets/user_avatar.dart';

const _widths = [320.0, 375.0, 390.0, 430.0, 768.0, 1024.0, 1440.0];

const _routes = [
  '/',
  '/categories',
  '/category/alitas',
  '/challenges',
  '/rankings',
  '/explore',
  '/profile',
  '/profile/edit',
  '/create',
  '/join/AB23CD',
];

class _StubMap implements MapProviderView {
  const _StubMap();

  @override
  Widget build({
    required LatLngPoint center,
    required double zoom,
    required List<RestaurantMapMarker> markers,
    required void Function(RestaurantMapMarker marker) onMarkerTap,
    LatLngPoint? userLocation,
  }) {
    return const ColoredBox(
      color: Color(0xFFE8EEF4),
      child: Center(child: Text('map')),
    );
  }
}

void main() {
  for (final width in _widths) {
    testWidgets('sin overflow a ${width.toInt()} px', (tester) async {
      const user = AuthUser(
        id: 'u1',
        email: 'gabriel@foodreto.app',
        displayName: 'Gabriel Guamán',
      );
      final profiles = InMemoryProfileRepository();
      await profiles.createProfile(
        const NewProfile(
          uid: 'u1',
          username: 'un_username_muy_larg',
          displayName: 'Gabriel Guamán con un nombre largo',
          avatar: AvatarConfig(style: 'adventurer', seed: 'gabriel'),
          bio:
              'Rey de las alitas 🍗 y del sushi 🍣, rompiendo récords cada fin de semana.',
        ),
      );
      final container = ProviderContainer.test(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(backendMode: BackendMode.local),
          ),
          avatarNetworkEnabledProvider.overrideWithValue(false),
          authRepositoryProvider.overrideWithValue(
            InMemoryAuthRepository(initialUser: user),
          ),
          profileRepositoryProvider.overrideWithValue(profiles),
          mapProviderViewProvider.overrideWithValue(const _StubMap()),
        ],
      );
      addTearDown(container.dispose);

      final height = width < 600 ? 700.0 : 900.0;
      tester.view
        ..physicalSize = Size(width, height) * 2
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FoodRetoApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final router = container.read(routerProvider);
      for (final route in _routes) {
        router.go(route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          router.state.uri.toString(),
          route,
          reason: 'no debe redirigir $route',
        );
      }
      // Riverpod pausa streams con timer 5m al salir de Rankings.
      await tester.pump(const Duration(minutes: 5));
    });
  }
}
