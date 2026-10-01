import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/features/challenge/domain/value_objects/invite_code.dart';

void main() {
  test('normaliza mayúsculas, espacios y guiones', () {
    expect(InviteCode.normalize('ab2-3cd '), 'AB23CD');
  });

  test('acepta códigos del alfabeto', () {
    expect(InviteCode.isValid('AB23CD'), isTrue);
    expect(InviteCode.isValid('ab 23 cd'), isTrue);
  });

  test('rechaza longitud incorrecta y caracteres ambiguos', () {
    expect(InviteCode.isValid('AB23C'), isFalse);
    expect(InviteCode.isValid('AB23CDE'), isFalse);
    expect(InviteCode.isValid('AB10CD'), isFalse, reason: '0 y 1 excluidos');
    expect(InviteCode.isValid('ABOICD'), isFalse, reason: 'O e I excluidas');
  });
}
