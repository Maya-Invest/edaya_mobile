import 'dart:convert';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoPush implements PushNotificationService {
  @override
  Future<void> registerForAuthenticatedUser() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final automatic in [false, true]) {
    test('automatic school selection is opt-in: $automatic', () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/authorization/profiles')) {
          return http.Response(
            jsonEncode({
              'profiles': [
                for (final school in ['Zulu', 'Alpha'])
                  {
                    'kind': 'teacher',
                    'actorId': 'teacher-$school',
                    'schoolId': school,
                    'schoolName': school,
                  },
              ],
            }),
            200,
          );
        }
        final school = request.headers['x-school-id'];
        return http.Response(
          jsonEncode({
            'kind': 'teacher',
            'actorId': 'teacher-$school',
            'schoolId': school,
            'assuranceLevel': 'verified',
            'grants': [],
          }),
          200,
        );
      });
      final session = AppSessionController(
        authClient: AuthClient(baseUrl: 'http://localhost', client: client),
        sessionStorage: AuthSessionStorage(),
        pushNotifications: _NoPush(),
        routerRefresh: EdayaRouterRefresh(),
        validateGrants: (_) => null,
        unauthorizedProfileMessage: () => 'Denied',
        resolveActorKind: () => 'teacher',
        selectFirstProfile: automatic,
      );
      session.user(
        const AuthUser(id: 'account', email: 'teacher@example.test'),
      );
      expect(await session.refreshGrants(), isNull);
      expect(session.needsProfileSelection, !automatic);
      expect(session.schoolIdHeader, automatic ? 'Alpha' : null);
    });
  }

  test(
    'selecting either school resolves grants after a multi-profile login',
    () async {
      SharedPreferences.setMockInitialValues({});
      final grantSchools = <String>[];
      final profiles = [
        for (final school in ['north', 'south'])
          SchoolAuthorizationProfile(
            kind: 'teacher',
            actorId: 'teacher-$school',
            schoolId: school,
            schoolName: school,
            schoolShortName: school,
          ),
      ];
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/authorization/profiles')) {
          return http.Response(
            jsonEncode({
              'profiles': [
                for (final profile in profiles)
                  {
                    'kind': profile.kind,
                    'actorId': profile.actorId,
                    'schoolId': profile.schoolId,
                    'schoolName': profile.schoolName,
                    'schoolShortName': profile.schoolShortName,
                  },
              ],
            }),
            200,
          );
        }
        final school = request.headers['x-school-id']!;
        grantSchools.add(school);
        return http.Response(
          jsonEncode({
            'kind': 'teacher',
            'actorId': 'teacher-$school',
            'schoolId': school,
            'assuranceLevel': 'verified',
            'grants': [],
          }),
          200,
        );
      });
      final session = AppSessionController(
        authClient: AuthClient(baseUrl: 'http://localhost', client: client),
        sessionStorage: AuthSessionStorage(),
        pushNotifications: _NoPush(),
        routerRefresh: EdayaRouterRefresh(),
        validateGrants: (_) => null,
        unauthorizedProfileMessage: () => 'Denied',
        resolveActorKind: () => 'teacher',
      );
      session.user(
        const AuthUser(id: 'account', email: 'teacher@example.test'),
      );
      session.availableProfiles(profiles);
      expect(session.needsProfileSelection, isTrue);
      for (final profile in profiles) {
        expect(await session.selectProfile(profile), isNull);
        expect(session.needsProfileSelection, isFalse);
        expect(session.schoolIdHeader, profile.schoolId);
        expect(session.actorIdHeader, profile.actorId);
      }
      expect(grantSchools, ['north', 'south']);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'edaya_selected_school_id',
        ),
        'south',
      );
    },
  );
}
