import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../live/entity_queries.dart';
import '../auth/session_storage.dart';
import 'academic_year_controller.dart';

class TeacherAssignmentOption {
  const TeacherAssignmentOption({
    required this.id,
    required this.classGroupId,
    required this.classLabel,
    required this.subjectLabel,
    required this.isHomeroom,
    this.classSubjectId,
  });

  final String id;
  final String classGroupId;
  final String classLabel;
  final String subjectLabel;
  final bool isHomeroom;
  final String? classSubjectId;
}

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
  final schoolName = LxVar<String?>(null);
  final assignments = LxVar<List<TeacherAssignmentOption>>(const []);
  final activeAssignmentId = LxVar<String?>(null);
  final assignedClasses = LxVar<List<AssignedClass>>(const []);
  final taughtClassSubjectIds = LxVar<Set<String>>({});
  final assignedClassGroupIds = LxVar<Set<String>>({});
  final isLoading = LxVar(false);
  final errorMessage = LxVar('');
  bool _closed = false;

  @override
  void onClose() {
    _closed = true;
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();
    autoDispose(teacherName);
    autoDispose(teacherPhotoUrl);
    autoDispose(teacherId);
    autoDispose(schoolName);
    autoDispose(assignments);
    autoDispose(activeAssignmentId);
    autoDispose(assignedClasses);
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

  TeacherAssignmentOption? get activeAssignment {
    final id = activeAssignmentId.value;
    if (id == null) {
      return assignments.value.isEmpty ? null : assignments.value.first;
    }
    for (final assignment in assignments.value) {
      if (assignment.id == id) {
        return assignment;
      }
    }
    return assignments.value.isEmpty ? null : assignments.value.first;
  }

  List<String> get visibleClassGroupIds {
    final active = activeAssignment;
    if (active != null) {
      return [active.classGroupId];
    }
    return assignedClasses.value.map((entry) => entry.id).toList();
  }

  String get teacherInitials {
    final name = teacherName.value?.trim() ?? '';
    if (name.isEmpty) {
      return 'EN';
    }
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final letters = parts.map((part) => part[0]).take(2).join();
    return letters.toUpperCase();
  }

  Future<void> _reloadOnAcademicYearChange() async {
    await _session.refreshGrants();
    if (!_closed) await reloadContext();
  }

  Future<void> initializeFromSession() async {
    final persisted = await _sessionStorage.readAssignmentId();
    if (_closed) return;
    activeAssignmentId(persisted);
    if (!_closed) await reloadContext();
  }

  Future<void> selectAssignment(String assignmentId) async {
    activeAssignmentId(assignmentId);
    await _sessionStorage.writeAssignmentId(assignmentId);
  }

  Future<void> reloadContext() async {
    if (_closed) return;
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
      assignments(const []);
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
          if (_closed) return;
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
          if (_closed) return;
          teacherName(
            _session.user.value?.name ?? systemL10n().teacherFallbackName,
          );
          teacherPhotoUrl(null);
        }

        final schoolId = _session.schoolIdHeader;
        if (schoolId != null && schoolId.isNotEmpty) {
          try {
            final school = await client.schools.get(schoolId);
            if (_closed) return;
            schoolName(school['name'] as String? ?? schoolId);
          } on Object {
            if (_closed) return;
            schoolName(schoolId);
          }
        }

        final assignmentRows = await client.teacherAssignments.list(
          teacherAssignmentsForTeacherAndYear(
            teacherId: resolvedTeacherId,
            academicYearId: yearId,
          ),
        );
        if (_closed) return;
        // Read grants also include subject teachers' classes. Only actual
        // homeroom assignments may produce a homeroom context option.
        final teachingScope = teachingScopeFromTeacherAssignments(
          assignmentRows,
        );

        final classGroupIds = teachingScope.classGroupIds;
        final taughtSubjectIds = teachingScope.classSubjectIds;
        taughtClassSubjectIds(taughtSubjectIds);
        assignedClassGroupIds(classGroupIds);

        final classSubjectRows = taughtSubjectIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.classSubjects.list(
                entitiesByIds(taughtSubjectIds.toList()),
              );
        if (_closed) return;
        final subjectIds = classSubjectRows
            .map((row) => row['subjectId'] as String?)
            .whereType<String>()
            .toSet()
            .toList();
        final subjectRows = subjectIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.subjects.list(entitiesByIds(subjectIds));
        if (_closed) return;
        final subjectNameById = {
          for (final subject in subjectRows)
            subject['id'] as String:
                subject['name'] as String? ?? systemL10n().subjectFallback,
        };

        final allClassGroupIds = {
          ...classGroupIds,
          ...classSubjectRows.map((row) => row['classGroupId'] as String),
        };
        final classLabelById = <String, String>{};
        for (final classGroupId in allClassGroupIds) {
          try {
            final classGroup = await client.classGroups.get(classGroupId);
            classLabelById[classGroupId] =
                classGroup['name'] as String? ?? classGroupId;
          } on Object {
            classLabelById[classGroupId] = classGroupId;
          }
        }

        if (_closed) return;
        final classes = [
          for (final entry in classLabelById.entries)
            AssignedClass(id: entry.key, label: entry.value),
        ]..sort((a, b) => a.label.compareTo(b.label));
        assignedClasses(classes);

        final options = <TeacherAssignmentOption>[];
        for (final classGroupId in classGroupIds) {
          options.add(
            TeacherAssignmentOption(
              id: 'homeroom-$classGroupId',
              classGroupId: classGroupId,
              classLabel: classLabelById[classGroupId] ?? classGroupId,
              subjectLabel: 'Titulaire',
              isHomeroom: true,
            ),
          );
        }
        for (final row in classSubjectRows) {
          final classSubjectId = row['id'] as String;
          final classGroupId = row['classGroupId'] as String;
          final subjectId = row['subjectId'] as String?;
          options.add(
            TeacherAssignmentOption(
              id: classSubjectId,
              classGroupId: classGroupId,
              classLabel: classLabelById[classGroupId] ?? classGroupId,
              classSubjectId: classSubjectId,
              subjectLabel: subjectId == null
                  ? systemL10n().subjectFallback
                  : subjectNameById[subjectId] ?? systemL10n().subjectFallback,
              isHomeroom: false,
            ),
          );
        }
        options.sort((a, b) {
          final byClass = a.classLabel.compareTo(b.classLabel);
          if (byClass != 0) {
            return byClass;
          }
          return a.subjectLabel.compareTo(b.subjectLabel);
        });
        assignments(options);

        final persisted = activeAssignmentId.value;
        if (options.isEmpty) {
          activeAssignmentId(null);
          await _sessionStorage.writeAssignmentId(null);
        } else if (persisted == null ||
            !options.any((option) => option.id == persisted)) {
          await selectAssignment(options.first.id);
        }
      } on api.ApiError catch (error) {
        if (!_closed) {
          errorMessage(systemL10n().couldNotLoadTeachingContext('$error'));
        }
      } on Object catch (error) {
        if (!_closed) {
          errorMessage(systemL10n().couldNotLoadTeachingContext('$error'));
        }
      } finally {
        if (!_closed) isLoading(false);
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
    if (_closed) return;
    teacherId(null);
    teacherName(null);
    teacherPhotoUrl(null);
    schoolName(null);
    assignments(const []);
    assignedClasses(const []);
    taughtClassSubjectIds({});
    assignedClassGroupIds({});
    errorMessage('');
    isLoading(false);
  }
}
