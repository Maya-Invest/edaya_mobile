import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/teacher_context_controller.dart';
import 'teaching_data.dart';
import 'teaching_models.dart';

typedef _TeacherScope = ({
  String? teacherId,
  String? schoolId,
  String? yearId,
  String? assignmentId,
});

class LiveClassWorkspaceController extends LevitController
    with LevitReactiveTasksMixin {
  LiveClassWorkspaceController({
    required this.classGroupId,
    this.recordedOnly = true,
    required TeacherContextController teacherContext,
    required SchoolClientFactory schoolClient,
  }) : _teacherContext = teacherContext,
       _schoolClient = schoolClient;

  final String classGroupId;
  final bool recordedOnly;
  final TeacherContextController _teacherContext;
  final SchoolClientFactory _schoolClient;

  final selectedClassSubjectId = LxVar<String?>(null);
  final classSubjectOptions = LxVar<List<TeachingClassSubjectOption>>(const []);
  final progressOverview = LxVar<TeachingProgressOverview?>(null);
  final logbookEntries = LxVar<List<TeachingLogEntry>>(const []);
  final logbookReady = LxVar(false);
  final nextLogbookCursor = LxVar<String?>(null);
  final loadingMore = LxVar(false);
  final logbookPageError = LxVar('');
  Completer<void>? _abort;

  final errorMessage = LxVar('');
  int _teachingGeneration = 0;

  (_TeacherScope, String?)? _displayedSelection;

  _TeacherScope get _contextKey {
    final selection = _teacherContext.selection;
    return (
      teacherId: _teacherContext.teacherId.value,
      schoolId: selection?.schoolId,
      yearId: selection?.academicYearId,
      assignmentId: _teacherContext.activeAssignmentId.value,
    );
  }

  @override
  void onInit() {
    super.onInit();
    autoDispose(selectedClassSubjectId);
    autoDispose(classSubjectOptions);
    autoDispose(progressOverview);
    autoDispose(logbookEntries);
    autoDispose(errorMessage);
    autoDispose(logbookReady);
    autoDispose(nextLogbookCursor);
    autoDispose(loadingMore);
    autoDispose(logbookPageError);
    unawaited(load());
  }

  String get classLabel {
    for (final assigned in _teacherContext.assignedClasses.value) {
      if (assigned.id == classGroupId) {
        return assigned.label;
      }
    }
    return classGroupId;
  }

  TeachingClassSubjectOption? get selectedOption {
    final id = selectedClassSubjectId.value;
    if (id == null) {
      return null;
    }
    return classSubjectOptions.value.where((item) => item.id == id).firstOrNull;
  }

  Future<void> selectSubject(String? classSubjectId) async {
    selectedClassSubjectId(classSubjectId);
    await loadTeachingData();
  }

  Future<void> load() async {
    errorMessage('');
    final contextKey = _contextKey;
    if (_displayedSelection?.$1 != contextKey) _resetTeaching();
    await runTask(() async {
      try {
        final assignment = _teacherContext.activeAssignment;
        final catalog = _teacherContext.catalog;
        final offeringId = assignment?.classSubjectId;
        final options =
            assignment != null &&
                offeringId != null &&
                assignment.classGroupId == classGroupId &&
                catalog != null &&
                catalog.fresh &&
                catalog.options.contains(assignment)
            ? [
                TeachingClassSubjectOption(
                  id: offeringId,
                  classGroupId: classGroupId,
                  subjectName: assignment.subjectLabel,
                  classLabel: classLabel,
                ),
              ]
            : await fetchTeachingSubjectsForClass(
                client: _schoolClient(),
                classGroupId: classGroupId,
                taughtClassSubjectIds: {?offeringId},
                isHomeroomClass: false,
                classLabelById: {classGroupId: classLabel},
                subjectFallback: systemL10n().subjectFallback,
              );
        if (isClosed || contextKey != _contextKey) return;
        classSubjectOptions(options);
        if (options.isEmpty) {
          selectedClassSubjectId(null);
          _resetTeaching();
          return;
        }
        final current = selectedClassSubjectId.value;
        if (current == null || !options.any((item) => item.id == current)) {
          selectedClassSubjectId(options.first.id);
        }
        await loadTeachingData();
      } on Object catch (error) {
        if (isClosed || contextKey != _contextKey) return;
        _firstPageFailure(error);
      }
    });
  }

  void _cancelReads() {
    ++_teachingGeneration;
    _abort?.complete();
    _abort = null;
  }

  @override
  void onClose() {
    _cancelReads();
    super.onClose();
  }

  void _resetTeaching() {
    _cancelReads();
    progressOverview(null);
    logbookEntries(const []);
    logbookReady(false);
    nextLogbookCursor(null);
    loadingMore(false);
    logbookPageError('');
  }

  bool _denied(Object error) =>
      error is api.ApiError && (error.status == 401 || error.status == 403);

  void _firstPageFailure(Object error) {
    if (_denied(error)) _resetTeaching();
    errorMessage(systemL10n().couldNotLoadTeachingData('$error'));
  }

  bool _current(int generation, _TeacherScope scope) =>
      !isClosed && generation == _teachingGeneration && scope == _contextKey;

  Future<void> loadTeachingData() async {
    final option = selectedOption;
    final scope = _contextKey;
    final selection = (scope, option?.id);
    if (_displayedSelection != selection || option == null) {
      _resetTeaching();
      _displayedSelection = selection;
    } else {
      _cancelReads();
    }
    final generation = _teachingGeneration;
    errorMessage('');
    logbookPageError('');
    loadingMore(false);
    nextLogbookCursor(null);
    if (option == null) return;
    final abort = _abort = Completer<void>();
    void failed(Object error) {
      if (_current(generation, scope)) _firstPageFailure(error);
    }

    try {
      final client = _schoolClient();
      await Future.wait<void>([
        fetchTeachingProgressOverview(
          client: client,
          classSubjectId: option.id,
          matterFallback: systemL10n().chapterFallback,
        ).then<void>((value) {
          if (_current(generation, scope)) progressOverview(value);
        }, onError: failed),
        fetchTeachingLogPage(
          client: client,
          option: option,
          recordedOnly: recordedOnly,
          abort: abort.future,
        ).then<void>((page) {
          if (_current(generation, scope)) {
            logbookEntries(page.items);
            logbookReady(true);
            nextLogbookCursor(page.nextCursor);
          }
        }, onError: failed),
      ]);
    } on Object catch (error) {
      failed(error);
    }
  }

  Future<void> loadMoreLogbook() async {
    final cursor = nextLogbookCursor.value;
    final option = selectedOption;
    final abort = _abort;
    final scope = _contextKey;
    if (loadingMore.value ||
        cursor == null ||
        option == null ||
        abort == null ||
        _displayedSelection != (scope, option.id)) {
      return;
    }
    final generation = _teachingGeneration;
    loadingMore(true);
    logbookPageError('');
    try {
      final page = await fetchTeachingLogPage(
        client: _schoolClient(),
        option: option,
        recordedOnly: recordedOnly,
        abort: abort.future,
        cursor: cursor,
      );
      if (!_current(generation, scope)) return;
      final seen = logbookEntries.value
          .map((entry) => entry.lessonSessionId)
          .toSet();
      logbookEntries([
        ...logbookEntries.value,
        ...page.items.where((entry) => seen.add(entry.lessonSessionId)),
      ]);
      nextLogbookCursor(page.nextCursor);
    } on Object catch (error) {
      if (!_current(generation, scope)) return;
      if (_denied(error)) {
        _firstPageFailure(error);
      } else {
        logbookPageError(systemL10n().couldNotLoadTeachingData('$error'));
      }
    } finally {
      if (_current(generation, scope)) loadingMore(false);
    }
  }
}
