import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes email including numeric addresses', () {
    final contact = LoginIdentifier.detect('  Staff@School.Example  ');
    expect(contact?.kind, 'email');
    expect(contact?.value, 'staff@school.example');
    expect(LoginIdentifier.detect('0712345678@example.com')?.kind, 'email');
  });
  test('normalizes international phones independently of country support', () {
    for (final input in ['+2250712345678', ' +225 (07) 12-34.56 78 ']) {
      final contact = LoginIdentifier.detect(input);
      expect(contact?.kind, 'phone');
      expect(contact?.value, '+2250712345678');
    }
    expect(LoginIdentifier.detect('+14165551234')?.kind, 'phone');
  });
  test('rejects incomplete and ambiguous contacts', () {
    for (final input in [
      '',
      'staff',
      'staff@',
      'staff@.example',
      'staff @school.example',
      '0712345678',
      '002250712345678',
      '+22507',
      '+0250712345678',
      '+22507abc12345',
      '++2250712345678',
      '+1234567890123456',
      '${'a' * 250}@example.com',
    ]) {
      expect(LoginIdentifier.detect(input), isNull);
    }
  });
}
