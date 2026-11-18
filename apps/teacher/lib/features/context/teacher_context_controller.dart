import 'package:timezone/timezone.dart' as tz;

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'teacher_assignment_catalog.dart';
export 'teacher_assignment_catalog.dart'
    show TeacherAssignmentOption, AssignedClass;
import '../auth/session_storage.dart';
import 'academic_year_controller.dart';

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
  bool confirmedNoAssignments = false;
  final loadFailed = LxVar(false);
  void recordLoadFailure(String message) {
    _recent.remove((_session.schoolIdHeader, _session.actorIdHeader));
    confirmedNoAssignments = false;
    loadFailed(true);
    errorMessage(message);
  }

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
    autoDispose(loadFailed);

    autoDispose(
      _session.user.stream.listen((user) {
        _recent.removeWhere(
          (_, entry) => entry.catalog.workspace.account != user?.id,
        );
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

  TeacherAssignmentCatalog? catalog;
  final _recent =
      <
        (String, String),
        ({TeacherAssignmentCatalog catalog, String? yearLabel})
      >{};

  /// Only picker display data is retained between school visits. Activation
  /// always reads the published year, grants and actual assignments again.
  ({TeacherAssignmentCatalog catalog, String? yearLabel})? recentCatalog(
    String school,
    String actor,
  ) {
    final entry = _recent[(school, actor)];
    if (entry == null ||
        !entry.catalog.fresh ||
        entry.catalog.workspace.account != _session.user.value?.id)
      return null;
    return entry;
  }

  void rememberCatalog(TeacherAssignmentCatalog data, String? yearLabel) {
    if (_closed || data.workspace.account != _session.user.value?.id) return;
    _recent.removeWhere(
      (_, e) =>
          !e.catalog.fresh ||
          e.catalog.workspace.account != data.workspace.account,
    );
    _recent[(data.workspace.school, data.workspace.actor)] = (
      catalog: data,
      yearLabel: yearLabel,
    );
  }

  Future<void> initializeFromSession({
    TeacherAssignmentCatalog? preview,
    String? preferredAssignment,
  }) async {
    if (!_closed)
      await reloadContext(
        preview: preview,
        preferredAssignment: preferredAssignment,
      );
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
  Future<void> reloadContext({
    TeacherAssignmentCatalog? preview,
    String? preferredAssignment,
  }) {
    final grants = _session.grants.value;
    final key =
        '${grants?.schoolId}/${grants?.actorId}/${_academicYear.selectedYearId.value}/${_session.user.value?.id}/$preferredAssignment';
    final pending = _pendingLoad;
    if (_pendingKey == key && pending != null) return pending;
    _pendingKey = key;
    final next = _loadContext(preview, preferredAssignment);
    _pendingLoad = next;
    return next.whenComplete(() {
      if (identical(_pendingLoad, next)) _pendingLoad = null;
    });
  }

  Future<void> _loadContext(
    TeacherAssignmentCatalog? preview,
    String? preferredAssignment,
  ) async {
    if (_closed) return;
    final generation = ++_loadGeneration;
    final revision = _selectionRevision;
    final grants = _session.grants.value;
    final account = _session.user.value?.id;
    final yearId = _academicYear.selectedYearId.value;
    bool stale() =>
        _closed ||
        generation != _loadGeneration ||
        account != _session.user.value?.id ||
        yearId != _academicYear.selectedYearId.value ||
        grants?.schoolId != _session.schoolIdHeader ||
        grants?.actorId != _session.actorIdHeader;
    if (account == null || grants == null || grants.kind != 'teacher') {
      _clearContext();
      return;
    }

    confirmedNoAssignments = false;
    loadFailed(false);
    final resolvedTeacherId = grants.actorId;
    teacherId(resolvedTeacherId);
    errorMessage('');

    if (yearId == null) {
      teacherName(
        _session.user.value?.name ?? systemL10n().teacherFallbackName,
      );
      catalog = null;
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
        final workspace = (
          account: account,
          school: grants.schoolId,
          actor: resolvedTeacherId,
          year: yearId,
        );
        if (preview == null || catalog?.workspace != workspace) {
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
        }
        final data = await readTeacherAssignmentCatalog(
          client,
          workspace,
          previous: preview,
        );
        if (stale()) return;
        final options = data.options;
        final saved = await _sessionStorage.readClassSelection(_selectionKey);
        final legacy = saved == null
            ? await _sessionStorage.readClassSelection(_legacySelectionKey)
            : null;
        if (stale()) return;
        // A user selection during a same-school refresh takes priority if still eligible.
        final preferred = revision == _selectionRevision
            ? preferredAssignment
            : activeAssignmentId.value;
        final selected =
            options.where((option) => option.id == preferred).firstOrNull ??
            options.where((option) => option.id == saved).firstOrNull ??
            options
                .where((option) => option.classGroupId == legacy)
                .firstOrNull ??
            options.firstOrNull;
        Levit.batch(() {
          catalog = data;
          rememberCatalog(data, _academicYear.selectedYearLabel);
          taughtClassSubjectIds(data.scope.classSubjectIds);
          assignedClassGroupIds(data.scope.classGroupIds);
          classByAssignmentId(data.classByAssignmentId);
          assignedClasses(data.classes);
          assignments(options);
          activeAssignmentId(selected?.id);
        });
        confirmedNoAssignments = selected == null;
        if (selected == null) {
          errorMessage(systemL10n().noActiveAssignmentForThisSchoolYear);
        } else if (preferredAssignment == null &&
            saved != null &&
            selected.id != saved) {
          errorMessage(
            systemL10n().yourAssignmentHasChangedAnotherTeachingAssignmentHas,
          );
        }
        await _sessionStorage.writeClassSelection(_selectionKey, selected?.id);
      } on api.ApiError catch (error) {
        if (!stale()) {
          recordLoadFailure(systemL10n().couldNotLoadTeachingContext('$error'));
        }
      } on Object catch (error) {
        if (!stale()) {
          recordLoadFailure(systemL10n().couldNotLoadTeachingContext('$error'));
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
    catalog = null;
    _pendingKey = null;
    if (_closed) return;
    confirmedNoAssignments = false;
    loadFailed(false);
    activeAssignmentId(null);
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
