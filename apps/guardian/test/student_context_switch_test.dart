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
  final user = LxVar<AuthUser?>(null);
  @override
  final grants = LxVar<api.EffectiveGrantsResponse?>(null);
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
  final slow = Completer<List<Map<String, dynamic>>>();
  bool failClass = false;
  bool failYears = false;
  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    final body = options?.body as Map? ?? {};
    if (path.endsWith('/academic-years/list')) {
      if (failYears) throw api.ApiError(503, path);
      return <Map<String, dynamic>>[
            {'id': 'current', 'startDate': '2026-01-01', 'status': 'published'},
            {'id': 'old', 'startDate': '2025-01-01', 'status': 'archived'},
          ]
          as T;
    }
    if (path.endsWith('/enrollments/list')) {
      if (body['studentId'] == 'slow' && body['academicYearId'] == null)
        return await slow.future as T;
      if (body['studentId'] == 'empty') return <Map<String, dynamic>>[] as T;
      return [
                {
                  'studentId': body['studentId'],
                  'academicYearId': 'old',
                  'classGroupId': 'class',
                  'status': 'closed',
                  'enrollmentIndex': 1,
                },
                if (body['academicYearId'] == null ||
                    body['academicYearId'] == 'current')
                  {
                    'studentId': body['studentId'],
                    'academicYearId': 'current',
                    'classGroupId': 'class',
                    'status': 'active',
                    'enrollmentIndex': 2,
                  },
              ]
              .where(
                (r) =>
                    body['academicYearId'] == null ||
                    r['academicYearId'] == body['academicYearId'],
              )
              .toList()
          as T;
    }
    if (path.contains('/students/'))
      return {
            'id': path.split('/').last,
            'firstName': 'Child',
            'lastName': 'Name',
            'schoolId': 'school',
          }
          as T;
    if (path.contains('/class-groups/')) {
      if (failClass) throw api.ApiError(403, path);
      return {'id': 'class', 'name': 'Class'} as T;
    }
    if (path.contains('/schools/'))
      return {'id': 'school', 'name': 'School'} as T;
    throw StateError(path);
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
      transport.slow.complete([
        {'studentId': 'slow', 'academicYearId': 'current'},
      ]);
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
