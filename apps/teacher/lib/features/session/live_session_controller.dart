import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../live/entity_queries.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../calendar/live_calendar_controller.dart';
import '../calendar/teacher_session.dart';
import '../context/academic_year_controller.dart';
import '../context/teacher_context_controller.dart';
import 'session_logbook_draft_storage.dart';
import 'session_logbook_logic.dart';

class LiveSessionStudent {
  const LiveSessionStudent({
    required this.studentId,
    required this.fullName,
    required this.initials,
    this.photoUrl,
    this.attendanceId,
    this.status,
    this.reason,
    this.notes,
  });

  final String studentId;
  final String fullName;
  final String initials;
  final String? photoUrl;
  final String? attendanceId;
  final AttendanceStatus? status;
  final String? reason;
  final String? notes;

  LiveSessionStudent copyWith({
    String? attendanceId,
    AttendanceStatus? status,
    String? reason,
    String? notes,
  }) {
    return LiveSessionStudent(
      studentId: studentId,
      fullName: fullName,
      initials: initials,
      photoUrl: photoUrl,
      attendanceId: attendanceId ?? this.attendanceId,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
    );
  }
}

class LiveSessionController extends LevitController
    with LevitReactiveTasksMixin {
  LiveSessionController({
    required this.sessionId,
    required LiveCalendarController calendar,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
    TeacherOutboxStore? outboxStore,
    TeacherContextController? teacherContext,
    String? Function()? schoolId,
    TeacherOutboxContext? Function()? outboxContext,
  }) : _calendar = calendar,
       _academicYear = academicYear,
       _schoolClient = schoolClient,
       _outboxStore = outboxStore ?? openTeacherOutboxStore(),
       _teacherContext = teacherContext,
       _schoolId = schoolId,
       _outboxContext = outboxContext;

  final String sessionId;
  final LiveCalendarController _calendar;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;
  final TeacherOutboxStore _outboxStore;
  final TeacherContextController? _teacherContext;
  final String? Function()? _schoolId;
  final TeacherOutboxContext? Function()? _outboxContext;

  final session = LxVar<TeacherSession?>(null);
  final students = LxVar<List<LiveSessionStudent>>(const []);
  final content = LxVar('');
  final objectives = LxVar('');
  final homework = LxVar('');
  final familySummary = LxVar('');
  final progressPercent = LxVar(0);
  final subjectMatters = LxVar<List<SessionSubjectMatterOption>>(const []);
  final errorMessage = LxVar('');
  final saveMessage = LxVar('');
  final pendingOutboxCount = LxVar(0);

  @override
  void onInit() {
    super.onInit();
    autoDispose(session);
    autoDispose(students);
    autoDispose(content);
    autoDispose(objectives);
    autoDispose(homework);
    autoDispose(familySummary);
    autoDispose(progressPercent);
    autoDispose(selectedMatterId);
    autoDispose(subjectMatters);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    autoDispose(pendingOutboxCount);
    autoDispose(
      _calendar.sessions.stream.listen((_) {
        final refreshed = _calendar.sessionById(sessionId);
        // A detail route can refer to a lesson outside the calendar's current
        // week. Refreshing that week must not discard a lesson loaded by ID.
        if (refreshed != null) session(refreshed);
      }),
    );
    session(_calendar.sessionById(sessionId));
    unawaited(load());
  }

  bool get supportsAttendanceRecording {
    final current = session.value;
    if (current == null || current.kind != 'lesson') {
      return false;
    }
    final context = _teacherContext;
    if (context == null) {
      return true;
    }
    final subjectId = current.classSubjectId;
    if (subjectId == null) {
      return false;
    }
    return context.taughtClassSubjectIds.value.contains(subjectId);
  }

  bool get supportsLogbook => session.value?.kind == 'lesson';

  bool get attendanceComplete {
    final roster = students.value;
    if (roster.isEmpty) {
      return false;
    }
    return roster.every((row) => row.status != null);
  }

  bool get logbookComplete {
    return decodeStructuredSessionNote(
      encodeStructuredSessionNote(
        StructuredLogbookContent(
          content: content.value,
          objectives: objectives.value
              .split('\n')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
          homework: homework.value,
          familySummary: familySummary.value,
        ),
      ),
    ).isComplete;
  }

  SessionSubjectMatterOption? get _selectedMatter {
    final matters = subjectMatters.value;
    if (matters.isEmpty) {
      return null;
    }
    final selected = selectedMatterId.value;
    if (selected == null) {
      return matters.first;
    }
    for (final matter in matters) {
      if (matter.id == selected) {
        return matter;
      }
    }
    return matters.first;
  }

  final selectedMatterId = LxVar<String?>(null);

  int get minProgress {
    final matter = _selectedMatter;
    if (matter == null) {
      return 0;
    }
    return minMatterProgressPercentage(matter);
  }

  void selectMatter(String matterId) {
    selectedMatterId(matterId);
    final matter = _selectedMatter;
    if (matter != null) {
      progressPercent(minMatterProgressPercentage(matter));
    }
  }

  Future<void> load() async {
    errorMessage('');
    await runTask(() async {
      await syncPendingOutbox();
      var current = _calendar.sessionById(sessionId);
      if (current == null) {
        await _calendar.loadCalendarData();
        current = _calendar.sessionById(sessionId);
      }
      session(current);
      if (current == null) {
        current = await _loadSessionById();
        session(current);
      }
      if (current == null) {
        students(const []);
        return;
      }

      try {
        final client = _schoolClient();
        final enrollmentRows = await client.enrollments.listAll(
          activeEnrollmentsForClass(
            current.classGroupId,
            academicYearId: _academicYear.selectedYearId.value,
          ),
        );
        final studentIds = enrollmentRows
            .map((row) => row['studentId'] as String?)
            .whereType<String>()
            .toList();
        final studentRows = studentIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.students.listAll(entitiesByIds(studentIds));
        final attendanceRows = await listAttendanceForOccurrence(
          client.attendance,
          kind: current.kind,
          occurrenceId: current.id,
        );
        final attendanceByStudent = {
          for (final row in attendanceRows) row['studentId'] as String: row,
        };
        final roster =
            studentRows.map((row) {
              final studentId = row['id'] as String;
              final firstName = row['firstName'] as String? ?? '';
              final lastName = row['lastName'] as String? ?? '';
              final fullName = '$firstName $lastName'.trim();
              final displayName = fullName.isEmpty ? studentId : fullName;
              final attendance = attendanceByStudent[studentId];
              return LiveSessionStudent(
                studentId: studentId,
                fullName: displayName,
                initials: personInitials(displayName),
                photoUrl: row['photoUrl'] as String?,
                attendanceId: attendance?['id'] as String?,
                status: _statusFromApi(attendance?['status'] as String?),
                reason: attendance?['reason'] as String?,
                notes: attendance?['notes'] as String?,
              );
            }).toList()
              ..sort((a, b) => a.fullName.compareTo(b.fullName));
        students(roster);

        if (!supportsLogbook || current.classSubjectId == null) {
          content('');
          objectives('');
          homework('');
          familySummary('');
          progressPercent(0);
          subjectMatters(const []);
          return;
        }

        final classSubjectId = current.classSubjectId!;
        final matterLinks = await client.classSubjectMatters.list({
          'classSubjectId': classSubjectId,
        });
        final matterIds = matterLinks
            .map((row) => row['subjectMatterId'] as String?)
            .whereType<String>()
            .toList();
        final matters = matterIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.subjectMatters.list(entitiesByIds(matterIds));
        final progressRows = await client.classSubjectProgress.list(
          progressForLessonSessions([current.id]),
        );
        final lesson = await client.lessonSessions.get(current.id);
        subjectMatters(
          buildSessionSubjectMatters(
            matterLinks: matterLinks,
            subjectMatters: matters,
            sessionProgressRows: progressRows,
            fallbackName: systemL10n().chapterFallback,
          ),
        );
        _applySessionNote(lesson['sessionNote'] as String?);
        await _restoreDraft();
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadSession('$error'));
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadSession('$error'));
      }
    });
  }

  Future<void> setAttendanceStatus(
    String studentId,
    AttendanceStatus status, {
    String? reason,
    String? notes,
  }) async {
    final current = session.value;
    final row = students.value
        .where((item) => item.studentId == studentId)
        .firstOrNull;
    if (current == null || row == null) {
      return;
    }
    if (!supportsAttendanceRecording) {
      saveMessage(systemL10n().attendanceRecordingLessonOnly);
      return;
    }
    saveMessage('');
    _outboxStore.bindContext(_outboxContext?.call());
    final attendanceId = row.attendanceId ?? '${row.studentId}-${current.id}';
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final payload = attendanceRecordPayload(
      kind: current.kind,
      occurrenceId: current.id,
      studentId: row.studentId,
      attendanceId: attendanceId,
      status: status.name,
      createdAt: createdAt,
      reason: reason,
      notes: notes,
    );
    try {
      await _schoolClient().recordAttendance(payload);
      await _removeAttendanceOutbox(row.studentId);
      _patchStudent(
        studentId,
        attendanceId: attendanceId,
        status: status,
        reason: reason,
        notes: notes,
      );
      unawaited(_calendar.loadCalendarData());
    } on Object catch (error) {
      if (!isRetryableTeacherWriteFailure(error)) {
        saveMessage(systemL10n().couldNotSaveMark('$error'));
        return;
      }
      await _enqueueAttendanceFailure(
        row: row,
        status: status,
        reason: reason,
        notes: notes,
        attendanceId: attendanceId,
        createdAt: createdAt,
        error: '$error',
      );
    }
  }

  Future<void> markAllPresent() async {
    for (final row in students.value) {
      if (row.status == AttendanceStatus.present) {
        continue;
      }
      await setAttendanceStatus(row.studentId, AttendanceStatus.present);
    }
  }

  Future<void> completeAttendance() async {
    for (final row in students.value) {
      if (row.status != null) {
        continue;
      }
      await setAttendanceStatus(row.studentId, AttendanceStatus.present);
    }
  }

  Future<bool> saveLogbook({
    required String contentText,
    required String objectivesText,
    required String homeworkText,
    required String familySummaryText,
    required int progress,
  }) async {
    final current = session.value;
    if (current == null || !supportsLogbook || current.classSubjectId == null) {
      return false;
    }

    final structured = StructuredLogbookContent(
      content: contentText,
      objectives: objectivesText
          .split('\n')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      homework: homeworkText,
      familySummary: familySummaryText,
    );
    final progressEntries = <LogbookProgressDraft>[];
    final matter = _selectedMatter;
    if (matter != null) {
      final minimum = minMatterProgressPercentage(matter);
      if (progress < minimum) {
        saveMessage(systemL10n().progressMustNotDecrease(minimum));
        return false;
      }
      progressEntries.add(
        LogbookProgressDraft(
          matterId: matter.id,
          completedPercentage: progress,
        ),
      );
    }

    saveMessage('');
    _outboxStore.bindContext(_outboxContext?.call());
    final encodedNote = encodeStructuredSessionNote(structured);
    final matterById = {
      for (final matter in subjectMatters.value) matter.id: matter,
    };
    final recordedAt = DateTime.now();
    final schoolId = _schoolId?.call();
    final progressOps = progressOperationsForLogbook(
      sessionId: current.id,
      entries: progressEntries,
      matterById: matterById,
      recordedAt: recordedAt,
    );
    final offlineNote = offlineLessonSessionPayload(
      session: current,
      schoolId: schoolId,
      sessionNote: encodedNote,
    );
    final client = _schoolClient();

    try {
      var notePayload = offlineNote;
      try {
        final lessonSession = await client.lessonSessions.get(current.id);
        notePayload = lessonSessionNotePayload(
          lessonSession: lessonSession,
          sessionNote: encodedNote,
          displayLabelFallback: current.title,
        );
      } on Object {
        if (!_offlineLessonPayloadIsComplete(offlineNote)) {
          rethrow;
        }
      }

      await client.lessonSessions.save(notePayload);
      for (final op in progressOps) {
        final action = op['action'] as String;
        final payload = op['payload'] as Map<String, dynamic>;
        if (action == 'create') {
          await client.recordLessonSessionProgress(payload);
        } else {
          await client.classSubjectProgress.save(payload);
        }
      }

      content(contentText);
      objectives(objectivesText);
      homework(homeworkText);
      familySummary(familySummaryText);
      progressPercent(progress);
      await SessionLogbookDraftStorage.clear(
        current.id,
        context: _outboxContext?.call(),
      );
      unawaited(_calendar.loadCalendarData());
      return true;
    } on Object catch (error) {
      if (!isRetryableTeacherWriteFailure(error) ||
          !_offlineLessonPayloadIsComplete(offlineNote)) {
        saveMessage(systemL10n().couldNotSaveMark('$error'));
        return false;
      }
      return _enqueueLogbookFailure(
        notePayload: offlineNote,
        progressOps: progressOps,
        error: '$error',
        contentText: contentText,
        objectivesText: objectivesText,
        homeworkText: homeworkText,
        familySummaryText: familySummaryText,
        progress: progress,
      );
    }
  }

  Future<void> persistDraft({
    required String contentText,
    required String objectivesText,
    required String homeworkText,
    required String familySummaryText,
    required int progress,
  }) async {
    await SessionLogbookDraftStorage.save(
      sessionId,
      SessionLogbookDraft(
        sessionNote: contentText,
        objectives: objectivesText,
        homework: homeworkText,
        familySummary: familySummaryText,
        progressEntries: [
          if (_selectedMatter != null)
            SessionLogbookDraftProgressEntry(
              matterId: _selectedMatter!.id,
              completedPercentage: progress,
              notes: '',
              isEditingExisting: _selectedMatter!.hasSessionProgress,
            ),
        ],
        updatedAt: DateTime.now(),
      ),
      context: _outboxContext?.call(),
    );
  }

  Future<int> syncPendingOutbox() async {
    _outboxStore.bindContext(_outboxContext?.call());
    final pending = await _outboxStore.listPending();
    var syncedCount = 0;
    final client = _schoolClient();
    for (final entry in pending) {
      final lessonSessionId =
          entry.payload['lessonSessionId'] as String? ??
          (entry.payload['notePayload'] is Map
              ? (entry.payload['notePayload'] as Map)['id'] as String?
              : null);
      final matchesSession = switch (entry.kind) {
        TeacherOutboxKind.attendance =>
          (entry.payload['lessonSessionId'] as String?) == sessionId &&
              supportsAttendanceRecording,
        TeacherOutboxKind.logbook =>
          lessonSessionId == sessionId && supportsLogbook,
        _ => false,
      };
      if (!matchesSession) {
        continue;
      }
      try {
        await syncTeacherOutboxEntry(client, entry);
        await _outboxStore.remove(entry.id);
        syncedCount++;
      } on Object catch (error) {
        await _outboxStore.upsert(
          entry.copyWith(
            state: isRetryableTeacherWriteFailure(error)
                ? TeacherOutboxState.failed
                : TeacherOutboxState.rejected,
            attemptCount: entry.attemptCount + 1,
            lastError: '$error',
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
    pendingOutboxCount(await _outboxStore.pendingCount());
    return syncedCount;
  }

  void _applySessionNote(String? raw) {
    final decoded = decodeStructuredSessionNote(raw);
    content(decoded.content);
    objectives(decoded.objectives.join('\n'));
    homework(decoded.homework ?? '');
    familySummary(decoded.familySummary ?? '');
    final matter = _selectedMatter;
    if (matter != null) {
      progressPercent(minMatterProgressPercentage(matter));
    } else {
      progressPercent(0);
    }
  }

  Future<void> _restoreDraft() async {
    final draft = await SessionLogbookDraftStorage.load(
      sessionId,
      context: _outboxContext?.call(),
    );
    if (draft == null) {
      return;
    }
    content(draft.sessionNote);
    objectives(draft.objectives);
    homework(draft.homework);
    familySummary(draft.familySummary);
    if (draft.progressEntries.isNotEmpty) {
      progressPercent(draft.progressEntries.first.completedPercentage);
    }
  }

  void _patchStudent(
    String studentId, {
    required String attendanceId,
    required AttendanceStatus status,
    String? reason,
    String? notes,
  }) {
    students([
      for (final item in students.value)
        if (item.studentId == studentId)
          item.copyWith(
            attendanceId: attendanceId,
            status: status,
            reason: reason,
            notes: notes,
          )
        else
          item,
    ]);
  }

  Future<void> _enqueueAttendanceFailure({
    required LiveSessionStudent row,
    required AttendanceStatus status,
    required String? reason,
    required String? notes,
    required String attendanceId,
    required String createdAt,
    required String error,
  }) async {
    final current = session.value;
    if (current == null) {
      return;
    }
    final payload = attendanceRecordPayload(
      kind: current.kind,
      occurrenceId: current.id,
      studentId: row.studentId,
      attendanceId: attendanceId,
      status: status.name,
      createdAt: createdAt,
      reason: reason,
      notes: notes,
    );
    final now = DateTime.now();
    await _outboxStore.enqueue(
      TeacherOutboxEntry(
        id: attendanceId,
        kind: TeacherOutboxKind.attendance,
        idempotencyKey: teacherAttendanceIdempotencyKey(
          occurrenceId: current.id,
          studentId: row.studentId,
        ),
        payload: payload,
        state: TeacherOutboxState.pending,
        attemptCount: 1,
        lastError: error,
        createdAt: now,
        updatedAt: now,
      ),
    );
    _patchStudent(
      row.studentId,
      attendanceId: attendanceId,
      status: status,
      reason: reason,
      notes: notes,
    );
    saveMessage(systemL10n().attendanceSavedLocally);
    pendingOutboxCount(await _outboxStore.pendingCount());
  }

  Future<void> _removeAttendanceOutbox(String studentId) async {
    final pending = await _outboxStore.listPending();
    for (final entry in pending) {
      if (entry.kind == TeacherOutboxKind.attendance &&
          entry.payload['studentId'] == studentId &&
          entry.payload['lessonSessionId'] == sessionId) {
        await _outboxStore.remove(entry.id);
      }
    }
    pendingOutboxCount(await _outboxStore.pendingCount());
  }

  Future<bool> _enqueueLogbookFailure({
    required Map<String, dynamic> notePayload,
    required List<Map<String, dynamic>> progressOps,
    required String error,
    required String contentText,
    required String objectivesText,
    required String homeworkText,
    required String familySummaryText,
    required int progress,
  }) async {
    final current = session.value;
    if (current == null) {
      return false;
    }
    await _outboxStore.enqueue(
      buildTeacherOutboxEntry(
        id: 'logbook-${current.id}-${DateTime.now().millisecondsSinceEpoch}',
        kind: TeacherOutboxKind.logbook,
        idempotencyKey: teacherLogbookIdempotencyKey(
          lessonSessionId: current.id,
        ),
        payload: {
          'lessonSessionId': current.id,
          ...logbookOutboxPayload(
            notePayload: notePayload,
            progressOps: progressOps,
          ),
        },
        lastError: error,
      ),
    );
    content(contentText);
    objectives(objectivesText);
    homework(homeworkText);
    familySummary(familySummaryText);
    progressPercent(progress);
    saveMessage(systemL10n().attendanceSavedLocally);
    pendingOutboxCount(await _outboxStore.pendingCount());
    return true;
  }

  Future<TeacherSession?> _loadSessionById() async {
    try {
      final lesson = await _schoolClient().lessonSessions.get(sessionId);
      final startsAt = DateTime.tryParse('${lesson['startsAt']}');
      final endsAt = DateTime.tryParse('${lesson['endsAt']}');
      if (startsAt == null || endsAt == null) {
        return null;
      }
      return TeacherSession(
        id: lesson['id'] as String? ?? sessionId,
        title: lesson['displayLabel'] as String? ?? sessionId,
        kind: 'lesson',
        startsAt: startsAt,
        endsAt: endsAt,
        classGroupId: lesson['classGroupId'] as String? ?? '',
        classLabel: lesson['classGroupId'] as String? ?? '',
        subjectLabel: '',
        classSubjectId: lesson['classSubjectId'] as String?,
        status: lesson['status'] as String?,
      );
    } on Object {
      return null;
    }
  }

  AttendanceStatus? _statusFromApi(String? value) {
    return switch (value) {
      'present' => AttendanceStatus.present,
      'absent' => AttendanceStatus.absent,
      'late' => AttendanceStatus.late,
      'excused' => AttendanceStatus.excused,
      _ => null,
    };
  }
}

Map<String, dynamic> offlineLessonSessionPayload({
  required TeacherSession session,
  required String? schoolId,
  required String sessionNote,
}) {
  return {
    'id': session.id,
    if (schoolId != null && schoolId.isNotEmpty) 'schoolId': schoolId,
    'classGroupId': session.classGroupId,
    if (session.classSubjectId != null) 'classSubjectId': session.classSubjectId,
    'startsAt': session.startsAt.toUtc().toIso8601String(),
    'endsAt': session.endsAt.toUtc().toIso8601String(),
    'displayLabel': session.title,
    'sessionNote': normalizeSessionNote(sessionNote),
  };
}

bool _offlineLessonPayloadIsComplete(Map<String, dynamic> note) {
  for (final key in const [
    'schoolId',
    'classGroupId',
    'classSubjectId',
    'startsAt',
    'endsAt',
  ]) {
    final value = note[key];
    if (value == null || (value is String && value.isEmpty)) {
      return false;
    }
  }
  return true;
}

List<Map<String, dynamic>> progressOperationsForLogbook({
  required String sessionId,
  required List<LogbookProgressDraft> entries,
  required Map<String, SessionSubjectMatterOption> matterById,
  required DateTime recordedAt,
}) {
  final operations = <Map<String, dynamic>>[];
  for (final entry in entries) {
    final matter = matterById[entry.matterId];
    if (matter == null) {
      continue;
    }
    final existing = matter.sessionProgress;
    if (isProgressCreate(existing)) {
      operations.add({
        'action': 'create',
        'payload': recordLessonProgressPayload(
          id: newProgressId(sessionId),
          classSubjectMatterId: matter.id,
          lessonSessionId: sessionId,
          completedPercentage: entry.completedPercentage,
          notes: entry.notes,
          recordedAt: recordedAt,
        ),
      });
      continue;
    }
    operations.add({
      'action': 'update',
      'payload': {
        'id': existing!.id,
        'classSubjectMatterId': matter.id,
        'lessonSessionId': sessionId,
        'completedPercentage': entry.completedPercentage,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        if (entry.notes != null && entry.notes!.trim().isNotEmpty)
          'notes': entry.notes,
      },
    });
  }
  return operations;
}
