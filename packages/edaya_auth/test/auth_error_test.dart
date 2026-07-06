import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeAuthErrorMessage maps wasm abort failures', () {
    expect(
      normalizeAuthErrorMessage('Aborted(). Build with -sASSERTIONS for more info.'),
      contains('bun repo seed'),
    );
  });

  test('normalizeAuthErrorMessage maps credential failures', () {
    expect(
      normalizeAuthErrorMessage('User not found'),
      'Invalid email or password.',
    );
  });
}
