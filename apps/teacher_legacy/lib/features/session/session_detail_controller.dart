import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../../common/utils/entity_filters.dart';
import '../calendar/models/teacher_session.dart';
import 'models/session_detail_models.dart';
import 'session_logbook_logic.dart' as logbook;

class SessionDetailController extends LevitController
    with LevitReactiveTasksMixin {
  SessionDetailController({
    required this.session,
    required String? Function() getAcademicYearId,
    required SchoolClientFactory schoolClient,
    TeacherOutboxStore? outboxStore,
  }) : _getAcademicYearId = getAcademicYearId,
       _schoolClient = schoolClient,
       _outboxStore = outboxStore ?? openTeacherOutboxStore();

  final TeacherSession session;
  final String? Function() _getAcademicYearId;
  final SchoolClientFactory _schoolClient;
  final TeacherOutboxStore _outboxStore;

  final segment = LxVar(SessionDetailSegment.attendance);
  final students = LxVar<List<SessionStudentRow>>(const []);
  final sessionNote = LxVar('');
  final subjectMatters = LxVar<List<SessionSubjectMatterOption>>(const []);
  final classSubjectCompletedPercentage = LxVar<int?>(null);
  final activityNotes = LxVar<String?>(null);
  final errorMessage = LxVar('');
  final saveMessage = LxVar('');
  final pendingOutboxCount = LxVar(0);

  @override
  void onInit() {
    super.onInit();
    autoDispose(segment);
    autoDispose(students);
    autoDispose(sessionNote);
    autoDispose(subjectMatters);
    autoDispose(classSubjectCompletedPercentage);
    autoDispose(activityNotes);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    autoDispose(pendingOutboxCount);
    unawaited(loadDetail());
    unawaited(refreshPendingOutboxCount());
  }

  int get recordedAttendanceCount =>
      students.value.where((row) => row.status != null).length;

  bool get supportsLogbook => session.kind == 'lesson';

  bool get supportsAttendanceRecording => session.kind == 'lesson';

  List<SessionSubjectMatterOption> get recordedMatters =>
      logbook.recordedSessionMatters(subjectMatters.value);

  List<SessionSubjectMatterOption> get pickableMatters =>
      logbook.pickableSessionMatters(subjectMatters.value);

  Future<void> loadDetail() async {
    errorMessage('');
    await runTask(() async {
      try {
        await syncPendingOutbox();
        final client = _schoolClient();
        final enrollmentRows = await client.enrollments.list(
          activeEnrollmentsForClass(
            session.classGroupId,
            academicYearId: _getAcademicYearId(),
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
          kind: session.kind,
          occurrenceId: session.id,
        );
        final attendanceByStudent = {
          for (final row in attendanceRows) row['studentId'] as String: row,
        };

        final roster = studentRows.map((row) {
          final studentId = row['id'] as String;
          final firstName = row['firstName'] as String? ?? '';
          final lastName = row['lastName'] as String? ?? '';
          final fullName = '$firstName $lastName'.trim();
          final attendance = attendanceByStudent[studentId];
          return SessionStudentRow(
            studentId: studentId,
            studentName: fullName.isEmpty ? studentId : fullName,
            studentInitials: _initials(fullName.isEmpty ? studentId : fullName),
            photoUrl: row['photoUrl'] as String?,
            attendanceId: attendance?['id'] as String?,
            status: SessionAttendanceStatus.fromApi(
              attendance?['status'] as String?,
            ),
            reason: attendance?['reason'] as String?,
            notes: attendance?['notes'] as String?,
          );
        }).toList()..sort((a, b) => a.studentName.compareTo(b.studentName));
        students(roster);

        if (!supportsLogbook || session.classSubjectId == null) {
          sessionNote('');
          subjectMatters(const []);
          classSubjectCompletedPercentage(null);
          if (session.kind == 'activity') {
            try {
              final activitySession = await client.activitySessions.get(
                session.id,
              );
              final notes = activitySession['notes'] as String?;
              activityNotes(notes != null && notes.isNotEmpty ? notes : null);
            } on Object {
              activityNotes(null);
            }
          } else {
            activityNotes(null);
          }
          return;
        }

        activityNotes(null);
        final classSubjectId = session.classSubjectId!;
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
          progressForLessonSessions([session.id]),
        );
        final lessonSession = await client.lessonSessions.get(session.id);
        final classSubject = await client.classSubjects.get(classSubjectId);

        subjectMatters(
          logbook.buildSessionSubjectMatters(
            matterLinks: matterLinks,
            subjectMatters: matters,
            sessionProgressRows: progressRows,
            fallbackName: systemL10n().chapterFallback,
          ),
        );
        sessionNote(lessonSession['sessionNote'] as String? ?? '');
        classSubjectCompletedPercentage(
          (classSubject['completedPercentage'] as num?)?.toInt(),
        );
      } on ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadSession('$error'));
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadSession('$error'));
      }
    });
  }

  Future<bool> recordAttendance(
    SessionStudentRow row,
    SessionAttendanceStatus status, {
    String? reason,
    String? notes,
  }) async {
    if (!supportsAttendanceRecording) {
      saveMessage(systemL10n().attendanceRecordingLessonOnly);
      return false;
    }

    saveMessage('');
    final attendanceId = row.attendanceId ?? '${row.studentId}-${session.id}';
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final payload = attendanceRecordPayload(
      kind: session.kind,
      occurrenceId: session.id,
      studentId: row.studentId,
      attendanceId: attendanceId,
      status: status.apiValue,
      createdAt: createdAt,
      reason: reason,
      notes: notes,
    );

    try {
      final client = _schoolClient();
      await client.recordAttendance(payload);
      await _removeAttendanceOutbox(row.studentId);
      students(
        students.value
            .map(
              (entry) => entry.studentId == row.studentId
                  ? entry.copyWith(
                      attendanceId: attendanceId,
                      status: status,
                      reason: reason,
                      notes: notes,
                    )
                  : entry,
            )
            .toList(),
      );
      return true;
    } on ApiError catch (error) {
      return _enqueueAttendanceFailure(
        row: row,
        status: status,
        reason: reason,
        notes: notes,
        attendanceId: attendanceId,
        createdAt: createdAt,
        error: '$error',
      );
    } on Object catch (error) {
      return _enqueueAttendanceFailure(
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

  Future<int> markAllPresent() async {
    var savedCount = 0;
    for (final row in students.value) {
      if (row.status == SessionAttendanceStatus.present) {
        continue;
      }
      final saved = await recordAttendance(row, SessionAttendanceStatus.present);
      if (saved) {
        savedCount++;
      }
    }
    return savedCount;
  }

  Future<void> refreshPendingOutboxCount() async {
    pendingOutboxCount(await _outboxStore.pendingCount());
  }

  Future<int> syncPendingOutbox() async {
    final pending = await _outboxStore.listPending();
    var syncedCount = 0;
    final client = _schoolClient();

    for (final entry in pending) {
      final lessonSessionId = entry.payload['lessonSessionId'] as String? ??
          (entry.payload['notePayload'] is Map
              ? (entry.payload['notePayload'] as Map)['id'] as String?
              : null);
      final attendanceSessionId = entry.payload['lessonSessionId'] as String?;

      final matchesSession = switch (entry.kind) {
        TeacherOutboxKind.attendance =>
          attendanceSessionId == session.id && supportsAttendanceRecording,
        TeacherOutboxKind.logbook =>
          lessonSessionId == session.id && supportsLogbook,
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

    if (syncedCount > 0) {
      await loadDetail();
    }
    await refreshPendingOutboxCount();
    return syncedCount;
  }

  Future<bool> _enqueueAttendanceFailure({
    required SessionStudentRow row,
    required SessionAttendanceStatus status,
    required String? reason,
    required String? notes,
    required String attendanceId,
    required String createdAt,
    required String error,
  }) async {
    final payload = attendanceRecordPayload(
      kind: session.kind,
      occurrenceId: session.id,
      studentId: row.studentId,
      attendanceId: attendanceId,
      status: status.apiValue,
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
          occurrenceId: session.id,
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
    students(
      students.value
          .map(
            (entry) => entry.studentId == row.studentId
                ? entry.copyWith(
                    attendanceId: attendanceId,
                    status: status,
                    reason: reason,
                    notes: notes,
                  )
                : entry,
          )
          .toList(),
    );
    saveMessage(systemL10n().attendanceSavedLocally);
    await refreshPendingOutboxCount();
    return true;
  }

  Future<void> _removeAttendanceOutbox(String studentId) async {
    final pending = await _outboxStore.listPending();
    for (final entry in pending) {
      if (entry.kind == TeacherOutboxKind.attendance &&
          entry.payload['studentId'] == studentId &&
          entry.payload['lessonSessionId'] == session.id) {
        await _outboxStore.remove(entry.id);
      }
    }
    await refreshPendingOutboxCount();
  }

  Future<bool> saveLogbook({
    required logbook.StructuredLogbookContent structuredContent,
    List<LogbookProgressDraft> progressEntries = const [],
  }) async {
    if (!supportsLogbook || session.classSubjectId == null) {
      return false;
    }

    final matterById = {
      for (final matter in subjectMatters.value) matter.id: matter,
    };

    for (final entry in progressEntries) {
      final matter = matterById[entry.matterId];
      if (matter == null) {
        saveMessage(systemL10n().chapterFallback);
        return false;
      }
      final minimum = logbook.minMatterProgressPercentage(matter);
      if (entry.completedPercentage < minimum) {
        saveMessage(systemL10n().progressMustNotDecrease(minimum));
        return false;
      }
    }

    saveMessage('');
    final encodedNote = logbook.encodeStructuredSessionNote(structuredContent);
    final progressOps = <Map<String, dynamic>>[];
    final recordedAt = DateTime.now();
    final client = _schoolClient();

    try {
      final lessonSession = await client.lessonSessions.get(session.id);
      final notePayload = logbook.lessonSessionNotePayload(
        lessonSession: lessonSession,
        sessionNote: encodedNote,
        displayLabelFallback: session.title,
      );

      for (final entry in progressEntries) {
        final matter = matterById[entry.matterId]!;
        final existing = matter.sessionProgress;

        if (logbook.isProgressCreate(existing)) {
          progressOps.add({
            'action': 'create',
            'payload': logbook.recordLessonProgressPayload(
              id: logbook.newProgressId(session.id),
              classSubjectMatterId: matter.id,
              lessonSessionId: session.id,
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
            'payload': logbook.updateProgressPayload(
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

      sessionNote(encodedNote);
      await loadDetail();
      return true;
    } on Object catch (error) {
      return _enqueueLogbookFailure(
        encodedNote: encodedNote,
        progressEntries: progressEntries,
        matterById: matterById,
        error: '$error',
        prefetchedOps: progressOps,
      );
    }
  }

  Future<bool> _enqueueLogbookFailure({
    required String encodedNote,
    required List<LogbookProgressDraft> progressEntries,
    required Map<String, SessionSubjectMatterOption> matterById,
    required String error,
    List<Map<String, dynamic>> prefetchedOps = const [],
  }) async {
    final recordedAt = DateTime.now();
    final progressOps = prefetchedOps.isNotEmpty
        ? prefetchedOps
        : <Map<String, dynamic>>[];

    if (progressOps.isEmpty) {
      for (final entry in progressEntries) {
        final matter = matterById[entry.matterId];
        if (matter == null) {
          continue;
        }
        final existing = matter.sessionProgress;
        if (logbook.isProgressCreate(existing)) {
          progressOps.add({
            'action': 'create',
            'payload': logbook.recordLessonProgressPayload(
              id: logbook.newProgressId(session.id),
              classSubjectMatterId: matter.id,
              lessonSessionId: session.id,
              completedPercentage: entry.completedPercentage,
              notes: entry.notes,
              recordedAt: recordedAt,
            ),
          });
        }
      }
    }

    final notePayload = {
      'id': session.id,
      'sessionNote': logbook.normalizeSessionNote(encodedNote),
      'displayLabel': session.title,
    };

    final now = DateTime.now();
    await _outboxStore.enqueue(
      buildTeacherOutboxEntry(
        id: 'logbook-${session.id}-${now.millisecondsSinceEpoch}',
        kind: TeacherOutboxKind.logbook,
        idempotencyKey: teacherLogbookIdempotencyKey(
          lessonSessionId: session.id,
        ),
        payload: {
          'lessonSessionId': session.id,
          ...logbookOutboxPayload(
            notePayload: notePayload,
            progressOps: progressOps,
          ),
        },
        lastError: error,
      ),
    );
    sessionNote(encodedNote);
    saveMessage(systemL10n().attendanceSavedLocally);
    await refreshPendingOutboxCount();
    return true;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

enum SessionDetailSegment { attendance, logbook }
