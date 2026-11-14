import 'dart:async';
import 'package:timezone/timezone.dart' as tz;

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
  String get label => [
    classLabel,
    if (classSubjectId != null) subjectLabel,
    if (isHomeroom) 'Titulaire',
  ].join(' · ');
}

class TeacherWorkspaceSelection {
  const TeacherWorkspaceSelection({
    required this.schoolId,
    required this.academicYearId,
    required this.classGroupId,
    this.classSubjectId,
  });
  final String schoolId;
  final String academicYearId;
  final String classGroupId;
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
  final schoolTimeZone = LxVar('UTC');
  tz.TZDateTime schoolTime(DateTime instant) => tz.TZDateTime.from(
    instant,
    schoolTimeZone.value == 'UTC'
        ? tz.UTC
        : tz.getLocation(schoolTimeZone.value),
  );
  final schoolName = LxVar<String?>(null);
  final assignments = LxVar<List<TeacherAssignmentOption>>(const []);
  final classByAssignmentId = LxVar<Map<String, String>>({});
  final activeAssignmentId = LxVar<String?>(null);
  final assignedClasses = LxVar<List<AssignedClass>>(const []);
  final taughtClassSubjectIds = LxVar<Set<String>>({});
  final assignedClassGroupIds = LxVar<Set<String>>({});
  final isLoading = LxVar(false);
  final errorMessage = LxVar('');
  bool _closed = false;
  int _loadGeneration = 0;
  int _selectionRevision = 0;

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
    autoDispose(schoolTimeZone);
    autoDispose(assignments);
    autoDispose(activeAssignmentId);
    autoDispose(classByAssignmentId);
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
      return null;
    }
    for (final assignment in assignments.value) {
      if (assignment.id == id) {
        return assignment;
      }
    }
    return null;
  }

  List<String> get visibleClassGroupIds {
    final active = activeAssignment;
    if (active != null) {
      return [active.classGroupId];
    }
    return const [];
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
    if (_academicYear.selectedYearId.value == null) {
      await reloadContext();
      return;
    }
    await _session.refreshGrants();
    if (!_closed) await reloadContext();
  }

  Future<void> initializeFromSession() async {
    if (!_closed) await reloadContext();
  }

  TeacherWorkspaceSelection? get selection {
    final active = activeAssignment;
    final school = _session.schoolIdHeader;
    final year = _academicYear.selectedYearId.value;
    if (active == null || school == null || year == null) return null;
    return TeacherWorkspaceSelection(
      schoolId: school,
      academicYearId: year,
      classGroupId: active.classGroupId,
      classSubjectId: active.classSubjectId,
    );
  }

  String get _legacySelectionKey =>
      'teacher_v2.class.${_session.grants.value?.schoolId}.${teacherId.value}.${_academicYear.selectedYearId.value}';
  String get _selectionKey => 'teacher_v2.assignment.$_legacySelectionKey';

  Future<void> selectClass(String? classId) async {
    final current = activeAssignment;
    final option = current?.classGroupId == classId
        ? current
        : assignments.value
              .where((item) => item.classGroupId == classId)
              .firstOrNull;
    if (option != null) await selectAssignment(option.id);
  }

  Future<void> selectAssignment(String assignmentId) async {
    final option = assignments.value
        .where((item) => item.id == assignmentId)
        .firstOrNull;
    if (option == null) return;
    _selectionRevision++;
    activeAssignmentId(option.id);
    await _sessionStorage.writeClassSelection(_selectionKey, option.id);
  }

  Future<void>? _pendingLoad;
  String? _pendingKey;
  Future<void> reloadContext() {
    final grants = _session.grants.value;
    final key =
        '${grants?.schoolId}/${grants?.actorId}/${_academicYear.selectedYearId.value}';
    final pending = _pendingLoad;
    if (_pendingKey == key && pending != null) return pending;
    _pendingKey = key;
    final next = _loadContext();
    _pendingLoad = next;
    return next.whenComplete(() {
      if (identical(_pendingLoad, next)) _pendingLoad = null;
    });
  }

  Future<void> _loadContext() async {
    if (_closed) return;
    final generation = ++_loadGeneration;
    final revision = _selectionRevision;
    bool stale() => _closed || generation != _loadGeneration;
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
          if (stale()) return;
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
          if (stale()) return;
          teacherName(
            _session.user.value?.name ?? systemL10n().teacherFallbackName,
          );
          teacherPhotoUrl(null);
        }

        final schoolId = _session.schoolIdHeader;
        if (schoolId != null && schoolId.isNotEmpty) {
          try {
            final school = await client.schools.get(schoolId);
            if (stale()) return;
            schoolTimeZone(school['timeZone'] as String? ?? 'UTC');
            schoolName(school['name'] as String? ?? schoolId);
          } on Object {
            if (stale()) return;
            schoolName(schoolId);
          }
        }

        final assignmentRows = await client.teacherAssignments.list(
          teacherAssignmentsForTeacherAndYear(
            teacherId: resolvedTeacherId,
            academicYearId: yearId,
          ),
        );
        if (stale()) return;
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
        if (stale()) return;
        final groupBySubject = {
          for (final row in classSubjectRows)
            row['id'] as String: row['classGroupId'] as String,
        };
        classByAssignmentId({
          for (final row in assignmentRows)
            if ((row['classGroupId'] ?? groupBySubject[row['classSubjectId']])
                case final String group)
              row['id'] as String: group,
        });
        final subjectIds = classSubjectRows
            .map((row) => row['subjectId'] as String?)
            .whereType<String>()
            .toSet()
            .toList();
        final subjectRows = subjectIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.subjects.list(entitiesByIds(subjectIds));
        if (stale()) return;
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

        if (stale()) return;
        final classes = [
          for (final entry in classLabelById.entries)
            AssignedClass(id: entry.key, label: entry.value),
        ]..sort((a, b) => a.label.compareTo(b.label));
        assignedClasses(classes);

        final options = <TeacherAssignmentOption>[];
        for (final classGroupId in classGroupIds) {
          if (classSubjectRows.any(
            (row) => row['classGroupId'] == classGroupId,
          )) {
            continue;
          }
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
              isHomeroom: classGroupIds.contains(classGroupId),
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

        final saved = await _sessionStorage.readClassSelection(_selectionKey);
        final legacy = saved == null
            ? await _sessionStorage.readClassSelection(_legacySelectionKey)
            : null;
        if (stale() ||
            revision != _selectionRevision ||
            yearId != _academicYear.selectedYearId.value ||
            resolvedTeacherId != _session.grants.value?.actorId) {
          return;
        }
        final selected =
            options.where((option) => option.id == saved).firstOrNull ??
            options
                .where((option) => option.classGroupId == legacy)
                .firstOrNull ??
            options.firstOrNull;
        activeAssignmentId(selected?.id);
        if (selected == null) {
          errorMessage('Aucune affectation active pour cette année scolaire.');
        } else if (saved != null && selected.id != saved) {
          errorMessage(
            'Votre affectation a changé. Un autre enseignement a été sélectionné.',
          );
        }
        await _sessionStorage.writeClassSelection(_selectionKey, selected?.id);
      } on api.ApiError catch (error) {
        if (!stale()) {
          errorMessage(systemL10n().couldNotLoadTeachingContext('$error'));
        }
      } on Object catch (error) {
        if (!stale()) {
          errorMessage(systemL10n().couldNotLoadTeachingContext('$error'));
        }
      } finally {
        if (!stale()) isLoading(false);
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
    _loadGeneration++;
    if (_closed) return;
    teacherId(null);
    teacherName(null);
    teacherPhotoUrl(null);
    classByAssignmentId({});
    schoolName(null);
    schoolTimeZone('UTC');
    assignments(const []);
    assignedClasses(const []);
    taughtClassSubjectIds({});
    assignedClassGroupIds({});
    errorMessage('');
    isLoading(false);
  }
}
