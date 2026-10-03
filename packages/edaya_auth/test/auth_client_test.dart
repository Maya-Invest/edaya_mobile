import 'dart:convert';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'OTP delivery reports network failure without creating a challenge',
    () async {
      final client = AuthClient(
        baseUrl: 'http://localhost:9999',
        client: MockClient((_) async {
          throw http.ClientException('offline');
        }),
      );
      final result = await client.sendOtp(value: 'person@example.com');
      expect(result.isSuccess, isFalse);
      expect(result.error?.code, 'NETWORK_ERROR');
      expect(client.pendingChallenge, isNull);
      expect(client.renewalCredential, isNull);
    },
  );
  test(
    'signInWithEmailOtp stores opaque Account renewal credentials and returns user',
    () async {
      final client = AuthClient(
        baseUrl: 'http://localhost:9999',
        client: MockClient((request) async {
          expect(request.url.path, '/auth/edaya/otp/verify');
          expect(jsonDecode(request.body), {
            'challenge': 'primary-challenge',
            'code': '246810',
          });

          return http.Response(
            jsonEncode({
              'state': 'complete',
              'token': 'opaque-synthetic-proof',
              'user': {
                'id': 'user-1',
                'email': 'teacher@school.edu',
                'name': 'Teacher',
              },
            }),
            200,
            headers: {'set-cookie': 'edaya_session=abc123; Path=/; HttpOnly'},
          );
        }),
      );

      client.pendingChallenge = 'primary-challenge';
      final result = await client.signInWithEmailOtp(
        email: 'teacher@school.edu',
        otp: '246810',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.email, 'teacher@school.edu');
      expect(client.cookieHeader, isNull);
      expect(client.renewalCredential, 'opaque-synthetic-proof');
    },
  );

  test('normal builds perform no testing requests', () async {
    var requests = 0;
    final client = AuthClient(
      baseUrl: 'http://localhost:9999',
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 404);
      }),
    );
    if (!AuthClient.testOtpAccess) {
      expect(await client.testingOtpAvailable(), isFalse);
      expect(await client.revealTestOtp('challenge'), isNull);
      expect(requests, 0);
    }
  });

  test('getSession returns null when unauthenticated', () async {
    final client = AuthClient(
      baseUrl: 'http://localhost:9999',
      client: MockClient((request) async {
        expect(request.url.path, '/auth/edaya/session');
        return http.Response('', 401);
      }),
    );

    final result = await client.getSession();
    expect(result.isSuccess, isTrue);
    expect(result.data, isNull);
  });

  test(
    'lost resend recovery keeps its ID after a superseded status response',
    () async {
      final ids = <String>[];
      var calls = 0;
      final client = AuthClient(
        baseUrl: 'http://localhost:9999',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/status')) {
            return http.Response(
              jsonEncode({
                'challenge': 'old',
                'lifecycle': 'superseded',
                'actions': {'resend': false, 'sms': false},
              }),
              200,
            );
          }
          final payload = jsonDecode(request.body) as Map;
          expect(payload['challenge'], 'old');
          expect(payload['action'], 'sms');
          ids.add(payload['requestId'] as String);
          if (++calls == 1) {
            return http.Response(
              jsonEncode({'code': 'authentication_unavailable'}),
              503,
            );
          }
          return http.Response(
            jsonEncode({
              'challenge': 'new',
              'channel': 'sms',
              'delivery': 'accepted',
            }),
            200,
          );
        }),
      );
      client.pendingChallenge = 'old';
      client.pendingStep = 'primary_required';
      expect((await client.resendOtp(action: 'sms')).isSuccess, isFalse);
      await client.otpStatus();
      expect(client.primaryStatus!.canResend, isFalse);
      expect(client.canRetryOtpRequest, isTrue);
      expect((await client.retryOtpRequest()).isSuccess, isTrue);
      expect(client.pendingChallenge, 'new');
      expect(ids.toSet().length, 1);
      expect(client.canRetryOtpRequest, isFalse);
    },
  );

  test('signOut sends application/json content type', () async {
    final client = AuthClient(
      baseUrl: 'http://localhost:9999',
      client: MockClient((request) async {
        expect(request.url.path, '/auth/edaya/sign-out');
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
        expect(request.url.path, '/auth/edaya/otp/start');
        final payload = jsonDecode(request.body) as Map;
        expect(payload['kind'], 'email');
        expect(payload['value'], 'parent@school.edu');
        expect(payload['locale'], 'fr');
        expect(payload['requestId'], matches(RegExp(r'^[a-f0-9-]{36}$')));
        expect(payload.containsKey('channel'), isFalse);
        return http.Response(jsonEncode({'challenge': 'primary'}), 200);
      }),
    );

    final result = await client.sendEmailOtp(email: 'parent@school.edu');
    expect(result.isSuccess, isTrue);
  });

  test(
    'phone sends preserve request IDs on a lost response, then expose delivery and cooldown',
    () async {
      final requests = <Map>[];
      var calls = 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final client = AuthClient(
        baseUrl: 'http://localhost:9999',
        client: MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map);
          if (++calls == 1) throw http.ClientException('lost response');
          return http.Response(
            jsonEncode({
              'state': 'primary_required',
              'challenge': 'phone-proof',
              'channel': 'whatsapp',
              'delivery': 'uncertain',
              'lifecycle': 'pending',
              'expiresAt': now + 300000,
              'nextResendAt': now + 60000,
              'serverNow': now,
              'actions': {'resend': true, 'sms': true},
            }),
            200,
          );
        }),
      );
      expect(
        (await client.sendOtp(
          value: '+2250712345678',
          channel: 'phone',
        )).isSuccess,
        isFalse,
      );
      expect(
        (await client.sendOtp(
          value: '+2250712345678',
          channel: 'phone',
        )).isSuccess,
        isTrue,
      );
      expect(requests[0]['requestId'], requests[1]['requestId']);
      expect(requests[0].containsKey('channel'), isFalse);
      expect(client.primaryStatus!.delivery, 'uncertain');
      expect(client.primaryStatus!.canSms, isTrue);
      expect(client.primaryStatus!.secondsRemaining, greaterThan(55));
      expect(client.renewalCredential, isNull);
      client.clearCredentials();
      expect(client.primaryStatus, isNull);
    },
  );

  test(
    'resend and SMS send only the retained challenge and a new request ID',
    () async {
      final requests = <Map>[];
      final client = AuthClient(
        baseUrl: 'http://localhost:9999',
        client: MockClient((request) async {
          expect(request.url.path, '/auth/edaya/otp/resend');
          final payload = jsonDecode(request.body) as Map;
          requests.add(payload);
          return http.Response(
            jsonEncode({
              'challenge': 'replacement',
              'channel': 'sms',
              'delivery': 'accepted',
              'actions': {'resend': true, 'sms': false},
            }),
            200,
          );
        }),
      );
      client.pendingChallenge = 'original';
      expect((await client.resendOtp(action: 'sms')).isSuccess, isTrue);
      expect(requests.first['challenge'], 'original');
      expect(requests.first['action'], 'sms');
      expect(requests.first.containsKey('value'), isFalse);
      expect(client.primaryStatus!.channel, 'sms');
      expect(client.primaryStatus!.canSms, isFalse);
      await client.resendOtp();
      expect(requests.last['challenge'], 'replacement');
      expect(requests.last['requestId'], isNot(requests.first['requestId']));
    },
  );

  test(
    'status uses a POST body and cannot replace a newer challenge',
    () async {
      late AuthClient client;
      client = AuthClient(
        baseUrl: 'http://localhost:9999',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/auth/edaya/otp/status');
          expect(request.url.query, isEmpty);
          expect(jsonDecode(request.body), {'challenge': 'original'});
          client.pendingChallenge = 'newer';
          return http.Response(
            jsonEncode({'challenge': 'original', 'delivery': 'delivered'}),
            200,
          );
        }),
      );
      client.pendingChallenge = 'original';
      client.pendingStep = 'primary_required';
      await client.otpStatus();
      expect(client.pendingChallenge, 'newer');
      expect(client.primaryStatus, isNull);
    },
  );

  test(
    'baseUrlProvider switches request origin without rebuilding client',
    () async {
      var baseUrl = 'http://localhost:9999';
      final requestedHosts = <String>[];
      final origins = <String?>[];
      final client = AuthClient(
        baseUrl: baseUrl,
        baseUrlProvider: () => baseUrl,
        client: MockClient((request) async {
          requestedHosts.add(request.url.origin);
          origins.add(request.headers['origin']);
          return http.Response('', 401);
        }),
      );

      await client.getSession();
      baseUrl = 'http://10.0.2.2:9999';
      await client.getSession();

      expect(requestedHosts, ['http://localhost:9999', 'http://10.0.2.2:9999']);
      expect(origins, requestedHosts);
    },
  );
}
