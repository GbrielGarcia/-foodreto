import 'dart:math' as math;

/// Calculos locales de distancia (nunca se persisten).
abstract final class GeoDistance {
  static const _earthRadiusKm = 6371.0;

  /// Haversine en kilometros.
  static double kmBetween({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static String formatKm(double km) {
    if (km < 1) {
      final m = (km * 1000).round();
      return '$m m';
    }
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  static double _rad(double deg) => deg * math.pi / 180;
}

/// Centro por defecto del mapa (Quito). Configurable; no es ubicacion del usuario.
abstract final class ExploreDefaults {
  static const defaultLatitude = -0.1807;
  static const defaultLongitude = -78.4678;
  static const defaultZoom = 12.0;
}

class LatLngPoint {
  const LatLngPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}
