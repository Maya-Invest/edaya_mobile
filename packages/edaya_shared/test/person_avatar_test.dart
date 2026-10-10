import 'dart:convert';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhotoAuth extends AuthClient {
  PhotoAuth(http.Client client)
    : super(baseUrl: ApiBaseUrlConfig.baseUrl, client: client);
  int tokenRequests = 0;
  @override
  Future<String> getAccessToken({required Uri resource}) async {
    expect(resource.origin, 'http://10.0.2.2:9999');
    return 'fixture-token-${++tokenRequests}';
  }
}

class PhotoGrantTransport implements api.Transport {
  PhotoGrantTransport({this.denied = false, this.external = false});
  final bool external;
  final bool denied;
  final paths = <String>[];

  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    expect(method, 'GET');
    paths.add(path);
    if (denied) throw api.ApiError(403, {});
    return <String, dynamic>{
          'downloadUrl': external
              ? 'https://files.example/portrait?signature=fixture'
              : 'http://localhost:9999/core/files/memory/portrait?signature=fixture',
        }
        as T;
  }
}

void main() {
  for (final scenario in ['local', 'external', 'denied', 'expired']) {
    final denied = scenario == 'denied';
    final external = scenario == 'external';
    final expired = scenario == 'expired';
    testWidgets(
      denied
          ? 'denied portrait remains initials without fetching private bytes'
          : 'portrait loads through $scenario storage with scoped credentials',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await ApiBaseUrlConfig.saveOverride('http://10.0.2.2:9999');
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
        final transport = PhotoGrantTransport(
          denied: denied,
          external: external,
        );
        final downloads = <http.Request>[];
        final auth = PhotoAuth(
          MockClient((request) async {
            downloads.add(request);
            if (expired && downloads.length == 1) return http.Response('', 401);
            return http.Response.bytes(
              base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
              ),
              200,
            );
          }),
        );
        await tester.pumpWidget(
          LScope(
            name: 'portrait-$scenario',
            dependencyFactory: (scope) {
              scope.put<AuthClient>(() => auth);
              scope.put<SchoolClientFactory>(
                () =>
                    () => api.createSchoolClient(transport),
              );
            },
            child: const MaterialApp(
              home: Scaffold(
                body: PersonAvatar(
                  name: 'Test child',
                  initials: 'TC',
                  photoUrl: '/core/files/pending-photo/content',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(transport.paths, ['/core/files/pending-photo/download-url']);
        final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
        if (denied) {
          expect(downloads, isEmpty);
          expect(avatar.backgroundImage, isNull);
          expect(find.text('TC'), findsOneWidget);
        } else {
          expect(downloads, hasLength(expired ? 2 : 1));
          expect(
            downloads.last.url.host,
            external ? 'files.example' : '10.0.2.2',
          );
          expect(downloads.last.url.query, 'signature=fixture');
          expect(
            downloads.last.headers['authorization'],
            external ? isNull : 'Bearer fixture-token-${expired ? 2 : 1}',
          );
          expect(auth.tokenRequests, external ? 0 : (expired ? 2 : 1));
          expect(avatar.backgroundImage, isA<MemoryImage>());
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await ApiBaseUrlConfig.clearOverride();
      },
    );
  }
}
