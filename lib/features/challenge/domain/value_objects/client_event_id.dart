import 'dart:math';

/// Identificador de evento generado en el dispositivo.
///
/// 20 caracteres alfanuméricos de `Random.secure` (~119 bits): colisiones
/// prácticamente imposibles, y válido como ID de documento de Firestore.
/// Cuando llegue el outbox (Fase 4) el mismo ID se guardará en local antes de
/// enviarse, así que un reintento reutiliza el ID y no duplica el conteo.
abstract final class ClientEventId {
  static const length = 20;
  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static final _pattern = RegExp('^[A-Za-z0-9]{$length}\$');

  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => _alphabet.codeUnitAt(rng.nextInt(_alphabet.length)),
      ),
    );
  }

  static bool isValid(String id) => _pattern.hasMatch(id);
}
