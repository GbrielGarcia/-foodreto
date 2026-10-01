import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Constantes y helpers del Firebase Emulator Suite.
///
/// El seed (`tool/seed/seed_categories.mjs --project demo-foodreto`) y la app
/// deben usar el **mismo** [projectId]: el emulador aísla los datos por
/// proyecto. Si Flutter usa `foodreto` y el seed `demo-foodreto`, la app ve
/// `categories` vacío sin error.
abstract final class EmulatorConfig {
  /// Debe coincidir con `--project` del emulador y del seed.
  static const projectId = 'demo-foodreto';

  static const firestorePort = 8080;
  static const authPort = 9099;

  /// Host del emulador.
  ///
  /// - Override: `--dart-define=FOODRETO_EMULATOR_HOST=…`
  /// - Android (AVD): `10.0.2.2` (localhost del host)
  /// - Web / iOS / desktop: `localhost`
  static String host({
    String fromEnvironment = const String.fromEnvironment(
      'FOODRETO_EMULATOR_HOST',
    ),
    TargetPlatform? platform,
    bool? isWeb,
  }) {
    final onWeb = isWeb ?? kIsWeb;
    final target = platform ?? defaultTargetPlatform;
    if (fromEnvironment.isNotEmpty) return fromEnvironment;
    if (!onWeb && target == TargetPlatform.android) return '10.0.2.2';
    return 'localhost';
  }

  /// Opciones de Firebase con [projectId] del emulador (mismo que el seed).
  static FirebaseOptions optionsFor(FirebaseOptions base) =>
      base.copyWith(projectId: projectId);
}
