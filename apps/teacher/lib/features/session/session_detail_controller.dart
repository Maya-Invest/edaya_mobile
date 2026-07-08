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
  }) : _getAcademicYearId = getAcademicYearId,
       _schoolClient = schoolClient;

  final TeacherSession session;
  final String? Function() _getAcademicYearId;
  final SchoolClientFactory _schoolClient;

  final segment = LxVar(SessionDetailSegment.attendance);
  final students = LxVar<List<SessionStudentRow>>(const []);
  final sessionNote = LxVar('');
  final subjectMatters = LxVar<List<SessionSubjectMatterOption>>(const []);
  final classSubjectCompletedPercentage = LxVar<int?>(null);
  final activityNotes = LxVar<String?>(null);
  final errorMessage = LxVar('');
  final saveMessage = LxVar('');

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
    unawaited(loadDetail());
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
    SessionAttendanceStatus status,
  ) async {
    if (!supportsAttendanceRecording) {
      saveMessage(systemL10n().attendanceRecordingLessonOnly);
      return false;
    }

    saveMessage('');
    try {
      final client = _schoolClient();
      final attendanceId = row.attendanceId ?? '${row.studentId}-${session.id}';
      await client.recordAttendance(
        attendanceRecordPayload(
          kind: session.kind,
          occurrenceId: session.id,
          studentId: row.studentId,
          attendanceId: attendanceId,
          status: status.apiValue,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      students(
        students.value
            .map(
              (entry) => entry.studentId == row.studentId
                  ? entry.copyWith(attendanceId: attendanceId, status: status)
                  : entry,
            )
            .toList(),
      );
      return true;
    } on ApiError catch (error) {
      saveMessage(systemL10n().couldNotSaveAttendance('$error'));
      return false;
    } on Object catch (error) {
      saveMessage(systemL10n().couldNotSaveAttendance('$error'));
      return false;
    }
  }

  Future<bool> saveLogbook({
    required String sessionNoteText,
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
    try {
      final client = _schoolClient();
      final lessonSession = await client.lessonSessions.get(session.id);
      await client.lessonSessions.save(
        logbook.lessonSessionNotePayload(
          lessonSession: lessonSession,
          sessionNote: sessionNoteText,
          displayLabelFallback: session.title,
        ),
      );
      sessionNote(sessionNoteText.trim());

      for (final entry in progressEntries) {
        final matter = matterById[entry.matterId]!;
        final existing = matter.sessionProgress;
        final recordedAt = DateTime.now();

        if (logbook.isProgressCreate(existing)) {
          await client.recordLessonSessionProgress(
            logbook.recordLessonProgressPayload(
              id: logbook.newProgressId(session.id),
              classSubjectMatterId: matter.id,
              lessonSessionId: session.id,
              completedPercentage: entry.completedPercentage,
              notes: entry.notes,
              recordedAt: recordedAt,
            ),
          );
        } else {
          final progressRow = await client.classSubjectProgress.get(
            existing!.id,
          );
          await client.classSubjectProgress.save(
            logbook.updateProgressPayload(
              existing: progressRow,
              completedPercentage: entry.completedPercentage,
              notes: entry.notes,
              recordedAt: recordedAt,
            ),
          );
        }
      }

      await loadDetail();
      return true;
    } on Object catch (error) {
      saveMessage(systemL10n().couldNotSaveLogbook('$error'));
      return false;
    }
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
