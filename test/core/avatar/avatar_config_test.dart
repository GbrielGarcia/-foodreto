import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/avatar/avatar_config.dart';
import 'package:foodreto/core/avatar/dicebear.dart';

void main() {
  test('la URL es reproducible y usa la versión fijada', () {
    const config = AvatarConfig(
      style: 'avataaars',
      seed: 'gabriel123',
      options: {'backgroundColor': 'ffc53d'},
    );
    final a = DiceBear.svgUri(config);
    final b = DiceBear.svgUri(
      AvatarConfig.fromData(
        style: 'avataaars',
        seed: 'gabriel123',
        options: {'backgroundColor': 'ffc53d'},
      ),
    );
    expect(a, b);
    expect(
      a.toString(),
      'https://api.dicebear.com/10.x/avataaars/svg?seed=gabriel123&backgroundColor=ffc53d',
    );
  });

  test('toData guarda estilo, semilla y opciones', () {
    const config = AvatarConfig(style: 'micah', seed: 'abc', options: {});
    expect(config.toData(), {
      'avatarStyle': 'micah',
      'avatarSeed': 'abc',
      'avatarOptions': <String, String>{},
    });
  });

  group('fromData sanea datos persistidos', () {
    test('estilo desconocido cae al estilo por defecto', () {
      final config = AvatarConfig.fromData(style: 'hackeado', seed: 'x');
      expect(config.style, AvatarConfig.defaultStyle);
    });

    test('semilla inválida o ausente usa un valor seguro', () {
      expect(AvatarConfig.fromData(seed: '').seed, 'foodreto');
      expect(AvatarConfig.fromData(seed: '<script>').seed, 'foodreto');
      expect(AvatarConfig.fromData(seed: 'a' * 65).seed, 'foodreto');
    });

    test('solo conserva opciones permitidas con valores de la paleta', () {
      final config = AvatarConfig.fromData(
        style: 'micah',
        seed: 'x',
        options: {'backgroundColor': '000000', 'radius': '50'},
      );
      expect(config.options, isEmpty);

      final ok = AvatarConfig.fromData(
        style: 'micah',
        seed: 'x',
        options: {'backgroundColor': 'ffc53d', 'radius': '50'},
      );
      expect(ok.options, {'backgroundColor': 'ffc53d'});
    });
  });

  test('random genera configuraciones válidas y deterministas con semilla', () {
    final a = AvatarConfig.random(random: Random(7));
    final b = AvatarConfig.random(random: Random(7));
    expect(a, b);
    expect(AvatarConfig.isValidStyle(a.style), isTrue);
    expect(AvatarConfig.isValidSeed(a.seed), isTrue);
    expect(AvatarConfig.backgroundColors, contains(a.backgroundColor));
  });

  test('copyWith e igualdad por valor', () {
    const base = AvatarConfig(style: 'micah', seed: 'x');
    final changed = base.copyWith(seed: 'y', backgroundColor: '2ed3a1');
    expect(changed.seed, 'y');
    expect(changed.backgroundColor, '2ed3a1');
    expect(changed == base, isFalse);
    expect(base.copyWith(), base);
    expect(base.copyWith().hashCode, base.hashCode);
  });
}
