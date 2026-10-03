@Tags(['staging'])
library;

import 'dart:convert';
import 'dart:io';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  final config = IntegrationConfig.fromEnvironment();
  setUpAll(() {
    if (config.authUrl != 'https://staging.api.edayaplus.com' ||
        config.baseUrl != 'https://staging.api.edayaplus.com' ||
        AuthClient.testOtpAccess ||
        Platform.environment['SEED_AUTH_SESSIONS_FILE'] == null) {
      throw StateError(
        'Staging smoke requires recorded URLs, private fixture sessions and no OTP test access',
      );
    }
  });
  test(
    '[staging.identity.email-only] deployed Identity advertises email-only authentication',
    () async {
      final response = await http.get(
        Uri.parse('${config.authUrl}/auth/edaya/methods'),
      );
      expect(response.statusCode, 200);
      final methods = (jsonDecode(response.body) as Map)['methods'] as List;
      expect(
        methods.any((dynamic method) => method['kind'] == 'email'),
        isTrue,
      );
      expect(
        methods.any(
          (dynamic method) =>
              method['kind'] == 'phone' && method['available'] == true,
        ),
        isFalse,
      );
      expect(
        await AuthClient(baseUrl: config.authUrl).phoneAvailable(),
        isFalse,
      );
    },
  );
  test(
    '[staging.identity.no-test-access] deployed Identity exposes no OTP capture routes',
    () async {
      final response = await http.get(
        Uri.parse('${config.authUrl}/auth/edaya/testing/capabilities'),
      );
      expect(response.statusCode, 404);
    },
  );
  for (final profile in TeacherPortalProfile.demoCiProfiles) {
    test(
      '[staging.teacher.${profile.kind.name}] private session resolves native teacher scope',
      () async {
        final session = await PortalSession.signIn(
          config: config.withTeacherEmail(profile.email),
          actorKind: 'teacher',
          academicYearId: profile.academicYearId,
        );
        final context = await bootstrapTeacherPortal(session, profile);
        expect(context.grants.kind, 'teacher');
        expect(context.grants.schoolId, isNotEmpty);
        expect(context.assignedClassGroups, isNotEmpty);
        expect(
          await session.authClient.getAccessToken(
            resource: Uri.parse(config.baseUrl),
          ),
          isNotEmpty,
        );
      },
    );
  }
  for (final profile in GuardianPortalProfile.demoCiProfiles) {
    test(
      '[staging.guardian.${profile.guardianId}] private session resolves native guardian children',
      () async {
        final session = await PortalSession.signIn(
          config: config.withGuardianEmail(profile.email),
          actorKind: 'guardian',
          academicYearId: profile.academicYearId,
        );
        final context = await bootstrapGuardianPortal(session, profile);
        expect(context.grants.kind, 'guardian');
        expect(
          context.linkedStudents.map((student) => student['id']),
          containsAll(profile.expectedStudentIds),
        );
        expect(
          await session.authClient.getAccessToken(
            resource: Uri.parse(config.baseUrl),
          ),
          isNotEmpty,
        );
      },
    );
  }
}
