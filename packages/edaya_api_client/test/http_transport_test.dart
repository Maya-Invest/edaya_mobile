import 'dart:convert';

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('exchanges and retries using the resolved request origin', () async {
    final requested = <String>[];
    final invalidated = <String>[];
    var attempts = 0;
    final transport = HttpTransport(
      baseUrl: 'https://school.example.test/api',
      client: MockClient((request) async {
        attempts++;
        expect(request.headers['Authorization'], startsWith('Bearer '));
        expect(request.headers['Cookie'], isNull);
        if (attempts == 1) {
          return http.Response('', 401);
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
      getAccessToken: ({required Uri resource}) async {
        requested.add(resource.origin);
        return 'header.${resource.host}.sig';
      },
      invalidateAccessToken: ({required Uri resource, required String token}) {
        invalidated.add('${resource.origin}:$token');
      },
    );

    final result = await transport.request<Map<String, dynamic>>(
      'GET',
      '/core/students',
    );
    expect(result['ok'], true);
    expect(requested, [
      'https://school.example.test',
      'https://school.example.test',
    ]);
    expect(invalidated.single, startsWith('https://school.example.test:'));
    expect(attempts, 2);
  });

  test(
    'private GETs revalidate for each actor and drop stale bytes on denial',
    () async {
      var actor = 'a', round = 0;
      final validators = <String?>[];
      final transport = HttpTransport(
        baseUrl: 'https://school.example.test',
        getActorKind: () => 'staff',
        getActorId: () => actor,
        getSchoolId: () => 'school',
        client: MockClient((request) async {
          validators.add(request.headers['if-none-match']);
          switch (++round) {
            case 2:
              return http.Response('', 304);
            case 3:
              return http.Response('denied', 403);
            default:
              return http.Response(
                jsonEncode({'actor': actor}),
                200,
                headers: {'etag': '"$actor"'},
              );
          }
        }),
      );
      Future<Map<String, dynamic>> read() =>
          transport.request('GET', '/core/directory/students');
      final first = await read();
      first['actor'] = 'local';
      expect((await read())['actor'], 'a');
      await expectLater(read(), throwsA(isA<ApiError>()));
      expect((await read())['actor'], 'a');
      actor = 'b';
      expect((await read())['actor'], 'b');
      expect(validators, [null, '"a"', '"a"', null, null]);
    },
  );

  test('does not retry a denied write', () async {
    var attempts = 0;
    final transport = HttpTransport(
      baseUrl: 'https://school.example.test',
      client: MockClient((request) async {
        attempts++;
        return http.Response('', 401);
      }),
      getAccessToken: ({required Uri resource}) async => 'header.payload.sig',
      invalidateAccessToken:
          ({required Uri resource, required String token}) {},
    );

    await expectLater(
      transport.request<void>(
        'POST',
        '/core/commands/pay',
        options: const TransportRequestOptions(body: {}),
      ),
      throwsA(isA<ApiError>()),
    );
    expect(attempts, 1);
  });
}
