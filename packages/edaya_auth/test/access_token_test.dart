import 'dart:async';
import 'dart:convert';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String payload() => jsonEncode({
  'accessToken': 'header.payload.signature',
  'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
});

void main() {
  test('serializes renewal and sends signed credential only to auth', () async {
    var calls = 0;
    final client = AuthClient(
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        calls++;
        expect(request.url.path, '/auth/edaya/access-token');
        expect(request.headers['Authorization'], 'Bearer signed.proof');
        expect(request.headers['Cookie'], isNull);
        return http.Response(payload(), 200);
      }),
    );
    client.restoreRenewalCredential('signed.proof');
    final tokens = await Future.wait([
      client.getAccessToken(),
      client.getAccessToken(),
    ]);
    expect(calls, 1);
    expect(tokens.first, tokens.last);
  });

  test('logout cannot be undone by a pending exchange', () async {
    final response = Completer<http.Response>();
    final client = AuthClient(
      baseUrl: 'https://api.example.test',
      client: MockClient((_) => response.future),
    );
    client.restoreRenewalCredential('signed.proof');
    final pending = client.getAccessToken();
    client.clearCredentials();
    response.complete(http.Response(payload(), 200));
    await expectLater(pending, throwsA(isA<AuthError>()));
    expect(client.renewalCredential, isNull);
  });

  test(
    'changing servers never sends the previous renewal credential',
    () async {
      var origin = 'https://first.example.test';
      final client = AuthClient(
        baseUrl: origin,
        baseUrlProvider: () => origin,
        client: MockClient((request) async {
          expect(request.headers['Authorization'], isNull);
          return http.Response('{}', 401);
        }),
      );
      client.restoreRenewalCredential('signed.proof');
      origin = 'https://second.example.test';
      await expectLater(client.getAccessToken(), throwsA(isA<AuthError>()));
      expect(client.renewalCredential, isNull);
    },
  );
}
