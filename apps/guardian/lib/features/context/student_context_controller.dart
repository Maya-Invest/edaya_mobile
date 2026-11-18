import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../auth/session_storage.dart';
import '../my_students/linked_student.dart';
import 'academic_year_controller.dart';
import 'pupil_enrollment_years.dart';

class StudentContextController extends LevitController
    with LevitReactiveTasksMixin {
  StudentContextController({
    required SessionStorage sessionStorage,
    required AppSessionController session,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
    SchoolClientFactory? catalogClient,
  }) : _sessionStorage = sessionStorage,
       _session = session,
       _academicYear = academicYear,
       _schoolClient = schoolClient,
       _catalogClient = catalogClient ?? schoolClient;

  final SessionStorage _sessionStorage;
  final AppSessionController _session;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient, _catalogClient;
  final enrollmentYears = LxVar<List<Map<String, dynamic>>>(const []);

  final linkedStudentIds = LxVar<List<String>>(const []);
  final linkedStudentsResolved = LxVar(false);
  final activeStudent = LxVar<LinkedStudent?>(null);
  final classGroupId = LxVar<String?>(null);
  final classLabel = LxVar<String?>(null);
  final schoolName = LxVar<String?>(null);
  final isEnrolled = LxVar(false);
  final isLoading = LxVar(false);
  final errorMessage = LxVar('');

  int _reloadGeneration = 0;
  int _initializeGeneration = 0;
  bool _switching = false;
  int _selectionGeneration = 0;

  void beginSwitch() {
    _selectionGeneration++;
    _switching = true;
    _initializeGeneration++;
    _clearContext();
    linkedStudentsResolved(false);
  }

  String? get activeYearId => _academicYear.selectedYearId.value;

  String? get activeStudentId => activeStudent.value?.id;

  bool get hasLinkedStudents => linkedStudentIds.value.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    autoDispose(enrollmentYears);
    autoDispose(linkedStudentIds);
    autoDispose(linkedStudentsResolved);
    autoDispose(activeStudent);
    autoDispose(classGroupId);
    autoDispose(classLabel);
    autoDispose(schoolName);
    autoDispose(isEnrolled);
    autoDispose(isLoading);
    autoDispose(errorMessage);

    autoDispose(
      _academicYear.selectedYearId.stream.listen((_) {
        if (!_switching) unawaited(reloadContext());
      }),
    );
    autoDispose(
      _session.grants.stream.listen((grants) {
        if (grants == null || grants.kind != 'guardian') {
          linkedStudentIds(const []);
          // A new sign-in must resolve its relationships before routing to
          // the no-children page, including after a second-factor sign-in.
          linkedStudentsResolved(false);
          _clearContext();
        }
      }),
    );
  }

  Future<void> initializeFromSession({
    String? preferredStudentId,
    String? preferredYearId,
  }) async {
    final initialization = ++_initializeGeneration;
    final account = _session.user.value?.id;
    final school = _session.schoolIdHeader;
    final actor = _session.actorIdHeader;
    bool valid() =>
        !isClosed &&
        initialization == _initializeGeneration &&
        account == _session.user.value?.id &&
        school == _session.schoolIdHeader &&
        actor == _session.actorIdHeader;
    if (!_session.isAuthenticated) {
      linkedStudentIds(const []);
      linkedStudentsResolved(true);
      return;
    }

    final grants = _session.grants.value;
    if (grants == null || grants.kind != 'guardian') {
      linkedStudentIds(const []);
      linkedStudentsResolved(true);
      return;
    }

    final scopedStudentIds = await loadGuardianLinkedStudentIds(
      _schoolClient(),
      grants.actorId,
    );
    if (!valid()) return;
    linkedStudentIds(scopedStudentIds);
    if (scopedStudentIds.isEmpty) {
      await _sessionStorage.writeActiveStudentId(null);
      _clearContext();
      _switching = false;
      linkedStudentsResolved(true);
      return;
    }

    final persistedId =
        preferredStudentId ?? await _sessionStorage.readActiveStudentId();
    if (!valid()) return;
    await selectStudent(
      persistedId != null && scopedStudentIds.contains(persistedId)
          ? persistedId
          : scopedStudentIds.first,
      yearId: preferredYearId,
    );
    if (!valid()) return;
    _switching = false;
    linkedStudentsResolved(true);
  }

  Future<void> selectStudent(String studentId, {String? yearId}) async {
    if (!linkedStudentIds.value.contains(studentId)) return;
    final selection = ++_selectionGeneration;
    _switching = true;
    _clearContext();
    isLoading(true);
    final generation = _reloadGeneration;
    final school = _session.schoolIdHeader;
    final actor = _session.actorIdHeader;
    try {
      if (_academicYear.years.value.isEmpty &&
          !await _academicYear.loadYears()) {
        if (!isClosed && generation == _reloadGeneration) {
          errorMessage(_academicYear.errorMessage.value);
          isLoading(false);
        }
        return;
      }
      final catalog = _catalogClient();
      final placements = await catalog.enrollments.listAll({
        'studentId': studentId,
      });
      if (isClosed ||
          generation != _reloadGeneration ||
          school != _session.schoolIdHeader ||
          actor != _session.actorIdHeader)
        return;
      final available = pupilEnrollmentYears(
        _academicYear.years.value,
        placements,
        studentId,
      );
      if (placements.isNotEmpty && available.isEmpty) {
        throw StateError(systemL10n().noAcademicYearsAvailable);
      }
      if (yearId != null && !available.any((y) => y['id'] == yearId)) {
        throw StateError('School year unavailable');
      }
      enrollmentYears(available);
      _academicYear.selectedYearId(yearId ?? defaultPupilYear(available));
      _academicYear.errorMessage('');
      await _sessionStorage.writeActiveStudentId(studentId);
      if (isClosed || generation != _reloadGeneration) return;
      await reloadContext();
    } catch (error) {
      if (!isClosed && generation == _reloadGeneration) {
        errorMessage(systemL10n().couldNotLoadStudentContext(error.toString()));
        isLoading(false);
      }
      rethrow;
    } finally {
      if (!isClosed && selection == _selectionGeneration) _switching = false;
    }
  }

  Future<void> selectEnrollmentYear(String yearId) async {
    final id = activeStudentId;
    if (id == null) return;
    await selectStudent(id, yearId: yearId);
  }

  Future<void> clearStudent() async {
    await _sessionStorage.writeActiveStudentId(null);
    _clearContext();
  }

  void _clearContext() {
    _reloadGeneration++;
    activeStudent(null);
    enrollmentYears(const []);
    classGroupId(null);
    classLabel(null);
    schoolName(null);
    isEnrolled(false);
    errorMessage('');
    isLoading(false);
  }

  Future<void> reloadContext() {
    final generation = ++_reloadGeneration;
    return _reloadContext(generation);
  }

  Future<void> _reloadContext(int generation) async {
    final studentId = await _sessionStorage.readActiveStudentId();
    if (generation != _reloadGeneration) {
      return;
    }
    if (studentId == null) {
      _clearContext();
      return;
    }

    errorMessage('');

    await runTask(() async {
      if (generation != _reloadGeneration) {
        return;
      }
      isLoading(true);
      try {
        final schoolClient = _schoolClient();
        final studentJson = await schoolClient.students.get(studentId);
        if (generation != _reloadGeneration) {
          return;
        }
        final student = LinkedStudent.fromJson(studentJson);
        if (student.id != studentId) {
          return;
        }
        final resolvedSchoolName = await _loadSchoolName(
          schoolClient,
          student.schoolId,
        );
        if (generation != _reloadGeneration) {
          return;
        }
        await _academicYear.applyStoredYearForSchool(student.schoolId);
        if (generation != _reloadGeneration) {
          return;
        }
        final resolvedYearId = _academicYear.selectedYearId.value;

        if (resolvedYearId == null) {
          classGroupId(null);
          classLabel(null);
          isEnrolled(false);
          schoolName(resolvedSchoolName);
          activeStudent(student);
          return;
        }

        await _loadEnrollment(
          schoolClient: schoolClient,
          studentId: studentId,
          yearId: resolvedYearId,
          generation: generation,
        );
        if (isClosed ||
            generation != _reloadGeneration ||
            errorMessage.value.isNotEmpty)
          return;
        schoolName(resolvedSchoolName);
        activeStudent(student);
      } on api.ApiError catch (error) {
        if (generation != _reloadGeneration) {
          return;
        }
        errorMessage(systemL10n().couldNotLoadStudentContext(error.toString()));
        activeStudent(null);
        classGroupId(null);
        classLabel(null);
        schoolName(null);
        isEnrolled(false);
      } on Object catch (error) {
        if (generation != _reloadGeneration) {
          return;
        }
        errorMessage(systemL10n().couldNotLoadStudentContext(error.toString()));
        activeStudent(null);
        classGroupId(null);
        classLabel(null);
        schoolName(null);
        isEnrolled(false);
      } finally {
        if (generation == _reloadGeneration) {
          isLoading(false);
        }
      }
    });
  }

  Future<void> _loadEnrollment({
    required api.SchoolClient schoolClient,
    required String studentId,
    required String yearId,
    required int generation,
  }) async {
    try {
      final enrollments = await schoolClient.enrollments.listAll({
        'studentId': studentId,
        'academicYearId': yearId,
      });

      if (generation != _reloadGeneration || isClosed) return;
      if (enrollments.isEmpty) {
        classGroupId(null);
        classLabel(null);
        isEnrolled(false);
        return;
      }

      enrollments.sort(
        (a, b) => ((b['enrollmentIndex'] as num?) ?? 0).compareTo(
          (a['enrollmentIndex'] as num?) ?? 0,
        ),
      );
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
      if (generation != _reloadGeneration || isClosed) return;
      final className = classGroup['name'] as String? ?? enrollmentClassGroupId;
      final level = classGroup['level'] as String?;
      classLabel(level == null ? className : '$className · $level');
      isEnrolled(true);
    } on api.ApiError catch (error) {
      if (isClosed || generation != _reloadGeneration) return;
      errorMessage(systemL10n().couldNotLoadEnrollment(error.toString()));
      classGroupId(null);
      classLabel(null);
      isEnrolled(false);
    } on Object catch (error) {
      if (isClosed || generation != _reloadGeneration) return;
      errorMessage(systemL10n().couldNotLoadEnrollment(error.toString()));
      classGroupId(null);
      classLabel(null);
      isEnrolled(false);
    }
  }

  Future<String?> _loadSchoolName(
    api.SchoolClient schoolClient,
    String schoolId,
  ) async {
    if (schoolId.isEmpty) return _session.schoolIdHeader;
    try {
      final row = await schoolClient.schools.get(schoolId);
      final name = row['name'] as String?;
      if (name != null && name.trim().isNotEmpty) return name;
    } on Object {
      // Fall back to the school id when the directory name is not readable.
    }
    return schoolId;
  }
}
