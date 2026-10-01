import 'avatar_config.dart';

/// Construye la URL de la API HTTP de DiceBear para un [AvatarConfig].
abstract final class DiceBear {
  /// Versión fijada: cambiarla altera el dibujo de todos los avatares
  /// existentes, así que requiere una decisión explícita.
  static const apiVersion = '10.x';

  static Uri svgUri(AvatarConfig config) {
    return Uri.https('api.dicebear.com', '/$apiVersion/${config.style}/svg', {
      'seed': config.seed,
      ...config.options,
    });
  }
}
