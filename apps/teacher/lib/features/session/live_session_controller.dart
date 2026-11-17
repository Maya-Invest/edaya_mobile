import 'dart:convert';
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
import 'attendance_draft_queue.dart';
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
    this.departedAt,
    this.justification,
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
  final DateTime? departedAt;
  final String? justification;

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
      departedAt: departedAt,
      justification: justification,
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
  final subjectMatters = LxVar<List<SessionSubjectMatterOption>>(const []);
  final errorMessage = LxVar('');
  final saveMessage = LxVar('');
  final logbookMessage = LxVar('');
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
    autoDispose(subjectMatters);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    autoDispose(logbookMessage);
    autoDispose(pendingOutboxCount);
    autoDispose(attendanceSubmitted);
    autoDispose(draftWrites.writing);
    autoDispose(attendanceError);
    autoDispose(logbookError);
    autoDispose(draftPending);
    autoDispose(draftConflict);
    autoDispose(logbookDrafts);
    autoDispose(officialLogbook);
    autoDispose(pendingLogbook);
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

  String subjectFor(TeacherSession session) {
    return _teacherContext?.assignments.value
            .where(
              (a) =>
                  a.classSubjectId != null &&
                  a.classSubjectId == session.classSubjectId,
            )
            .firstOrNull
            ?.subjectLabel ??
        session.subjectLabel;
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

  Map<String, int> get _proposedProgress => {
    for (final entry
        in (pendingLogbook.value?['progress'] as List? ?? const [])
            .whereType<Map>())
      entry['matterId'] as String: (entry['completedPercentage'] as num)
          .toInt(),
  };

  Map<String, int> get savedChapterProgress =>
      Map.unmodifiable(_sessionProgress);
  Map<String, int> get editableChapterProgress =>
      pendingLogbook.value == null ? savedChapterProgress : _proposedProgress;
  String? _officialNote;
  String? get _editableNote => pendingLogbook.value == null
      ? _officialNote
      : pendingLogbook.value!['sessionNote'] as String?;
  String get correctionReason => _logbookCorrection?['reason'] as String? ?? '';
  int? get _proposalVersion => _logbookCorrection?['version'] as int?;

  final attendanceError = LxVar('');
  final logbookError = LxVar('');
  Future<void>? _loading;
  Future<void> load() =>
      _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    errorMessage('');
    attendanceError('');
    logbookError('');
    await runTask(() async {
      try {
        await syncPendingOutbox();
        final current =
            _calendar.sessionById(sessionId) ??
            session.value ??
            await _loadSessionById();
        if (isClosed) return;
        session(current);
        if (current == null) return;
        final client = _schoolClient();
        await Future.wait([
          _loadAttendance(current, client).catchError((Object error) {
            if (!isClosed)
              attendanceError(systemL10n().couldNotLoadSession('$error'));
          }),
          _loadLogbook(current, client).catchError((Object error) {
            if (!isClosed)
              logbookError(systemL10n().couldNotLoadSession('$error'));
          }),
        ]);
      } on Object catch (error) {
        if (!isClosed) errorMessage(systemL10n().couldNotLoadSession('$error'));
      }
    });
  }

  Future<void> _loadAttendance(
    TeacherSession current,
    api.SchoolClient client,
  ) async {
    List<Map<String, dynamic>> studentRows;
    List<Map<String, dynamic>> attendanceRows;
    if (supportsAttendanceRecording) {
      final call = await client.runQuery('get-teacher-attendance-call', {
        'anchor': {'kind': 'lesson', 'lessonSessionId': current.id},
      });
      _attendanceVersion = (call['version'] as num).toInt();
      attendanceSubmitted(call['submitted'] as bool);
      studentRows = (call['students'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      if (studentRows.isNotEmpty) {
        try {
          final details = await client.students.listAll(
            entitiesByIds(
              studentRows.map((row) => row['id'] as String).toList(),
            ),
          );
          final photos = {
            for (final row in details) row['id']: row['photoUrl'],
          };
          for (final row in studentRows) {
            row['photoUrl'] = photos[row['id']];
          }
        } on Object {
          // Portrait enrichment must not hide an authorized historical roster.
        }
      }
      attendanceRows =
          ((attendanceSubmitted.value ? call['records'] : call['entries'])
                  as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
    } else {
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
      studentRows = studentIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await client.students.listAll(entitiesByIds(studentIds));
      attendanceRows = await listAttendanceForOccurrence(
        client.attendance,
        kind: current.kind,
        occurrenceId: current.id,
      );
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
        workflowVersion: (attendance?['workflowVersion'] as num?)?.toInt() ?? 0,
        pendingCorrection: (attendance?['pendingCorrection'] as Map?)
            ?.cast<String, dynamic>(),
        departedAt: DateTime.tryParse(
          attendance?['departedAt']?.toString() ?? '',
        ),
        justification: attendance?['justificationStatus'] as String?,
        notes: attendance?['notes'] as String?,
      );
    }).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
    students(roster);
    final queued = (await _outboxStore.listPending())
        .where((entry) => entry.id == 'attendance-call-$sessionId')
        .firstOrNull;
    draftPending(queued != null && !attendanceSubmitted.value);
    draftConflict(queued != null && !teacherOutboxEntryIsReplayable(queued));
    if (queued != null &&
        !attendanceSubmitted.value &&
        teacherOutboxEntryIsReplayable(queued)) {
      final entries = ((queued.payload['body'] as Map)['entries'] as List)
          .cast<Map>();
      for (final entry in entries) {
        final status = _statusFromApi(entry['status'] as String?);
        if (status != null)
          _patchStudent(
            entry['studentId'] as String,
            status: status,
            reason: entry['teacherExplanation'] as String?,
            notes: entry['notes'] as String?,
          );
      }
    }
  }

  Future<void> _loadLogbook(
    TeacherSession current,
    api.SchoolClient client,
  ) async {
    if (!supportsLogbook || current.classSubjectId == null) {
      subjectMatters(const []);
      return;
    }

    final classSubjectId = current.classSubjectId!;
    final matterLinks = await client.classSubjectMatters.listAll({
      'classSubjectId': classSubjectId,
    });
    final matterIds = matterLinks
        .map((row) => row['subjectMatterId'] as String?)
        .whereType<String>()
        .toList();
    final matters = matterIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await client.subjectMatters.listAll(entitiesByIds(matterIds));
    final eligibility = await client.runQuery('get-teacher-workflow-state', {
      'proposal': {
        'workflow': 'logbook',
        'targetId': current.id,
        'sessionNote': null,
        'progress': [],
      },
    });
    final official = eligibility['official'] as Map;
    _sessionProgress
      ..clear()
      ..addEntries(
        (official['progress'] as List).whereType<Map>().map(
          (row) => MapEntry(
            row['matterId'] as String,
            (row['completedPercentage'] as num).toInt(),
          ),
        ),
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
        fallbackName: systemL10n().chapterFallback,
      ),
    );
    _officialNote = official['sessionNote'] as String?;
    officialLogbook(decodeStructuredSessionNote(_officialNote));
    pendingLogbook(
      (_logbookCorrection?['proposal'] as Map?)?.cast<String, dynamic>(),
    );
    await _draftWrite;
    logbookDrafts(
      await SessionLogbookDraftStorage.load(
        sessionId,
        _outboxContext?.call(),
        _logbookVersion,
        _proposalVersion,
        prefix: schoolStoragePrefix(_schoolClient()),
      ),
    );
  }

  final draftPending = LxVar(false);
  final draftConflict = LxVar(false);
  final logbookDrafts = LxVar<Map<String, LogbookEdit>>({});
  final officialLogbook = LxVar<StructuredLogbookContent?>(null);
  final pendingLogbook = LxVar<Map<String, dynamic>?>(null);
  DateTime schoolTime(DateTime instant) =>
      _teacherContext?.schoolTime(instant) ?? instant.toLocal();
  final draftWrites = AttendanceDraftQueue();

  Future<bool> setAttendanceStatus(
    String studentId,
    AttendanceStatus status, {
    String? reason,
    String? notes,
  }) => draftWrites.add(
    () =>
        _saveAttendanceStatus(studentId, status, reason: reason, notes: notes),
    active: () => !isClosed,
  );

  Future<bool> _saveAttendanceStatus(
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
      return false;
    }
    if (!supportsAttendanceRecording) {
      saveMessage(systemL10n().attendanceRecordingLessonOnly);
      return false;
    }
    saveMessage('');
    if (attendanceSubmitted.value) {
      saveMessage(systemL10n().attendanceCorrectionHint);
      return false;
    }
    final previous = students.value;
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
    draftPending(result == null);
    draftConflict(false);
    if (result != null) {
      _attendanceVersion = (result['version'] as num).toInt();
      return true;
    }
    final queued = (await _outboxStore.listPending())
        .where((entry) => entry.id == 'attendance-call-$sessionId')
        .firstOrNull;
    if (queued != null && teacherOutboxEntryIsReplayable(queued)) return true;
    students(previous);
    draftConflict(true);
    return false;
  }

  Future<void> markAllPresent() async {
    if (attendanceSubmitted.value) return;
    final remaining = students.value
        .where((row) => row.status == null)
        .toList();
    if (remaining.isEmpty) return;
    final previous = students.value;
    students([
      for (final row in previous)
        if (row.status == null)
          row.copyWith(status: AttendanceStatus.present)
        else
          row,
    ]);
    final saved = await setAttendanceStatus(
      remaining.first.studentId,
      AttendanceStatus.present,
    );
    if (!saved) students(previous);
  }

  Future<void> completeAttendance() async {
    await draftWrites.settled;
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
      if (call['version'] != _attendanceVersion) {
        await load();
        saveMessage(systemL10n().rollRegisterChanged);
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
    } on Object {
      saveMessage(systemL10n().attendanceSubmitFailed);
    }
  }

  bool get arrivalWindowActive {
    final current = session.value, now = SchoolClock.now();
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

  Future<bool> recordArrival(String studentId) =>
      _recordMovement(studentId, departure: false);
  Future<bool> recordDeparture(String studentId) =>
      _recordMovement(studentId, departure: true);
  Future<bool> _recordMovement(
    String studentId, {
    required bool departure,
  }) async {
    final row = students.value
        .where((s) => s.studentId == studentId)
        .firstOrNull;
    if (row?.attendanceId == null) return false;
    final id = '${departure ? 'departure' : 'arrival'}-${row!.attendanceId}';
    final queued = (await _outboxStore.listPending())
        .where(
          (entry) => entry.id == id && teacherOutboxEntryIsReplayable(entry),
        )
        .firstOrNull;
    final result = await _workflowCommand(
      departure
          ? 'record-teacher-attendance-departure'
          : 'record-teacher-attendance-arrival',
      (queued?.payload['body'] as Map?)?.cast<String, dynamic>() ??
          {
            'requestId': newSchoolRequestId(),
            'recordId': row.attendanceId,
            'expectedVersion': row.workflowVersion,
            'occurredAt': SchoolClock.now().toUtc().toIso8601String(),
          },
      TeacherOutboxKind.attendance,
      id,
    );
    if (result != null) await load();
    return result != null ||
        saveMessage.value == systemL10n().attendanceSavedLocally;
  }

  Future<Map<String, dynamic>?> _workflowCommand(
    String command,
    Map<String, dynamic> body,
    TeacherOutboxKind kind,
    String id, {
    String? logbookSection,
  }) async {
    final feedback = logbookSection == null ? saveMessage : logbookMessage;
    _outboxStore.bindContext(_outboxContext?.call());
    try {
      final result = await _schoolClient().runCommand(command, body);
      await _outboxStore.remove(id);
      feedback(
        kind == TeacherOutboxKind.correction
            ? systemL10n().workflowCorrectionPending
            : '',
      );
      return result;
    } on Object catch (error) {
      final retryable = isRetryableTeacherWriteFailure(error);
      await _outboxStore.enqueue(
        buildTeacherOutboxEntry(
          id: id,
          kind: kind,
          idempotencyKey: id,
          payload: {
            'command': command,
            'body': body,
            if (logbookSection != null) 'section': logbookSection,
          },
          lastError: '$error',
          state: retryable
              ? TeacherOutboxState.pending
              : TeacherOutboxState.conflict,
        ),
      );
      pendingOutboxCount(await _outboxStore.pendingCount());
      feedback(
        retryable
            ? systemL10n().attendanceSavedLocally
            : logbookSection == null
            ? systemL10n().attendanceSaveFailed
            : '${systemL10n().logbookNotSaved} · $error',
      );
      return null;
    }
  }

  Future<bool> saveLogbook(LogbookEdit edit) async {
    final current = session.value;
    if (current == null || !supportsLogbook || current.classSubjectId == null)
      return false;
    final correctionReason = edit.reason;
    final encodedNote = edit.note == null
        ? _editableNote
        : encodeStructuredSessionNote(edit.note!);
    final mergedProgress = {...editableChapterProgress};
    if (edit.chapterId case final String chapter) {
      if (!subjectMatters.value.any((m) => m.id == chapter)) return false;
      mergedProgress[chapter] = edit.percentage!;
    }
    final proposal = <String, dynamic>{
      'workflow': 'logbook',
      'targetId': current.id,
      'sessionNote': encodedNote,
      'progress': [
        for (final entry in mergedProgress.entries)
          {'matterId': entry.key, 'completedPercentage': entry.value},
      ],
    };
    if (logbookValidated.value && correctionReason.trim().isEmpty) {
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
    final outboxId = 'logbook-${current.id}';
    _outboxStore.bindContext(_outboxContext?.call());
    final previous = (await _outboxStore.listPending())
        .where(
          (entry) =>
              entry.id == outboxId && teacherOutboxEntryIsReplayable(entry),
        )
        .firstOrNull;
    if (previous != null) {
      final priorBody = Map<String, dynamic>.from(
        previous.payload['body'] as Map,
      );
      final priorCommand = previous.payload['command'] as String;
      final priorProposal = Map<String, dynamic>.from(
        priorBody['proposal'] as Map,
      );
      final section = previous.payload['section'] as String?;
      final delivered = await _workflowCommand(
        priorCommand,
        priorBody,
        previous.kind,
        outboxId,
        logbookSection: section ?? edit.key,
      );
      if (delivered == null) return false;
      final same =
          jsonEncode(priorProposal) == jsonEncode(proposal) &&
          priorBody['reason'] == body['reason'];
      await _acceptLogbookSave(
        priorCommand,
        delivered,
        priorProposal,
        same ? edit.key : null,
      );
      if (same) return true;
      return saveLogbook(edit);
    }
    final result = await _workflowCommand(
      command,
      body,
      logbookValidated.value
          ? TeacherOutboxKind.correction
          : TeacherOutboxKind.logbook,
      outboxId,
      logbookSection: edit.key,
    );
    if (result == null) return false;
    await _acceptLogbookSave(command, result, proposal, edit.key);
    return true;
  }

  Future<void> _acceptLogbookSave(
    String command,
    Map<String, dynamic> result,
    Map<String, dynamic> proposal,
    String? completedSection,
  ) async {
    if (command == 'save-teacher-logbook') {
      _logbookVersion = (result['version'] as num).toInt();
      _sessionProgress
        ..clear()
        ..addEntries(
          (proposal['progress'] as List).whereType<Map>().map(
            (row) => MapEntry(
              row['matterId'] as String,
              (row['completedPercentage'] as num).toInt(),
            ),
          ),
        );
      _officialNote = proposal['sessionNote'] as String?;
      officialLogbook(decodeStructuredSessionNote(_officialNote));
      unawaited(_calendar.loadCalendarData());
    } else {
      _logbookCorrection = result;
      pendingLogbook(proposal);
    }
    final remaining = Map.of(logbookDrafts.value)..remove(completedSection);
    await _persistDrafts(remaining);
  }

  Future<void> _draftWrite = Future.value();
  Future<void> persistDraft(LogbookEdit edit) =>
      _persistDrafts({...logbookDrafts.value, edit.key: edit});

  Future<void> _persistDrafts(Map<String, LogbookEdit> drafts) {
    logbookDrafts(drafts);
    final context = _outboxContext?.call();
    final version = _logbookVersion;
    final proposalVersion = _proposalVersion;
    final prefix = schoolStoragePrefix(_schoolClient());
    return _draftWrite = _draftWrite.then(
      (_) => SessionLogbookDraftStorage.save(
        sessionId,
        context,
        version,
        proposalVersion,
        drafts,
        prefix: prefix,
      ),
    );
  }

  LogbookEdit generalEditorValue() =>
      logbookDrafts.value['general'] ??
      LogbookEdit.general(
        decodeStructuredSessionNote(_editableNote),
        reason: correctionReason,
      );
  LogbookEdit chapterEditorValue(String id) =>
      logbookDrafts.value['chapter:$id'] ??
      LogbookEdit.chapter(
        id,
        editableChapterProgress[id] ??
            subjectMatters.value
                .firstWhere((m) => m.id == id)
                .cumulativePercentage,
        reason: correctionReason,
      );

  Future<void> retryAttendanceDraft() async {
    final id = 'attendance-call-$sessionId';
    final draft = (await _outboxStore.listPending())
        .where((entry) => entry.id == id)
        .firstOrNull;
    if (draft != null && teacherOutboxEntryIsReplayable(draft)) {
      try {
        await syncTeacherOutboxEntry(_schoolClient(), draft);
        await _outboxStore.remove(id);
      } on Object catch (error) {
        saveMessage(error.toString());
        return;
      }
    }
    saveMessage('');
    await load();
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
      if (!matchesSession || !teacherOutboxEntryIsReplayable(entry)) {
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
        classLabel:
            _teacherContext?.assignedClasses.value
                .where((c) => c.id == lesson['classGroupId'])
                .firstOrNull
                ?.label ??
            lesson['classGroupId'] as String? ??
            '',
        subjectLabel:
            _teacherContext?.assignments.value
                .where((a) => a.classSubjectId == lesson['classSubjectId'])
                .firstOrNull
                ?.subjectLabel ??
            lesson['displayLabel'] as String? ??
            '',
        classSubjectId: lesson['classSubjectId'] as String?,
        status: lesson['status'] as String?,
      );
    } on api.ApiError catch (error) {
      if (error.status == 404) return null;
      rethrow;
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
