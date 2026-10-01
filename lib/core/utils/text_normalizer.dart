/// Normalización de texto para búsquedas, slugs y detección de duplicados.
abstract final class TextNormalizer {
  static const _accents = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', //
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', //
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
    'ñ': 'n', 'ç': 'c',
  };

  static String removeAccents(String input) {
    final buffer = StringBuffer();
    for (final char in input.split('')) {
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString();
  }

  /// Minúsculas, sin acentos, sin signos y con espacios simples.
  /// "  Wing  House! " → "wing house"
  static String normalize(String input) {
    return removeAccents(input.toLowerCase())
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// "Hot Dogs de Tío Pepe" → "hot-dogs-de-tio-pepe"
  static String slugify(String input) => normalize(input).replaceAll(' ', '-');
}
