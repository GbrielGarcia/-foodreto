import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/features/profile/domain/value_objects/username.dart';

void main() {
  group('validate', () {
    test('acepta los ejemplos válidos', () {
      for (final valid in [
        'gabriel',
        'gabriel_dev',
        'foodreto_ec',
        'abc',
        'a' * 20,
      ]) {
        expect(Username.validate(valid), isNull, reason: valid);
      }
    });

    test('rechaza demasiado corto', () {
      expect(Username.validate('g'), UsernameError.tooShort);
      expect(Username.validate('ga'), UsernameError.tooShort);
    });

    test('rechaza más de 20 caracteres', () {
      expect(Username.validate('a' * 21), UsernameError.tooLong);
    });

    test('rechaza espacios, guiones y acentos', () {
      expect(
        Username.validate('gabriel guaman'),
        UsernameError.invalidCharacters,
      );
      expect(Username.validate('gabriel-dev'), UsernameError.invalidCharacters);
      expect(Username.validate('guamán'), UsernameError.invalidCharacters);
      expect(Username.validate('gabo.ec'), UsernameError.invalidCharacters);
    });

    test('vacío', () {
      expect(Username.validate('   '), UsernameError.empty);
      expect(Username.validate('@'), UsernameError.empty);
    });
  });

  group('normalize', () {
    test('pasa a minúsculas para comparar', () {
      expect(Username.normalize('Gabriel_Dev'), 'gabriel_dev');
      expect(Username.validate('GABRIEL'), isNull);
    });

    test('quita la @ inicial y espacios exteriores', () {
      expect(Username.normalize('  @Gabriel '), 'gabriel');
    });

    test('coincide con la regex de las reglas', () {
      expect(
        Username.pattern.hasMatch(Username.normalize('@FoodReto_EC')),
        isTrue,
      );
    });
  });

  group('suggest', () {
    test('desde el nombre, sin acentos ni espacios', () {
      expect(Username.suggest(displayName: 'Gabriel Guamán'), 'gabriel_guaman');
    });

    test('desde el correo si no hay nombre', () {
      expect(Username.suggest(email: 'liss.p@correo.com'), 'liss_p');
    });

    test('siempre devuelve un username válido', () {
      for (final name in [
        'Ñu',
        '',
        '!!!',
        'Un nombre larguísimo de verdad aquí',
      ]) {
        final suggestion = Username.suggest(displayName: name);
        expect(
          Username.isValid(suggestion),
          isTrue,
          reason: '"$name" → $suggestion',
        );
      }
    });
  });

  test('display añade @', () {
    expect(Username.display('gabriel'), '@gabriel');
  });
}
