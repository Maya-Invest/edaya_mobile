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
    this.workflowVersion = 0,
    this.pendingCorrection,
  });

  final String studentId;
  final String fullName;
  final String initials;
  final String? photoUrl;
  final String? attendanceId;
  final AttendanceStatus? status;
  final String? reason;
  final String? notes;
  final int workflowVersion;
  final Map<String, dynamic>? pendingCorrection;

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
      workflowVersion: workflowVersion,
      pendingCorrection: pendingCorrection,
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
       _outboxContext = outboxContext;

  final String sessionId;
  final LiveCalendarController _calendar;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;
  final TeacherOutboxStore _outboxStore;
  final TeacherContextController? _teacherContext;
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
  final attendanceSubmitted = LxVar(false);
  final logbookValidated = LxVar(false);
  int _attendanceVersion = 0;
  int _logbookVersion = 0;
  Map<String, dynamic>? _logbookCorrection;
  final Map<String, int> _sessionProgress = {};

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
    autoDispose(attendanceSubmitted);
    autoDispose(logbookValidated);
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

  int get minProgress => 0;

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
        var studentRows = studentIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.students.listAll(entitiesByIds(studentIds));
        var attendanceRows = await listAttendanceForOccurrence(
          client.attendance,
          kind: current.kind,
          occurrenceId: current.id,
        );
        if (supportsAttendanceRecording) {
          final call = await client.runQuery('get-teacher-attendance-call', {
            'anchor': {'kind': 'lesson', 'lessonSessionId': current.id},
          });
          _attendanceVersion = (call['version'] as num).toInt();
          attendanceSubmitted(call['submitted'] as bool);
          final officialRoster = (call['students'] as List).cast<Map>();
          studentRows = [
            for (final student in officialRoster)
              {
                ...studentRows
                        .where((row) => row['id'] == student['id'])
                        .firstOrNull ??
                    {},
                ...Map<String, dynamic>.from(student),
              },
          ];
          attendanceRows =
              ((attendanceSubmitted.value ? call['records'] : call['entries'])
                      as List)
                  .map((row) => Map<String, dynamic>.from(row as Map))
                  .toList();
        }
        final attendanceByStudent = {
          for (final row in attendanceRows) row['studentId'] as String: row,
        };
        final roster = studentRows.map((row) {
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
            reason: attendance?['teacherExplanation'] as String?,
            workflowVersion:
                (attendance?['workflowVersion'] as num?)?.toInt() ?? 0,
            notes: attendance?['notes'] as String?,
          );
        }).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
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
        _sessionProgress.clear();
        for (final row in progressRows) {
          _sessionProgress[row['classSubjectMatterId'] as String] =
              (row['completedPercentage'] as num).toInt();
        }
        final lesson = await client.lessonSessions.get(current.id);
        final eligibility = await client.runQuery(
          'get-teacher-workflow-state',
          {
            'proposal': {
              'workflow': 'logbook',
              'targetId': current.id,
              'sessionNote': null,
              'progress': [],
            },
          },
        );
        _logbookVersion = (eligibility['version'] as num).toInt();
        logbookValidated(eligibility['locked'] as bool);
        _logbookCorrection = (eligibility['corrections'] as List)
            .cast<Map>()
            .where((r) => r['status'] == 'pending')
            .map((r) => Map<String, dynamic>.from(r))
            .firstOrNull;
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
    if (attendanceSubmitted.value) {
      saveMessage(systemL10n().marksCorrectionHint);
      return;
    }
    _patchStudent(studentId, status: status, reason: reason, notes: notes);
    final body = <String, dynamic>{
      'requestId': newSchoolRequestId(),
      'expectedVersion': _attendanceVersion,
      'anchor': {'kind': 'lesson', 'lessonSessionId': current.id},
      'entries': [
        for (final student in students.value)
          if (student.status != null)
            {
              'studentId': student.studentId,
              'status': student.status!.name,
              'notes': student.notes,
              'teacherExplanation': student.reason,
            },
      ],
    };
    final result = await _workflowCommand(
      'save-teacher-attendance-draft',
      body,
      TeacherOutboxKind.attendance,
      'attendance-call-${current.id}',
    );
    if (result != null) _attendanceVersion = (result['version'] as num).toInt();
  }

  Future<void> markAllPresent() async {
    if (attendanceSubmitted.value) return;
    final remaining = students.value
        .where((row) => row.status == null)
        .toList();
    if (remaining.isEmpty) return;
    for (final row in remaining) {
      _patchStudent(row.studentId, status: AttendanceStatus.present);
    }
    await setAttendanceStatus(
      remaining.first.studentId,
      AttendanceStatus.present,
    );
  }

  Future<void> completeAttendance() async {
    if (attendanceSubmitted.value) return;
    if (!attendanceComplete) {
      saveMessage(systemL10n().attendanceIncomplete);
      return;
    }
    await syncPendingOutbox();
    final pending = await _outboxStore.listPending();
    if (pending.any((entry) => entry.id == 'attendance-call-$sessionId')) {
      saveMessage(systemL10n().attendanceSubmitNeedsSync);
      return;
    }
    try {
      final client = _schoolClient();
      final call = await client.runQuery('get-teacher-attendance-call', {
        'anchor': {'kind': 'lesson', 'lessonSessionId': sessionId},
      });
      if (call['submitted'] == true) {
        attendanceSubmitted(true);
        return;
      }
      final result = await client.runCommand('submit-teacher-attendance', {
        'requestId': newSchoolRequestId(),
        'expectedVersion': call['version'],
        'anchor': {'kind': 'lesson', 'lessonSessionId': sessionId},
        'entries': [],
      });
      _attendanceVersion = (result['version'] as num).toInt();
      attendanceSubmitted(true);
      await load();
    } on Object catch (error) {
      saveMessage(systemL10n().couldNotSaveMark('$error'));
    }
  }

  bool get arrivalWindowActive {
    final current = session.value, now = DateTime.now();
    return current != null &&
        now.isAfter(current.startsAt) &&
        now.isBefore(current.endsAt);
  }

  Future<void> requestAttendanceCorrection(
    String studentId,
    AttendanceStatus status,
    String reason, {
    String? notes,
    String? teacherExplanation,
  }) async {
    final row = students.value
        .where((s) => s.studentId == studentId)
        .firstOrNull;
    if (row?.attendanceId == null) return;
    final proposal = <String, dynamic>{
      'workflow': 'attendance',
      'targetId': row!.attendanceId,
      'status': status.name,
      'notes': notes ?? row.notes,
      'teacherExplanation': teacherExplanation ?? row.reason,
    };
    final result = await _workflowCommand(
      row.pendingCorrection == null
          ? 'request-teacher-correction'
          : 'revise-teacher-correction',
      {
        'requestId': newSchoolRequestId(),
        if (row.pendingCorrection != null)
          'correctionId': row.pendingCorrection!['id'],
        'expectedVersion':
            row.pendingCorrection?['version'] ?? row.workflowVersion,
        'reason': reason,
        'proposal': proposal,
      },
      TeacherOutboxKind.correction,
      'attendance-correction-${row.attendanceId}',
    );
    if (result != null) await load();
  }

  Future<void> recordArrival(String studentId) async {
    final row = students.value
        .where((s) => s.studentId == studentId)
        .firstOrNull;
    if (row?.attendanceId == null) return;
    final result = await _workflowCommand(
      'record-teacher-attendance-arrival',
      {
        'requestId': newSchoolRequestId(),
        'recordId': row!.attendanceId,
        'expectedVersion': row.workflowVersion,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
      },
      TeacherOutboxKind.attendance,
      'arrival-${row.attendanceId}',
    );
    if (result != null) await load();
  }

  Future<Map<String, dynamic>?> _workflowCommand(
    String command,
    Map<String, dynamic> body,
    TeacherOutboxKind kind,
    String id,
  ) async {
    _outboxStore.bindContext(_outboxContext?.call());
    try {
      final result = await _schoolClient().runCommand(command, body);
      await _outboxStore.remove(id);
      saveMessage(
        kind == TeacherOutboxKind.correction
            ? systemL10n().workflowCorrectionPending
            : systemL10n().workflowSynced,
      );
      return result;
    } on Object catch (error) {
      final retryable = isRetryableTeacherWriteFailure(error);
      await _outboxStore.enqueue(
        buildTeacherOutboxEntry(
          id: id,
          kind: kind,
          idempotencyKey: id,
          payload: {'command': command, 'body': body},
          lastError: '$error',
          state: retryable
              ? TeacherOutboxState.pending
              : TeacherOutboxState.conflict,
        ),
      );
      pendingOutboxCount(await _outboxStore.pendingCount());
      saveMessage(
        retryable
            ? systemL10n().attendanceSavedLocally
            : systemL10n().couldNotSaveMark('$error'),
      );
      return null;
    }
  }

  Future<bool> saveLogbook({
    required String contentText,
    required String objectivesText,
    required String homeworkText,
    required String familySummaryText,
    required int progress,
    String? correctionReason,
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
    final mergedProgress = {
      ..._sessionProgress,
      for (final entry in progressEntries)
        entry.matterId: entry.completedPercentage,
    };
    final proposal = <String, dynamic>{
      'workflow': 'logbook',
      'targetId': current.id,
      'sessionNote': encodedNote,
      'progress': [
        for (final entry in mergedProgress.entries)
          {'matterId': entry.key, 'completedPercentage': entry.value},
      ],
    };
    if (logbookValidated.value && (correctionReason?.trim().isEmpty ?? true)) {
      return false;
    }
    final command = logbookValidated.value
        ? (_logbookCorrection == null
              ? 'request-teacher-correction'
              : 'revise-teacher-correction')
        : 'save-teacher-logbook';
    final body = <String, dynamic>{
      'requestId': newSchoolRequestId(),
      'expectedVersion': _logbookCorrection?['version'] ?? _logbookVersion,
      if (_logbookCorrection != null) 'correctionId': _logbookCorrection!['id'],
      'proposal': proposal,
      if (logbookValidated.value) 'reason': correctionReason,
    };
    final result = await _workflowCommand(
      command,
      body,
      logbookValidated.value
          ? TeacherOutboxKind.correction
          : TeacherOutboxKind.logbook,
      'logbook-${current.id}',
    );
    if (result == null) return false;
    if (logbookValidated.value) _logbookCorrection = result;
    if (!logbookValidated.value) {
      _logbookVersion = (result['version'] as num).toInt();
      _sessionProgress
        ..clear()
        ..addAll(mergedProgress);
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
    }
    return true;
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
      final body = entry.payload['body'] as Map?;
      final anchor = body?['anchor'] as Map?;
      final proposal = body?['proposal'] as Map?;
      final lessonSessionId =
          anchor?['lessonSessionId'] as String? ??
          proposal?['targetId'] as String? ??
          entry.payload['lessonSessionId'] as String? ??
          (entry.payload['notePayload'] is Map
              ? (entry.payload['notePayload'] as Map)['id'] as String?
              : null);
      final matchesSession = switch (entry.kind) {
        TeacherOutboxKind.attendance =>
          (lessonSessionId == sessionId ||
                  students.value.any(
                    (row) => row.attendanceId == body?['recordId'],
                  )) &&
              supportsAttendanceRecording,
        TeacherOutboxKind.logbook =>
          lessonSessionId == sessionId && supportsLogbook,
        TeacherOutboxKind.correction => lessonSessionId == sessionId,
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
    String? attendanceId,
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
    if (session.classSubjectId != null)
      'classSubjectId': session.classSubjectId,
    'startsAt': session.startsAt.toUtc().toIso8601String(),
    'endsAt': session.endsAt.toUtc().toIso8601String(),
    'displayLabel': session.title,
    'sessionNote': normalizeSessionNote(sessionNote),
  };
}
