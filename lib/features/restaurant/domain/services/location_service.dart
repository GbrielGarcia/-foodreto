import 'geo_distance.dart';

enum LocationPermissionStatus {
  unknown,
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class UserLocationSnapshot {
  const UserLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.permission,
  });

  final double latitude;
  final double longitude;
  final LocationPermissionStatus permission;

  LatLngPoint get point => LatLngPoint(latitude, longitude);
}

/// Abstraccion de ubicacion del dispositivo (nunca se persiste).
abstract class LocationService {
  Future<LocationPermissionStatus> checkPermission();

  Future<LocationPermissionStatus> requestPermission();

  /// Obtiene posicion actual si hay permiso. No lanza: retorna null.
  Future<UserLocationSnapshot?> getCurrentLocation();
}
