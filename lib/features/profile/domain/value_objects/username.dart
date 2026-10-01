import '../../../../core/utils/text_normalizer.dart';

enum UsernameError { empty, tooShort, tooLong, invalidCharacters }

/// Reglas del @username: 3–20 caracteres, letras, números y `_`.
///
/// Se guarda siempre en minúsculas, así "Gabriel" y "gabriel" son el mismo.
abstract final class Username {
  static const minLength = 3;
  static const maxLength = 20;

  /// Debe coincidir con la regex de `firestore.rules`.
  static final pattern = RegExp('^[a-z0-9_]{$minLength,$maxLength}\$');

  /// Quita la `@` inicial, espacios exteriores y pasa a minúsculas.
  static String normalize(String input) {
    var value = input.trim().toLowerCase();
    if (value.startsWith('@')) value = value.substring(1);
    return value;
  }

  static UsernameError? validate(String input) {
    final value = normalize(input);
    if (value.isEmpty) return UsernameError.empty;
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
      return UsernameError.invalidCharacters;
    }
    if (value.length < minLength) return UsernameError.tooShort;
    if (value.length > maxLength) return UsernameError.tooLong;
    return null;
  }

  static bool isValid(String input) => validate(input) == null;

  static String message(UsernameError error) => switch (error) {
    UsernameError.empty => 'Elige tu @username.',
    UsernameError.tooShort => 'Mínimo $minLength caracteres.',
    UsernameError.tooLong => 'Máximo $maxLength caracteres.',
    UsernameError.invalidCharacters =>
      'Solo letras, números y _ (sin espacios ni guiones).',
  };

  /// Validador para `TextFormField`.
  static String? formValidator(String? value) {
    final error = validate(value ?? '');
    return error == null ? null : message(error);
  }

  /// Propuesta inicial a partir del nombre o del correo.
  /// "Gabriel Guamán" → "gabriel_guaman"
  static String suggest({String? displayName, String? email}) {
    final source = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!
        : (email?.split('@').first ?? '');
    var value = TextNormalizer.normalize(
      source,
    ).replaceAll(' ', '_').replaceAll(RegExp('[^a-z0-9_]'), '');
    if (value.length > maxLength) value = value.substring(0, maxLength);
    value = value.replaceAll(RegExp(r'_+$'), '');
    if (value.length < minLength) {
      value = 'foodie${value.isEmpty ? '' : '_$value'}';
    }
    return value;
  }

  static String display(String username) => '@$username';
}
