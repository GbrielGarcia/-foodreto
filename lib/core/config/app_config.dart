import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Backend que usa la app en esta ejecución.
enum BackendMode {
  /// Firebase real (requiere `flutterfire configure`).
  firebase,

  /// Repositorios en memoria. Para desarrollar sin Firebase y para tests.
  local,
}

class AppConfig {
  const AppConfig({
    required this.backendMode,
    this.useEmulators = false,
    this.useCloudFunctions = true,
    this.googleMapsApiKey = '',
    this.publicBaseUrl = defaultPublicBaseUrl,
  });

  /// Dominio de Firebase Hosting del proyecto. Se puede cambiar con
  /// `--dart-define=FOODRETO_PUBLIC_URL=https://…` (p. ej. dominio propio).
  static const defaultPublicBaseUrl = 'https://foodreto.web.app';

  final BackendMode backendMode;

  /// Firebase contra el Emulator Suite local (Auth + Firestore + Functions).
  final bool useEmulators;

  /// Cloud Functions para materializar rankings / notifs / admin.
  ///
  /// Default true en Firebase: evita doble trabajo del cliente (costo) y
  /// deja el Admin SDK en el servidor. Pon
  /// `--dart-define=FOODRETO_CLOUD_FUNCTIONS=false` para modo Spark cliente.
  final bool useCloudFunctions;

  /// Maps SDK. Vacio = fallback OSM (sin factura Google Maps).
  /// `--dart-define=GOOGLE_MAPS_API_KEY=…` + misma key en Android/iOS nativo.
  final String googleMapsApiKey;

  /// Base de los enlaces que se comparten (`/join/CODIGO`) fuera de la web.
  final String publicBaseUrl;

  bool get isLocal => backendMode == BackendMode.local;

  /// Analytics solo con Firebase real: el emulador no debe ensuciar datos.
  bool get sendsAnalytics =>
      backendMode == BackendMode.firebase && !useEmulators;

  /// Functions activas (no local, flag on).
  bool get usesCloudFunctions =>
      backendMode == BackendMode.firebase && useCloudFunctions;

  /// Google Maps SDK (key presente). Si no, OSM gratis.
  bool get usesGoogleMaps => googleMapsApiKey.trim().isNotEmpty;
}

/// Se sobrescribe en `bootstrap()` una vez decidido el backend.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'appConfigProvider debe sobrescribirse en el ProviderScope raíz.',
  ),
);
