import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import '../../common/utils/entity_query.dart';
import 'package:edaya_shared/edaya_shared.dart';
import '../auth/session_storage.dart';
import 'academic_year_controller.dart';

class AssignedClass {
  const AssignedClass({required this.id, required this.label});

  final String id;
  final String label;
}

class TeacherContextController extends LevitController
    with LevitReactiveTasksMixin {
  TeacherContextController({
    required SessionStorage sessionStorage,
    required AppSessionController session,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _sessionStorage = sessionStorage,
       _session = session,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final SessionStorage _sessionStorage;
  final AppSessionController _session;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final teacherName = LxVar<String?>(null);
  final teacherPhotoUrl = LxVar<String?>(null);
  final teacherId = LxVar<String?>(null);
  final assignedClasses = LxVar<List<AssignedClass>>(const []);
  final classFilterId = LxVar<String?>(null);
  final taughtClassSubjectIds = LxVar<Set<String>>({});
  final assignedClassGroupIds = LxVar<Set<String>>({});
  final isLoading = LxVar(false);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(teacherName);
    autoDispose(teacherPhotoUrl);
    autoDispose(teacherId);
    autoDispose(assignedClasses);
    autoDispose(classFilterId);
    autoDispose(taughtClassSubjectIds);
    autoDispose(assignedClassGroupIds);
    autoDispose(isLoading);
    autoDispose(errorMessage);

    autoDispose(
      _academicYear.selectedYearId.listen((_) {
        unawaited(_reloadOnAcademicYearChange());
      }),
    );
    autoDispose(
      _session.grants.stream.listen((grants) {
        if (grants == null || grants.kind != 'teacher') {
          _clearContext();
        }
      }),
    );
  }

  Future<void> _reloadOnAcademicYearChange() async {
    await _session.refreshGrants();
    await reloadContext();
  }

  List<String> get visibleClassGroupIds {
    final filter = classFilterId.value;
    if (filter != null) {
      return [filter];
    }
    return assignedClasses.value.map((entry) => entry.id).toList();
  }

  String? get classFilterLabel {
    final filter = classFilterId.value;
    if (filter == null) {
      return null;
    }
    for (final assigned in assignedClasses.value) {
      if (assigned.id == filter) {
        return assigned.label;
      }
    }
    return filter;
  }

  Future<void> initializeFromSession() async {
    final persistedFilter = await _sessionStorage.readClassFilterId();
    classFilterId(persistedFilter);
    await reloadContext();
  }

  Future<void> selectClassFilter(String? classGroupId) async {
    classFilterId(classGroupId);
    await _sessionStorage.writeClassFilterId(classGroupId);
  }

  Future<void> reloadContext() async {
    final grants = _session.grants.value;
    if (grants == null || grants.kind != 'teacher') {
      _clearContext();
      return;
    }

    final resolvedTeacherId = grants.actorId;
    teacherId(resolvedTeacherId);
    errorMessage('');

    final yearId = _academicYear.selectedYearId.value;
    if (yearId == null) {
      teacherName(
        _session.user.value?.name ?? systemL10n().teacherFallbackName,
      );
      assignedClasses(const []);
      taughtClassSubjectIds({});
      assignedClassGroupIds({});
      return;
    }

    await runTask(() async {
      isLoading(true);
      try {
        final client = _schoolClient();
        try {
          final teacher = await client.teachers.get(resolvedTeacherId);
          final firstName = teacher['firstName'] as String? ?? '';
          final lastName = teacher['lastName'] as String? ?? '';
          final fullName = '$firstName $lastName'.trim();
          teacherName(
            fullName.isEmpty
                ? (_session.user.value?.name ??
                      systemL10n().teacherFallbackName)
                : fullName,
          );
          teacherPhotoUrl(teacher['photoUrl'] as String?);
        } on Object {
          teacherName(
            _session.user.value?.name ?? systemL10n().teacherFallbackName,
          );
          teacherPhotoUrl(null);
        }

        final assignments = await client.teacherAssignments.list(
          teacherAssignmentsForTeacherAndYear(
            teacherId: resolvedTeacherId,
            academicYearId: yearId,
          ),
        );
        final teachingScope = teachingScopeFromTeacherAssignments(assignments);

        final classGroupIds = teachingScope.classGroupIds;
        final taughtSubjectIds = teachingScope.classSubjectIds;

        final classSubjectRows = taughtSubjectIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.classSubjects.list(
                entitiesByIds(taughtSubjectIds.toList()),
              );
        taughtClassSubjectIds(taughtSubjectIds);
        assignedClassGroupIds(classGroupIds);

        final allClassGroupIds = {
          ...classGroupIds,
          ...classSubjectRows.map((row) => row['classGroupId'] as String),
        };

        final classes = <AssignedClass>[];
        for (final classGroupId in allClassGroupIds) {
          try {
            final classGroup = await client.classGroups.get(classGroupId);
            classes.add(
              AssignedClass(
                id: classGroupId,
                label: classGroup['name'] as String? ?? classGroupId,
              ),
            );
          } on Object {
            classes.add(AssignedClass(id: classGroupId, label: classGroupId));
          }
        }
        classes.sort((a, b) => a.label.compareTo(b.label));
        assignedClasses(classes);

        final persistedFilter = await _sessionStorage.readClassFilterId();
        if (persistedFilter != null &&
            !classes.any((entry) => entry.id == persistedFilter)) {
          await selectClassFilter(null);
        }
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadTeachingContext('$error'));
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadTeachingContext('$error'));
      } finally {
        isLoading(false);
      }
    });
  }

  bool canTeachSession({
    required String sessionId,
    required String? classGroupId,
    required String? classSubjectId,
  }) {
    if (classSubjectId != null &&
        taughtClassSubjectIds.value.contains(classSubjectId)) {
      return true;
    }
    if (classGroupId != null &&
        assignedClassGroupIds.value.contains(classGroupId)) {
      return true;
    }
    return false;
  }

  void _clearContext() {
    teacherId(null);
    teacherName(null);
    teacherPhotoUrl(null);
    assignedClasses(const []);
    taughtClassSubjectIds({});
    assignedClassGroupIds({});
    errorMessage('');
    isLoading(false);
  }
}
