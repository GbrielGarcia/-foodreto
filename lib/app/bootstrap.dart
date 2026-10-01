import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/firebase/emulator_config.dart';
import '../firebase_options.dart';
import 'app.dart';
import 'boot_splash.dart';

Future<void> bootstrap() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Muestra branding FoodReto mientras inicializa Firebase (sustituye el
  // logo de Flutter / pantalla en blanco).
  runApp(const BootSplash());

  final config = await _initBackend();
  FlutterNativeSplash.remove();

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const FoodRetoApp(),
    ),
  );
}

Future<AppConfig> _initBackend() async {
  const local = AppConfig(backendMode: BackendMode.local);

  if (const String.fromEnvironment('FOODRETO_BACKEND') == 'local') {
    return local;
  }

  final baseOptions = _firebaseOptions();
  if (baseOptions == null) {
    debugPrint(
      'FoodReto: Firebase sin configurar, usando modo local. '
      'Ejecuta `flutterfire configure` para conectar el backend.',
    );
    return local;
  }

  final useEmulator =
      const String.fromEnvironment('FOODRETO_BACKEND') == 'emulator';
  final options = useEmulator
      ? EmulatorConfig.optionsFor(baseOptions)
      : baseOptions;

  await Firebase.initializeApp(options: options);
  await _activateAppCheck();

  if (useEmulator) {
    final host = EmulatorConfig.host();
    // Antes de cualquier lectura: apunta al emulador y desactiva caché local
    // para no mezclar datos de producción.
    FirebaseFirestore.instance.useFirestoreEmulator(
      host,
      EmulatorConfig.firestorePort,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    await FirebaseAuth.instance.useAuthEmulator(host, EmulatorConfig.authPort);
    debugPrint(
      'FoodReto: Firebase Emulator → project=${EmulatorConfig.projectId} '
      'Firestore=$host:${EmulatorConfig.firestorePort} '
      'Auth=$host:${EmulatorConfig.authPort}',
    );
    return AppConfig(
      backendMode: BackendMode.firebase,
      useEmulators: true,
      useCloudFunctions: _cloudFunctionsEnabled,
      googleMapsApiKey: _googleMapsApiKey,
      publicBaseUrl: _publicBaseUrl,
    );
  }

  _setUpCrashReporting();
  debugPrint(
    'FoodReto: Firebase REAL → project=${options.projectId} '
    'backend=firebase functions=${_cloudFunctionsEnabled ? "on" : "off"} '
    'maps=${_googleMapsApiKey.isEmpty ? "osm" : "google"}',
  );
  return AppConfig(
    backendMode: BackendMode.firebase,
    useCloudFunctions: _cloudFunctionsEnabled,
    googleMapsApiKey: _googleMapsApiKey,
    publicBaseUrl: _publicBaseUrl,
  );
}

/// Evita el warning "No AppCheckProvider installed".
/// En debug usa provider de debug; en release Play Integrity / DeviceCheck.
Future<void> _activateAppCheck() async {
  try {
    if (kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: WebDebugProvider(),
      );
      return;
    }
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? AppleDebugProvider()
          : const AppleDeviceCheckProvider(),
    );
  } catch (e, st) {
    debugPrint('FoodReto: App Check no activado ($e)');
    debugPrint('$st');
  }
}

const _publicBaseUrl = String.fromEnvironment(
  'FOODRETO_PUBLIC_URL',
  defaultValue: AppConfig.defaultPublicBaseUrl,
);

/// Default true: Functions materializan rankings (cliente no duplica writes).
const _cloudFunctionsEnabled =
    bool.fromEnvironment('FOODRETO_CLOUD_FUNCTIONS', defaultValue: true);

const _googleMapsApiKey = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY',
  defaultValue: '',
);

FirebaseOptions? _firebaseOptions() {
  try {
    return DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    // El archivo generado lanza esto en plataformas no configuradas.
    return null;
  }
}

void _setUpCrashReporting() {
  // Crashlytics no tiene soporte en web.
  if (kIsWeb) return;
  final crashlytics = FirebaseCrashlytics.instance;
  unawaited(crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode));
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}
