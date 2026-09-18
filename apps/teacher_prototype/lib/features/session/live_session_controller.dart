import 'dart:async';
import 'dart:convert';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../live/entity_queries.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../calendar/live_calendar_controller.dart';
import '../calendar/teacher_session.dart';
import '../context/academic_year_controller.dart';

class LiveSessionStudent {
  const LiveSessionStudent({
    required this.studentId,
    required this.fullName,
    required this.initials,
    this.photoUrl,
    this.attendanceId,
    this.status,
  });

  final String studentId;
  final String fullName;
  final String initials;
  final String? photoUrl;
  final String? attendanceId;
  final AttendanceStatus? status;

  LiveSessionStudent copyWith({
    String? attendanceId,
    AttendanceStatus? status,
  }) {
    return LiveSessionStudent(
      studentId: studentId,
      fullName: fullName,
      initials: initials,
      photoUrl: photoUrl,
      attendanceId: attendanceId ?? this.attendanceId,
      status: status ?? this.status,
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
  }) : _calendar = calendar,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final String sessionId;
  final LiveCalendarController _calendar;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final session = LxVar<TeacherSession?>(null);
  final students = LxVar<List<LiveSessionStudent>>(const []);
  final content = LxVar('');
  final objectives = LxVar('');
  final homework = LxVar('');
  final progressPercent = LxVar(50);
  final errorMessage = LxVar('');
  final saveMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(session);
    autoDispose(students);
    autoDispose(content);
    autoDispose(objectives);
    autoDispose(homework);
    autoDispose(progressPercent);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    autoDispose(
      _calendar.sessions.stream.listen((_) {
        session(_calendar.sessionById(sessionId));
      }),
    );
    session(_calendar.sessionById(sessionId));
    unawaited(load());
  }

  bool get attendanceComplete {
    final roster = students.value;
    if (roster.isEmpty) {
      return false;
    }
    return roster.every((row) => row.status != null);
  }

  bool get logbookComplete {
    return content.value.trim().isNotEmpty ||
        objectives.value.trim().isNotEmpty ||
        homework.value.trim().isNotEmpty;
  }

  Future<void> load() async {
    errorMessage('');
    await runTask(() async {
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
          );
        }).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
        students(roster);

        if (current.kind == 'lesson') {
          try {
            final lesson = await client.lessonSessions.get(current.id);
            _applySessionNote(lesson['sessionNote'] as String?);
          } on Object {
            // Keep empty logbook fields when the lesson row is unavailable.
          }
        }
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadSession('$error'));
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadSession('$error'));
      }
    });
  }

  Future<void> setAttendanceStatus(
    String studentId,
    AttendanceStatus status,
  ) async {
    final current = session.value;
    final row = students.value
        .where((item) => item.studentId == studentId)
        .firstOrNull;
    if (current == null || row == null) {
      return;
    }
    saveMessage('');
    final attendanceId = row.attendanceId ?? '${row.studentId}-${current.id}';
    try {
      await _schoolClient().recordAttendance(
        attendanceRecordPayload(
          kind: current.kind,
          occurrenceId: current.id,
          studentId: row.studentId,
          attendanceId: attendanceId,
          status: status.name,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      students([
        for (final item in students.value)
          if (item.studentId == studentId)
            item.copyWith(attendanceId: attendanceId, status: status)
          else
            item,
      ]);
      unawaited(_calendar.loadCalendarData());
    } on Object catch (error) {
      saveMessage('$error');
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
    await markAllPresent();
  }

  Future<bool> saveLogbook({
    required String contentText,
    required String objectivesText,
    required String homeworkText,
    required int progress,
  }) async {
    final current = session.value;
    if (current == null || current.kind != 'lesson') {
      return false;
    }
    saveMessage('');
    try {
      final client = _schoolClient();
      final lesson = await client.lessonSessions.get(current.id);
      await client.lessonSessions.save({
        ...lesson,
        'displayLabel': lesson['displayLabel'] as String? ?? current.title,
        'sessionNote': _encodeNote(
          contentText: contentText,
          objectivesText: objectivesText,
          homeworkText: homeworkText,
          progress: progress,
        ),
      });
      content(contentText);
      objectives(objectivesText);
      homework(homeworkText);
      progressPercent(progress);
      unawaited(_calendar.loadCalendarData());
      return true;
    } on Object catch (error) {
      saveMessage('$error');
      return false;
    }
  }

  void _applySessionNote(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      content('');
      objectives('');
      homework('');
      progressPercent(50);
      return;
    }
    if (!value.startsWith('{"edayaLogbook":')) {
      content(value);
      return;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        content(value);
        return;
      }
      final payload = decoded['edayaLogbook'];
      if (payload is! Map<String, dynamic>) {
        content(value);
        return;
      }
      content(payload['content'] as String? ?? '');
      final objectiveList = payload['objectives'];
      if (objectiveList is List) {
        objectives(objectiveList.whereType<String>().join('\n'));
      }
      homework(payload['homework'] as String? ?? '');
      final progress = payload['progress'];
      if (progress is num) {
        progressPercent(progress.toInt());
      }
    } on Object {
      content(value);
    }
  }

  String _encodeNote({
    required String contentText,
    required String objectivesText,
    required String homeworkText,
    required int progress,
  }) {
    final objectives = objectivesText
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return jsonEncode({
      'edayaLogbook': {
        'v': 1,
        'content': contentText.trim(),
        'objectives': objectives,
        if (homeworkText.trim().isNotEmpty) 'homework': homeworkText.trim(),
        'progress': progress,
      },
    });
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
