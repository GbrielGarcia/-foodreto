import 'dart:math';

/// Código de invitación de un reto (p. ej. `AB12CD`).
///
/// Alfabeto sin caracteres ambiguos (sin 0/O, 1/I/L) para dictarlo en voz alta.
/// 31⁶ ≈ 887 millones de combinaciones. La unicidad no depende del azar: el
/// código se reserva en `inviteCodes/{code}` en la misma transacción que crea
/// el reto.
abstract final class InviteCode {
  static const length = 6;
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static final _validRegExp = RegExp('^[$alphabet]{$length}\$');

  /// Mayúsculas y sin espacios ni guiones.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  static bool isValid(String input) => _validRegExp.hasMatch(normalize(input));

  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => alphabet.codeUnitAt(rng.nextInt(alphabet.length)),
      ),
    );
  }
}
