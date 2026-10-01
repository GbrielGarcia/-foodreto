import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/services/geo_distance.dart';
import '../../domain/services/map_provider.dart';

/// Google Maps SDK con opciones low-cost.
///
/// - Android detalle (1 marker): lite mode (casi sin tiles).
/// - Explorar: interactivo minimo (sin traffic / buildings / toolbar).
/// - Sin Places / Directions / Geocoding.
class GoogleMapsMapProvider implements MapProviderView {
  const GoogleMapsMapProvider({this.litePreferred = false});

  final bool litePreferred;

  @override
  Widget build({
    required LatLngPoint center,
    required double zoom,
    required List<RestaurantMapMarker> markers,
    required void Function(RestaurantMapMarker marker) onMarkerTap,
    LatLngPoint? userLocation,
  }) {
    final lite = litePreferred &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android;
    final camera = CameraPosition(
      target: LatLng(center.latitude, center.longitude),
      zoom: zoom.clamp(3, 18),
    );

    final markerSet = <Marker>{
      for (final m in markers)
        Marker(
          markerId: MarkerId(m.restaurantId),
          position: LatLng(m.position.latitude, m.position.longitude),
          infoWindow: InfoWindow(title: m.name),
          onTap: () => onMarkerTap(m),
          consumeTapEvents: true,
        ),
      if (userLocation != null)
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(userLocation.latitude, userLocation.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Tu ubicacion'),
        ),
    };

    return GoogleMap(
      initialCameraPosition: camera,
      markers: markerSet,
      liteModeEnabled: lite,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      indoorViewEnabled: false,
      trafficEnabled: false,
      buildingsEnabled: false,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,
      scrollGesturesEnabled: !lite,
      zoomGesturesEnabled: !lite,
      mapType: MapType.normal,
      minMaxZoomPreference: const MinMaxZoomPreference(5, 18),
    );
  }
}

/// Detalle = lite; explorar (varios markers) = interactivo.
class GoogleMapsMapFacade implements MapProviderView {
  const GoogleMapsMapFacade();

  @override
  Widget build({
    required LatLngPoint center,
    required double zoom,
    required List<RestaurantMapMarker> markers,
    required void Function(RestaurantMapMarker marker) onMarkerTap,
    LatLngPoint? userLocation,
  }) {
    return GoogleMapsMapProvider(litePreferred: markers.length <= 1).build(
      center: center,
      zoom: zoom,
      markers: markers,
      onMarkerTap: onMarkerTap,
      userLocation: userLocation,
    );
  }
}
