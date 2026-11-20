import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../auth/session_storage.dart';
import '../my_students/linked_student.dart';
import 'academic_year_controller.dart';
import 'guardian_choices.dart';
import 'pupil_enrollment_years.dart';

typedef GuardianPupilSelection = ({
  String accountId,
  String schoolId,
  String guardianId,
  String studentId,
  String academicYearId,
});

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
       _catalogClient = catalogClient ?? schoolClient;

  final SessionStorage _sessionStorage;
  final AppSessionController _session;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _catalogClient;
  final enrollmentYears = LxVar<List<Map<String, dynamic>>>(const []);

  final linkedStudentIds = LxVar<List<String>>(const []);
  final linkedStudentsResolved = LxVar(false);
  final activeStudent = LxVar<LinkedStudent?>(null);
  final classGroupId = LxVar<String?>(null);
  final classLabel = LxVar<String?>(null);
  final schoolTimeZone = LxVar<String>('UTC');
  final schoolName = LxVar<String?>(null);
  final isEnrolled = LxVar(false);
  final isLoading = LxVar(false);
  final errorMessage = LxVar('');

  int _generation = 0;
  bool _switching = false;
  String? _appliedYear;
  (String?, String?, String?, String?)? _resolvedScope;
  (String?, String?, String?, String?) get _scope => (
    _session.user.value?.id,
    _session.schoolIdHeader,
    _session.actorIdHeader,
    _session.grants.value?.kind,
  );

  void beginSwitch() {
    _generation++;
    _switching = true;
    _resolvedScope = null;
    linkedStudentIds(const []);
    linkedStudentsResolved(false);
    _clearContext();
  }

  String? get activeYearId => _academicYear.selectedYearId.value;

  String? get activeStudentId => activeStudent.value?.id;

  /// The published pupil/year only while its verified session still matches.
  GuardianPupilSelection? get verifiedSelection {
    final scope = _scope;
    final (accountId, schoolId, guardianId, kind) = scope;
    final studentId = activeStudentId;
    final yearId = activeYearId;
    if (_switching ||
        scope != _resolvedScope ||
        kind != 'guardian' ||
        accountId == null ||
        schoolId == null ||
        guardianId == null ||
        studentId == null ||
        yearId == null ||
        yearId != _appliedYear) {
      return null;
    }
    return (
      accountId: accountId,
      schoolId: schoolId,
      guardianId: guardianId,
      studentId: studentId,
      academicYearId: yearId,
    );
  }

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
    autoDispose(schoolTimeZone);
    autoDispose(isEnrolled);
    autoDispose(isLoading);
    autoDispose(errorMessage);

    autoDispose(
      _academicYear.selectedYearId.stream.listen((id) {
        if (!_switching && id != _appliedYear && activeStudentId != null) {
          unawaited(reloadContext());
        }
      }),
    );
    void invalidateScope() {
      if (_resolvedScope != null && _resolvedScope != _scope) beginSwitch();
    }

    autoDispose(_session.grants.stream.listen((_) => invalidateScope()));
    autoDispose(_session.user.stream.listen((_) => invalidateScope()));
  }

  Future<void> initializeFromSession({
    String? preferredStudentId,
    String? preferredYearId,
    GuardianChoices? choices,
  }) => _resolve(
    studentId: preferredStudentId,
    yearId: preferredYearId,
    choices: choices,
  );

  Future<void> selectStudent(String studentId, {String? yearId}) async {
    if (!linkedStudentIds.value.contains(studentId)) return;
    await _resolve(studentId: studentId, yearId: yearId);
  }

  Future<void> selectEnrollmentYear(String yearId) async {
    final id = activeStudentId;
    if (id != null) await selectStudent(id, yearId: yearId);
  }

  Future<void> reloadContext() =>
      _resolve(studentId: activeStudentId, yearId: activeYearId);

  Future<void> clearStudent() async {
    ++_generation;
    _clearContext();
    _switching = false;
    await _sessionStorage.writeActiveStudentId(null);
  }

  Future<void> _resolve({
    String? studentId,
    String? yearId,
    GuardianChoices? choices,
  }) async {
    final generation = ++_generation;
    final scope = _scope;
    bool current() => !isClosed && _generation == generation && _scope == scope;
    _switching = true;
    _clearContext();
    _resolvedScope = scope;
    if (!_session.isAuthenticated ||
        _session.grants.value?.kind != 'guardian') {
      linkedStudentIds(const []);
      linkedStudentsResolved(true);
      _switching = false;
      return;
    }
    isLoading(true);
    try {
      final result =
          choices ??
          GuardianChoices.fromJson(
            await _catalogClient().getGuardianChildChoices({}),
            accountId: scope.$1,
          );
      if (!current()) return;
      if (result.accountId != scope.$1 ||
          result.schoolId != scope.$2 ||
          result.guardianId != scope.$3) {
        throw StateError('Guardian profile changed');
      }
      final children = result.children;
      final ids = [for (final child in children) child.id]..sort();
      linkedStudentIds(ids);
      linkedStudentsResolved(true);
      final stored = studentId ?? await _sessionStorage.readActiveStudentId();
      if (!current()) return;
      final child =
          children.where((entry) => entry.id == stored).firstOrNull ??
          (studentId == null && ids.isNotEmpty
              ? children.firstWhere((child) => child.id == ids.first)
              : null);
      if (child == null) {
        _academicYear.applyGuardianChoices(result.years, null);
        await _sessionStorage.writeActiveStudentId(null);
        if (studentId != null) throw StateError('Child unavailable');
        return;
      }
      final placements = result.enrollments.where(
        (e) => e['studentId'] == child.id,
      );
      final available = pupilEnrollmentYears(
        result.years,
        placements,
        child.id,
      );
      if (placements.isNotEmpty && available.isEmpty) {
        throw StateError(systemL10n().noAcademicYearsAvailable);
      }
      bool eligible(String? id) =>
          id != null && available.any((y) => y['id'] == id);
      if (yearId != null && !eligible(yearId)) {
        throw StateError('School year unavailable');
      }
      String? savedYear;
      if (yearId == null && _academicYear.archive) {
        savedYear =
            _academicYear.initialYearId ??
            await _sessionStorage.readAcademicYearIdForSchool(result.schoolId);
      }
      if (!current()) return;
      final selected =
          yearId ??
          (eligible(savedYear) ? savedYear : defaultPupilYear(available));
      final inYear =
          placements.where((e) => e['academicYearId'] == selected).toList()
            ..sort(
              (a, b) => (b['enrollmentIndex'] as int).compareTo(
                a['enrollmentIndex'] as int,
              ),
            );
      final placement = inYear.firstOrNull;
      await _sessionStorage.writeActiveStudentId(child.id);
      if (!current()) return;
      _appliedYear = selected;
      _academicYear.applyGuardianChoices(result.years, selected);
      enrollmentYears(available);
      classGroupId(placement?['classGroupId'] as String?);
      classLabel(placement?['classLabel'] as String?);
      isEnrolled(placement != null);
      schoolName(result.schoolName);
      schoolTimeZone(result.timeZone);
      activeStudent(child);
    } catch (error) {
      if (!current()) return;
      errorMessage(systemL10n().couldNotLoadStudentContext(error.toString()));
      if (error is StateError) rethrow;
    } finally {
      if (current()) {
        _switching = false;
        isLoading(false);
      }
    }
  }

  void _clearContext() {
    activeStudent(null);
    enrollmentYears(const []);
    classGroupId(null);
    classLabel(null);
    schoolName(null);
    schoolTimeZone('UTC');
    isEnrolled(false);
    errorMessage('');
    isLoading(false);
  }
}
