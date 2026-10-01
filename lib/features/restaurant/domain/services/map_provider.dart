import 'package:flutter/widgets.dart';

import '../entities/restaurant.dart';
import 'geo_distance.dart';

/// Marcador de restaurante en el mapa (datos minimos).
class RestaurantMapMarker {
  const RestaurantMapMarker({
    required this.restaurantId,
    required this.name,
    required this.position,
    this.city = '',
    this.country = '',
    this.address = '',
    this.description = '',
    this.imageUrl,
    this.logoUrl,
    this.categoryIds = const [],
    this.phone = '',
    this.whatsapp = '',
  });

  final String restaurantId;
  final String name;
  final LatLngPoint position;
  final String city;
  final String country;
  final String address;
  final String description;
  final String? imageUrl;
  final String? logoUrl;
  final List<String> categoryIds;
  final String phone;
  final String whatsapp;

  String? get displayAvatarUrl =>
      (logoUrl != null && logoUrl!.isNotEmpty) ? logoUrl : imageUrl;

  factory RestaurantMapMarker.fromRestaurant(Restaurant r) =>
      RestaurantMapMarker(
        restaurantId: r.id,
        name: r.name,
        position: LatLngPoint(r.latitude!, r.longitude!),
        city: r.city,
        country: r.country,
        address: r.address,
        description: r.description,
        imageUrl: r.imageUrl,
        logoUrl: r.logoUrl,
        categoryIds: r.categoryIds,
        phone: r.phone,
        whatsapp: r.whatsapp,
      );
}

/// Abstraccion de mapa. Dominio/UI no dependen del SDK concreto.
///
/// Implementaciones:
/// - [GoogleMapsMapFacade]: Google Maps SDK (lite en detalle, low-cost).
/// - [FlutterOsmMapProvider]: OpenStreetMap via flutter_map (sin API key).
///
/// Seleccion: `AppConfig.usesGoogleMaps` (API key via dart-define).
abstract class MapProviderView {
  /// Construye el widget de mapa.
  Widget build({
    required LatLngPoint center,
    required double zoom,
    required List<RestaurantMapMarker> markers,
    required void Function(RestaurantMapMarker marker) onMarkerTap,
    LatLngPoint? userLocation,
  });
}
