import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/services/location_service.dart';

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationPermissionStatus> checkPermission() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return LocationPermissionStatus.serviceDisabled;
      return _map(await Geolocator.checkPermission());
    } on MissingPluginException {
      // Hot reload / restart incompleto: el plugin nativo no esta registrado.
      return LocationPermissionStatus.unknown;
    }
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return LocationPermissionStatus.serviceDisabled;
      var status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied) {
        status = await Geolocator.requestPermission();
      }
      return _map(status);
    } on MissingPluginException {
      return LocationPermissionStatus.unknown;
    }
  }

  @override
  Future<UserLocationSnapshot?> getCurrentLocation() async {
    final permission = await requestPermission();
    if (permission != LocationPermissionStatus.granted) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return UserLocationSnapshot(
        latitude: pos.latitude,
        longitude: pos.longitude,
        permission: permission,
      );
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  LocationPermissionStatus _map(LocationPermission p) => switch (p) {
        LocationPermission.always || LocationPermission.whileInUse =>
          LocationPermissionStatus.granted,
        LocationPermission.deniedForever =>
          LocationPermissionStatus.deniedForever,
        LocationPermission.denied => LocationPermissionStatus.denied,
        LocationPermission.unableToDetermine =>
          LocationPermissionStatus.unknown,
      };
}

/// Para tests / modo sin GPS.
class FakeLocationService implements LocationService {
  FakeLocationService({
    this.permission = LocationPermissionStatus.denied,
    this.snapshot,
  });

  LocationPermissionStatus permission;
  UserLocationSnapshot? snapshot;

  @override
  Future<LocationPermissionStatus> checkPermission() async => permission;

  @override
  Future<LocationPermissionStatus> requestPermission() async => permission;

  @override
  Future<UserLocationSnapshot?> getCurrentLocation() async =>
      permission == LocationPermissionStatus.granted ? snapshot : null;
}
