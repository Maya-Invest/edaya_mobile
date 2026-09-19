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
  }) : _calendar = calendar,
       _academicYear = academicYear,
       _schoolClient = schoolClient,
       _outboxStore = outboxStore ?? openTeacherOutboxStore();

  final String sessionId;
  final LiveCalendarController _calendar;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;
  final TeacherOutboxStore _outboxStore;

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
    autoDispose(subjectMatters);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    autoDispose(pendingOutboxCount);
    autoDispose(
      _calendar.sessions.stream.listen((_) {
        session(_calendar.sessionById(sessionId));
      }),
    );
    session(_calendar.sessionById(sessionId));
    unawaited(load());
  }

  bool get supportsAttendanceRecording => session.value?.kind == 'lesson';

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

  int get minProgress {
    final matters = subjectMatters.value;
    if (matters.isEmpty) {
      return 0;
    }
    return minMatterProgressPercentage(matters.first);
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
        students(const []);
        return;
      }

      try {
        final client = _schoolClient();
        final enrollmentRows = await client.enrollments.list(
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
            : await client.students.list(entitiesByIds(studentIds));
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
    if (subjectMatters.value.isNotEmpty) {
      final matter = subjectMatters.value.first;
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
    final encodedNote = encodeStructuredSessionNote(structured);
    final matterById = {
      for (final matter in subjectMatters.value) matter.id: matter,
    };
    final recordedAt = DateTime.now();
    final progressOps = <Map<String, dynamic>>[];
    final client = _schoolClient();

    try {
      final lessonSession = await client.lessonSessions.get(current.id);
      final notePayload = lessonSessionNotePayload(
        lessonSession: lessonSession,
        sessionNote: encodedNote,
        displayLabelFallback: current.title,
      );
      for (final entry in progressEntries) {
        final matter = matterById[entry.matterId]!;
        final existing = matter.sessionProgress;
        if (isProgressCreate(existing)) {
          progressOps.add({
            'action': 'create',
            'payload': recordLessonProgressPayload(
              id: newProgressId(current.id),
              classSubjectMatterId: matter.id,
              lessonSessionId: current.id,
              completedPercentage: entry.completedPercentage,
              notes: entry.notes,
              recordedAt: recordedAt,
            ),
          });
        } else {
          final progressRow = await client.classSubjectProgress.get(
            existing!.id,
          );
          progressOps.add({
            'action': 'update',
            'payload': updateProgressPayload(
              existing: progressRow,
              completedPercentage: entry.completedPercentage,
              notes: entry.notes,
              recordedAt: recordedAt,
            ),
          });
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
      await SessionLogbookDraftStorage.clear(current.id);
      unawaited(_calendar.loadCalendarData());
      return true;
    } on Object catch (error) {
      return _enqueueLogbookFailure(
        encodedNote: encodedNote,
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
          if (subjectMatters.value.isNotEmpty)
            SessionLogbookDraftProgressEntry(
              matterId: subjectMatters.value.first.id,
              completedPercentage: progress,
              notes: '',
              isEditingExisting:
                  subjectMatters.value.first.hasSessionProgress,
            ),
        ],
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<int> syncPendingOutbox() async {
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
            state: TeacherOutboxState.failed,
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
    if (subjectMatters.value.isNotEmpty) {
      progressPercent(minMatterProgressPercentage(subjectMatters.value.first));
    } else {
      progressPercent(0);
    }
  }

  Future<void> _restoreDraft() async {
    final draft = await SessionLogbookDraftStorage.load(sessionId);
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
    required String encodedNote,
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
    final notePayload = {
      'id': current.id,
      'sessionNote': normalizeSessionNote(encodedNote),
      'displayLabel': current.title,
    };
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
