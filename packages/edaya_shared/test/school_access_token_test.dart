import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native school clients require a renewal credential', () {
    final client = AuthClient(baseUrl: 'http://localhost:9900');
    expect(canIssueSchoolAccessToken(client), isFalse);
    client.restoreRenewalCredential('signed.proof');
    expect(canIssueSchoolAccessToken(client), isTrue);
  });
}
