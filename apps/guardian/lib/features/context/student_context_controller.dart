import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import '../../common/utils/entity_query.dart';
import '../auth/app_session_controller.dart';
import '../auth/session_storage.dart';
import '../my_students/linked_student.dart';
import 'academic_year_controller.dart';

class StudentContextController extends LevitController
    with LevitReactiveTasksMixin {
  StudentContextController({
    required SessionStorage sessionStorage,
    required AppSessionController session,
    required AcademicYearController academicYear,
  }) : _sessionStorage = sessionStorage,
       _session = session,
       _academicYear = academicYear;

  final SessionStorage _sessionStorage;
  final AppSessionController _session;
  final AcademicYearController _academicYear;

  final activeStudent = LxVar<LinkedStudent?>(null);
  final classGroupId = LxVar<String?>(null);
  final classLabel = LxVar<String?>(null);
  final isEnrolled = LxVar(false);
  final isLoading = LxVar(false);
  final errorMessage = LxVar('');

  Future<void>? _pendingReload;

  String? get activeStudentId => activeStudent.value?.id;

  @override
  void onInit() {
    super.onInit();
    autoDispose(activeStudent);
    autoDispose(classGroupId);
    autoDispose(classLabel);
    autoDispose(isEnrolled);
    autoDispose(isLoading);
    autoDispose(errorMessage);

    autoDispose(
      _academicYear.selectedYearId.stream.listen((_) {
        unawaited(reloadContext());
      }),
    );
  }

  Future<void> initializeFromSession() async {
    if (!_session.isAuthenticated) {
      return;
    }

    final grants = _session.grants.value;
    if (grants == null) {
      return;
    }

    final scopedStudentIds = studentIdsFromScopeGrants(
      grants.effectiveGrants.scopeGrants,
    );
    if (scopedStudentIds.isEmpty) {
      return;
    }

    final persistedId = await _sessionStorage.readActiveStudentId();
    if (persistedId != null && scopedStudentIds.contains(persistedId)) {
      await selectStudent(persistedId);
      return;
    }

    if (scopedStudentIds.length == 1) {
      await selectStudent(scopedStudentIds.first);
    }
  }

  Future<void> selectStudent(String studentId) async {
    await _sessionStorage.writeActiveStudentId(studentId);
    if (_academicYear.selectedYearId.value == null) {
      await _academicYear.loadYears();
    }
    await reloadContext();
  }

  Future<void> clearStudent() async {
    await _sessionStorage.writeActiveStudentId(null);
    activeStudent(null);
    classGroupId(null);
    classLabel(null);
    isEnrolled(false);
    errorMessage('');
  }

  Future<void> reloadContext() {
    _pendingReload ??= _reloadContext().whenComplete(() {
      _pendingReload = null;
    });
    return _pendingReload!;
  }

  Future<void> _reloadContext() async {
    final studentId = await _sessionStorage.readActiveStudentId();
    if (studentId == null) {
      activeStudent(null);
      classGroupId(null);
      classLabel(null);
      isEnrolled(false);
      return;
    }

    final yearId = _academicYear.selectedYearId.value;
    errorMessage('');

    await runTask(() async {
      isLoading(true);
      try {
        final schoolClient = AppRuntime.schoolClient();
        final studentJson = await schoolClient.students.get(studentId);
        activeStudent(LinkedStudent.fromJson(studentJson));

        if (yearId == null) {
          classGroupId(null);
          classLabel(null);
          isEnrolled(false);
          return;
        }

        await _loadEnrollment(
          schoolClient: schoolClient,
          studentId: studentId,
          yearId: yearId,
        );
      } on api.ApiError catch (error) {
        errorMessage('Could not load student context: $error');
        activeStudent(null);
        classGroupId(null);
        classLabel(null);
        isEnrolled(false);
      } on Object catch (error) {
        errorMessage('Could not load student context: $error');
        activeStudent(null);
        classGroupId(null);
        classLabel(null);
        isEnrolled(false);
      } finally {
        isLoading(false);
      }
    });
  }

  Future<void> _loadEnrollment({
    required api.SchoolClient schoolClient,
    required String studentId,
    required String yearId,
  }) async {
    try {
      final enrollments = await schoolClient.enrollments.list({
        'studentId': studentId,
        'academicYearId': yearId,
        'status': 'active',
      });

      if (enrollments.isEmpty) {
        classGroupId(null);
        classLabel(null);
        isEnrolled(false);
        return;
      }

      final enrollment = enrollments.first;
      final enrollmentClassGroupId = enrollment['classGroupId'] as String?;
      if (enrollmentClassGroupId == null) {
        classGroupId(null);
        classLabel(null);
        isEnrolled(false);
        return;
      }

      classGroupId(enrollmentClassGroupId);
      final classGroup = await schoolClient.classGroups.get(
        enrollmentClassGroupId,
      );
      final className = classGroup['name'] as String? ?? enrollmentClassGroupId;
      final level = classGroup['level'] as String?;
      classLabel(level == null ? className : '$className · $level');
      isEnrolled(true);
    } on api.ApiError catch (error) {
      errorMessage('Could not load enrollment: $error');
      classGroupId(null);
      classLabel(null);
      isEnrolled(false);
    } on Object catch (error) {
      errorMessage('Could not load enrollment: $error');
      classGroupId(null);
      classLabel(null);
      isEnrolled(false);
    }
  }
}
