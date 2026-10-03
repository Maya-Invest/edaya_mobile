import 'dart:async';
import 'dart:convert';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final school = Uri.parse('https://school.example.test');
final children = Uri.parse('https://children.example.test');

String payload(String token) => jsonEncode({
  'accessToken': token,
  'tokenType': 'Bearer',
  'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
});

void main() {
  test('serializes renewal and sends the requested resource origin', () async {
    var calls = 0;
    final client = AuthClient(
      baseUrl: 'https://identity.example.test',
      client: MockClient((request) async {
        calls++;
        expect(request.url.path, '/auth/edaya/access-token');
        expect(request.headers['Authorization'], 'Bearer signed.proof');
        expect(request.headers['Cookie'], isNull);
        expect(jsonDecode(request.body)['resource'], school.origin);
        return http.Response(payload('header.school.signature'), 200);
      }),
    );
    client.restoreRenewalCredential('signed.proof');
    final tokens = await Future.wait([
      client.getAccessToken(resource: school),
      client.getAccessToken(resource: school),
    ]);
    expect(calls, 1);
    expect(tokens.first, tokens.last);
  });

  test('issues distinct origins concurrently', () async {
    final client = AuthClient(
      baseUrl: 'https://identity.example.test',
      client: MockClient((request) async {
        final resource = jsonDecode(request.body)['resource'] as String;
        return http.Response(
          payload(
            resource.contains('school')
                ? 'header.school.signature'
                : 'header.children.signature',
          ),
          200,
        );
      }),
    );
    client.restoreRenewalCredential('signed.proof');
    final tokens = await Future.wait([
      client.getAccessToken(resource: school),
      client.getAccessToken(resource: children),
    ]);
    expect(tokens.toSet(), hasLength(2));
  });

  test('keeps distinct tokens for distinct API origins', () async {
    final client = AuthClient(
      baseUrl: 'https://identity.example.test',
      client: MockClient((request) async {
        final resource = jsonDecode(request.body)['resource'] as String;
        return http.Response(
          payload(
            resource.contains('school')
                ? 'header.school.signature'
                : 'header.children.signature',
          ),
          200,
        );
      }),
    );
    client.restoreRenewalCredential('signed.proof');
    final schoolToken = await client.getAccessToken(resource: school);
    final childrenToken = await client.getAccessToken(resource: children);
    expect(schoolToken, isNot(childrenToken));
    client.invalidateAccessToken(resource: school, token: schoolToken);
    expect(await client.getAccessToken(resource: children), childrenToken);
  });

  test('rejects an invalid resource before contacting identity', () async {
    var calls = 0;
    final client = AuthClient(
      baseUrl: 'https://identity.example.test',
      client: MockClient((_) async {
        calls++;
        return http.Response(payload('header.payload.signature'), 200);
      }),
    );
    client.restoreRenewalCredential('signed.proof');
    await expectLater(
      client.getAccessToken(
        resource: Uri.parse('https://school.example.test/v1'),
      ),
      throwsA(isA<AuthError>()),
    );
    expect(calls, 0);
  });

  test('logout cannot be undone by a pending exchange', () async {
    final response = Completer<http.Response>();
    final client = AuthClient(
      baseUrl: 'https://identity.example.test',
      client: MockClient((_) => response.future),
    );
    client.restoreRenewalCredential('signed.proof');
    final pending = client.getAccessToken(resource: school);
    client.clearCredentials();
    response.complete(http.Response(payload('header.payload.signature'), 200));
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
      await expectLater(
        client.getAccessToken(resource: school),
        throwsA(isA<AuthError>()),
      );
      expect(client.renewalCredential, isNull);
    },
  );
}
