import 'dart:convert';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'terms endpoint uses requested locale and fails closed for malformed responses',
    () async {
      var broken = false;
      final client = AuthClient(
        baseUrl: 'http://localhost:9999',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/auth/edaya/terms');
          expect(request.url.queryParameters['locale'], 'en');
          return http.Response(
            broken
                ? '{"enforced":true,"document":null}'
                : '{"enforced":false,"document":null}',
            200,
          );
        }),
      );
      expect((await client.getTerms(locale: 'en')).data?.enforced, isFalse);
      broken = true;
      expect(
        (await client.getTerms(locale: 'en')).error?.code,
        'terms_unavailable',
      );
    },
  );
  test('OTP-start retries preserve acceptance and request identity', () async {
    final payloads = <Object>[];
    final client = AuthClient(
      baseUrl: 'http://localhost:9999',
      client: MockClient((request) async {
        payloads.add(jsonDecode(request.body) as Object);
        return http.Response('{"code":"unavailable"}', 503);
      }),
    );
    await client.sendOtp(
      value: 'person@example.com',
      termsAcceptance: const AuthTermsAcceptance(
        version: 'v1',
        locale: 'en',
        accepted: true,
      ),
    );
    await client.retryOtpRequest();
    expect(payloads, hasLength(2));
    expect(payloads[1], payloads[0]);
    expect((payloads[0] as Map)['termsAcceptance'], {
      'version': 'v1',
      'locale': 'en',
      'accepted': true,
    });
  });
}
