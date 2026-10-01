/// Validadores de formularios. Devuelven `null` si el valor es válido.
abstract final class Validators {
  static final _emailRegExp = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static const minPasswordLength = 8;
  static const maxDisplayNameLength = 40;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Escribe tu correo.';
    if (!_emailRegExp.hasMatch(v)) return 'Ese correo no parece válido.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Escribe tu contraseña.';
    if (v.length < minPasswordLength) {
      return 'Mínimo $minPasswordLength caracteres.';
    }
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '¿Cómo te llamas?';
    if (v.length > maxDisplayNameLength) {
      return 'Máximo $maxDisplayNameLength caracteres.';
    }
    return null;
  }
}
