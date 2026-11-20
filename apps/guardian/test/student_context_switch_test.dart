import 'dart:async';
import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_guardian_v2/features/auth/session_storage.dart';
import 'package:edaya_guardian_v2/features/context/academic_year_controller.dart';
import 'package:edaya_guardian_v2/features/context/student_context_controller.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Session implements AppSessionController {
  @override
  final user = LxVar<AuthUser?>(
    AuthUser(id: 'account', email: 'guardian@example.test'),
  );
  @override
  final grants = LxVar<api.EffectiveGrantsResponse?>(
    const api.EffectiveGrantsResponse(
      kind: 'guardian',
      actorId: 'guardian',
      schoolId: 'school',
      assuranceLevel: 'standard',
      grants: [],
    ),
  );
  @override
  bool get isAuthenticated => true;
  @override
  bool get hasSchoolSession => true;
  @override
  String get schoolIdHeader => 'school';
  @override
  String get actorIdHeader => 'guardian';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Transport implements api.Transport {
  final slow = Completer<void>();
  bool failClass = false;
  bool failYears = false;
  int reads = 0;
  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    if (method != 'GET' || !path.endsWith('/guardian/child-choices')) {
      throw StateError(path);
    }
    if (++reads == 1) await slow.future;
    if (failYears || failClass) throw api.ApiError(failYears ? 503 : 403, path);
    return {
          'guardianId': 'guardian',
          'school': {
            'id': 'school',
            'name': 'School',
            'timeZone': 'Africa/Abidjan',
          },
          'children': [
            for (final id in ['slow', 'fast', 'empty'])
              {
                'id': id,
                'firstName': 'Child',
                'lastName': id,
                'schoolId': 'school',
              },
          ],
          'years': [
            {
              'id': 'current',
              'schoolId': 'school',
              'startDate': '2026-01-01',
              'status': 'published',
            },
            {
              'id': 'old',
              'schoolId': 'school',
              'startDate': '2025-01-01',
              'status': 'archived',
            },
          ],
          'enrollments': [
            for (final child in ['fast', 'slow'])
              for (final year in ['current', 'old'])
                {
                  'studentId': child,
                  'academicYearId': year,
                  'classGroupId': 'class',
                  'classLabel': 'Class',
                  'enrollmentIndex': year == 'current' ? 2 : 1,
                  'status': year == 'current' ? 'active' : 'closed',
                },
          ],
        }
        as T;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'complete enrollment context wins a race, retains explicit history and clears failed switches',
    () async {
      SharedPreferences.setMockInitialValues({});
      final session = _Session();
      final transport = _Transport();
      final client = api.createSchoolClient(transport);
      final storage = SessionStorage();
      final years = AcademicYearController(
        sessionStorage: storage,
        session: session,
        schoolClient: () => client,
      );
      years.onInit();
      years.years([
        {'id': 'current', 'startDate': '2026-01-01', 'status': 'published'},
        {'id': 'old', 'startDate': '2025-01-01', 'status': 'archived'},
      ]);
      final pupil = StudentContextController(
        sessionStorage: storage,
        session: session,
        academicYear: years,
        schoolClient: () => client,
      );
      pupil.onInit();
      addTearDown(() {
        pupil.onClose();
        years.onClose();
      });
      pupil.linkedStudentIds(['slow', 'fast', 'empty']);
      final slow = pupil.selectStudent('slow');
      await pupil.selectStudent('fast', yearId: 'old');
      expect(pupil.activeStudentId, 'fast');
      expect(pupil.activeYearId, 'old');
      expect(pupil.isEnrolled.value, true);
      expect(transport.reads, 2);
      expect(pupil.schoolTimeZone.value, 'Africa/Abidjan');
      transport.slow.complete();
      await slow;
      expect(pupil.activeStudentId, 'fast');
      expect(pupil.activeYearId, 'old');
      await expectLater(
        pupil.selectEnrollmentYear('unauthorized-year'),
        throwsStateError,
      );
      expect(pupil.activeStudentId, isNull);
      expect(pupil.errorMessage.value, isNotEmpty);
      await pupil.selectStudent('empty');
      expect(pupil.activeStudentId, 'empty');
      expect(pupil.activeYearId, isNull);
      expect(pupil.isEnrolled.value, false);
      await pupil.selectStudent('fast');
      expect(pupil.activeYearId, 'current');
      years.years([]);
      transport.failYears = true;
      await pupil.selectStudent('fast');
      expect(pupil.activeStudentId, isNull);
      expect(pupil.errorMessage.value, isNotEmpty);
      expect(pupil.isLoading.value, isFalse);
      transport.failYears = false;
      await pupil.selectStudent('fast');
      expect(pupil.activeStudentId, 'fast');
      expect(pupil.activeYearId, 'current');
      expect(pupil.isEnrolled.value, true);
      transport.failClass = true;
      await pupil.selectStudent('fast', yearId: 'old');
      expect(pupil.activeStudentId, isNull);
      expect(pupil.errorMessage.value, isNotEmpty);
    },
  );
}
