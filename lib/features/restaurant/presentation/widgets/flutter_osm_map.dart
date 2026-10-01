import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/services/geo_distance.dart';
import '../../domain/services/map_provider.dart';

/// Mapa multiplataforma con tiles OSM (sin API key).
///
/// Attribution: OpenStreetMap contributors.
class FlutterOsmMapProvider implements MapProviderView {
  const FlutterOsmMapProvider();

  @override
  Widget build({
    required LatLngPoint center,
    required double zoom,
    required List<RestaurantMapMarker> markers,
    required void Function(RestaurantMapMarker marker) onMarkerTap,
    LatLngPoint? userLocation,
  }) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(center.latitude, center.longitude),
        initialZoom: zoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.tinguardevtechnology.foodreto',
        ),
        MarkerLayer(
          markers: [
            if (userLocation != null)
              Marker(
                point: LatLng(userLocation.latitude, userLocation.longitude),
                width: 36,
                height: 36,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blueAccent,
                  size: 28,
                ),
              ),
            for (final m in markers)
              Marker(
                point: LatLng(m.position.latitude, m.position.longitude),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => onMarkerTap(m),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.redAccent,
                    size: 36,
                  ),
                ),
              ),
          ],
        ),
        // Compacto: evita overflow en mapas estrechos (?280px).
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  'OSM',
                  style: TextStyle(fontSize: 10, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
