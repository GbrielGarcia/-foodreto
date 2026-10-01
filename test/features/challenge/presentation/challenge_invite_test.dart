import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/features/challenge/presentation/share/challenge_invite.dart';

void main() {
  test('el enlace apunta a /join/CODIGO del dominio configurado', () {
    expect(
      ChallengeInvite.link(
        baseUrl: 'https://foodreto.web.app',
        code: 'AB23CD',
      ).toString(),
      'https://foodreto.web.app/join/AB23CD',
    );
    expect(
      ChallengeInvite.link(baseUrl: 'http://localhost:8766', code: 'AB23CD')
          .toString(),
      'http://localhost:8766/join/AB23CD',
    );
  });

  test('mensaje con emoji, título, restaurante, código y enlace', () {
    final link = ChallengeInvite.link(
      baseUrl: 'https://foodreto.web.app',
      code: 'AB23CD',
    );
    expect(
      ChallengeInvite.message(
        title: 'Reto de alitas',
        emoji: '🍗',
        code: 'AB23CD',
        link: link,
        restaurantName: 'Wing House',
      ),
      '🍗 Reto de alitas\n'
      '📍 Wing House\n'
      'Código: AB23CD\n'
      'Únete aquí: https://foodreto.web.app/join/AB23CD',
    );
  });

  test('sin restaurante no hay línea vacía', () {
    final message = ChallengeInvite.message(
      title: 'Reto de sushi',
      emoji: '🍣',
      code: 'QWERTY',
      link: Uri.parse('https://foodreto.web.app/join/QWERTY'),
    );
    expect(message.split('\n'), hasLength(3));
    expect(message, isNot(contains('📍')));
  });

  test('fuera de la web se usa el dominio público', () {
    expect(
      ChallengeInvite.baseUrl('https://foodreto.web.app'),
      'https://foodreto.web.app',
    );
  });
}
