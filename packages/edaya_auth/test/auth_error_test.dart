import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeAuthErrorMessage maps wasm abort failures', () {
    expect(
      normalizeAuthErrorMessage(
        'Aborted(). Build with -sASSERTIONS for more info.',
      ),
      contains('bun repo seed'),
    );
  });

  test('normalizeAuthErrorMessage maps OTP failures', () {
    expect(
      normalizeAuthErrorMessage('INVALID_OTP'),
      'Invalid or expired verification code.',
    );
  });
}
