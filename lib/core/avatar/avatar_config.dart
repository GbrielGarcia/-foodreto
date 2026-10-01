import 'dart:math';

/// Estilo de DiceBear ofrecido en el selector.
///
/// Solo estilos cuyo SVG usa elementos que `flutter_svg` renderiza igual en
/// Android, iOS y Web (sin filtros SVG).
class AvatarStyle {
  const AvatarStyle(this.id, this.label);

  /// Identificador en la API de DiceBear (`/10.x/{id}/svg`).
  final String id;
  final String label;
}

/// Avatar reproducible: el mismo estilo + semilla + opciones produce siempre
/// la misma imagen, así que no se guarda ningún archivo.
class AvatarConfig {
  const AvatarConfig({
    required this.style,
    required this.seed,
    this.options = const {},
  });

  factory AvatarConfig.random({Random? random}) {
    final r = random ?? Random.secure();
    return AvatarConfig(
      style: styles[r.nextInt(styles.length)].id,
      seed: randomSeed(random: r),
      options: {
        'backgroundColor': backgroundColors[r.nextInt(backgroundColors.length)],
      },
    );
  }

  /// Lee datos persistidos; valores desconocidos caen a valores seguros.
  factory AvatarConfig.fromData({
    Object? style,
    Object? seed,
    Object? options,
  }) {
    final styleId = style is String && isValidStyle(style)
        ? style
        : defaultStyle;
    final seedValue = seed is String && isValidSeed(seed) ? seed : 'foodreto';
    final raw = options is Map ? options : const {};
    return AvatarConfig(
      style: styleId,
      seed: seedValue,
      options: sanitizeOptions(raw),
    );
  }

  final String style;
  final String seed;

  /// Solo claves de [allowedOptionKeys] con valores validados.
  final Map<String, String> options;

  static const defaultStyle = 'adventurer';
  static const maxSeedLength = 64;

  static const styles = [
    AvatarStyle('adventurer', 'Aventurero'),
    AvatarStyle('avataaars', 'Clásico'),
    AvatarStyle('big-smile', 'Sonrisa'),
    AvatarStyle('fun-emoji', 'Emoji'),
    AvatarStyle('lorelei', 'Lorelei'),
    AvatarStyle('micah', 'Micah'),
    AvatarStyle('notionists', 'Boceto'),
    AvatarStyle('open-peeps', 'Peeps'),
    AvatarStyle('pixel-art', 'Pixel'),
    AvatarStyle('thumbs', 'Pulgar'),
  ];

  /// Fondos de la paleta de marca (hex sin `#`, como los espera DiceBear).
  static const backgroundColors = [
    'ffc53d',
    'ff8a5b',
    '2ed3a1',
    '7cc4ff',
    'b69cff',
    'ff7eb6',
    'f1e4d3',
    '22222d',
  ];

  static const allowedOptionKeys = {'backgroundColor'};

  static final _seedRegExp = RegExp(r'^[\w\-]+$');

  static bool isValidStyle(String style) => styles.any((s) => s.id == style);

  static bool isValidSeed(String seed) =>
      seed.isNotEmpty &&
      seed.length <= maxSeedLength &&
      _seedRegExp.hasMatch(seed);

  static Map<String, String> sanitizeOptions(Map<Object?, Object?> raw) {
    final result = <String, String>{};
    final background = raw['backgroundColor'];
    if (background is String && backgroundColors.contains(background)) {
      result['backgroundColor'] = background;
    }
    return result;
  }

  static String randomSeed({Random? random}) {
    const chars = 'abcdefghijkmnpqrstuvwxyz23456789';
    final r = random ?? Random.secure();
    return List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String? get backgroundColor => options['backgroundColor'];

  AvatarConfig copyWith({
    String? style,
    String? seed,
    String? backgroundColor,
  }) {
    return AvatarConfig(
      style: style ?? this.style,
      seed: seed ?? this.seed,
      options: {...options, 'backgroundColor': ?backgroundColor},
    );
  }

  Map<String, Object> toData() => {
    'avatarStyle': style,
    'avatarSeed': seed,
    'avatarOptions': options,
  };

  @override
  bool operator ==(Object other) =>
      other is AvatarConfig &&
      other.style == style &&
      other.seed == seed &&
      _mapEquals(other.options, options);

  @override
  int get hashCode => Object.hash(
    style,
    seed,
    Object.hashAllUnordered(options.entries.map((e) => '${e.key}=${e.value}')),
  );

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
