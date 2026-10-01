import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/utils/validators.dart';

void main() {
  test('email', () {
    expect(Validators.email(''), isNotNull);
    expect(Validators.email('gabriel'), isNotNull);
    expect(Validators.email('gabriel@foodreto'), isNotNull);
    expect(Validators.email(' gabriel@foodreto.app '), isNull);
  });

  test('password', () {
    expect(Validators.password(''), isNotNull);
    expect(Validators.password('1234567'), isNotNull);
    expect(Validators.password('12345678'), isNull);
  });

  test('displayName', () {
    expect(Validators.displayName('   '), isNotNull);
    expect(Validators.displayName('a' * 41), isNotNull);
    expect(Validators.displayName('Gabriel'), isNull);
  });
}
