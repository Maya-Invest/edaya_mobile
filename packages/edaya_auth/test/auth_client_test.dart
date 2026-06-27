import 'dart:convert';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('signInWithEmail stores session cookies and returns user', () async {
    final client = AuthClient(
      baseUrl: 'http://localhost:9999',
      client: MockClient((request) async {
        expect(request.url.path, '/auth/sign-in/email');
        expect(jsonDecode(request.body), {
          'email': 'teacher@school.edu',
          'password': 'secret',
        });

        return http.Response(
          jsonEncode({
            'user': {
              'id': 'user-1',
              'email': 'teacher@school.edu',
              'name': 'Teacher',
            },
          }),
          200,
          headers: {'set-cookie': 'better-auth.session_token=abc123; Path=/; HttpOnly'},
        );
      }),
    );

    final result = await client.signInWithEmail(
      email: 'teacher@school.edu',
      password: 'secret',
    );

    expect(result.isSuccess, isTrue);
    expect(result.data?.email, 'teacher@school.edu');
    expect(client.cookieHeader, 'better-auth.session_token=abc123');
  });

  test('getSession returns null when unauthenticated', () async {
    final client = AuthClient(
      baseUrl: 'http://localhost:9999',
      client: MockClient((request) async {
        expect(request.url.path, '/auth/get-session');
        return http.Response('', 401);
      }),
    );

    final result = await client.getSession();
    expect(result.isSuccess, isTrue);
    expect(result.data, isNull);
  });

  test('signOut sends application/json content type', () async {
    final client = AuthClient(
      baseUrl: 'http://localhost:9999',
      client: MockClient((request) async {
        expect(request.url.path, '/auth/sign-out');
        expect(request.headers['origin'], 'http://localhost:9999');
        expect(request.headers['content-type'], 'application/json');
        expect(jsonDecode(request.body), <String, dynamic>{});
        return http.Response('{}', 200);
      }),
    );

    final result = await client.signOut();
    expect(result.isSuccess, isTrue);
    expect(client.cookieHeader, isNull);
  });

  test('sendEmailOtp posts expected payload', () async {
    final client = AuthClient(
      baseUrl: 'http://localhost:9999',
      client: MockClient((request) async {
        expect(request.url.path, '/auth/email-otp/send-verification-otp');
        expect(jsonDecode(request.body), {
          'email': 'parent@school.edu',
          'type': 'sign-in',
        });
        return http.Response('{}', 200);
      }),
    );

    final result = await client.sendEmailOtp(email: 'parent@school.edu');
    expect(result.isSuccess, isTrue);
  });
}
