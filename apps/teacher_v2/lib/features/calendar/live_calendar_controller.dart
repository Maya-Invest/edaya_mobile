import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../live/entity_queries.dart';
import '../context/academic_year_controller.dart';
import '../context/teacher_context_controller.dart';
import '../session/session_logbook_logic.dart';
import 'teacher_session.dart';

class LiveCalendarController extends LevitController
    with LevitReactiveTasksMixin {
  LiveCalendarController({
    required TeacherContextController teacherContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _teacherContext = teacherContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final TeacherContextController _teacherContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final weekStart = LxVar(startOfWeek(defaultCalendarDay()));
  final selectedDay = LxVar(defaultCalendarDay());
  final sessions = LxVar<List<TeacherSession>>(const []);
  final todaySessions = LxVar<List<TeacherSession>>(const []);
  final attendanceCompletionBySessionId =
      LxVar<Map<String, SessionAttendanceCompletion>>({});
  final logbookCompleteBySessionId = LxVar<Map<String, bool>>({});
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(weekStart);
    autoDispose(selectedDay);
    autoDispose(sessions);
    autoDispose(todaySessions);
    autoDispose(attendanceCompletionBySessionId);
    autoDispose(logbookCompleteBySessionId);
    autoDispose(errorMessage);

    for (final subscription in [
      _teacherContext.teacherId.stream,
      _teacherContext.assignedClasses.stream,
      _teacherContext.activeAssignmentId.stream,
      _teacherContext.taughtClassSubjectIds.stream,
      _teacherContext.isLoading.stream,
      _academicYear.selectedYearId.stream,
      weekStart.stream,
    ]) {
      autoDispose(subscription.listen((_) => unawaited(loadCalendarData())));
    }

    unawaited(loadCalendarData());
  }

  CalendarSessionFocus get todayFocus => resolveCalendarSessionFocus(
    sessions: todaySessions.value.isNotEmpty
        ? todaySessions.value
        : sessions.value,
    now: DateTime.now(),
  );

  List<TeacherSession> get sessionsForSelectedDay {
    final day = selectedDay.value;
    return sessions.value
        .where(
          (session) =>
              isSameCalendarDay(
                _teacherContext.schoolTime(session.startsAt),
                day,
              ) &&
              _teacherContext.visibleClassGroupIds.contains(
                session.classGroupId,
              ),
        )
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  List<TeacherSession> get incompleteAttendanceSessions {
    final lessonSessions = todayFocus.todaySessions
        .where((session) => session.kind == 'lesson')
        .toList();
    return sessionsWithIncompleteAttendance(
      todayLessonSessions: lessonSessions,
      completionBySessionId: attendanceCompletionBySessionId.value,
    );
  }

  List<TeacherSession> get incompleteLogbookSessions {
    final now = DateTime.now();
    return todayFocus.todaySessions.where((session) {
      if (session.kind != 'lesson' || session.endsAt.isAfter(now)) {
        return false;
      }
      return !(logbookCompleteBySessionId.value[session.id] ?? false);
    }).toList();
  }

  TeacherSession? sessionById(String id) {
    for (final session in [...todaySessions.value, ...sessions.value]) {
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  void selectDay(DateTime day) {
    selectedDay(DateTime(day.year, day.month, day.day));
  }

  void goToDate(DateTime day) {
    final calendarDay = DateTime(day.year, day.month, day.day);
    weekStart(startOfWeek(calendarDay));
    selectedDay(calendarDay);
  }

  bool _matchesSelection(TeacherSession session) =>
      session.classGroupId == _teacherContext.activeAssignment?.classGroupId &&
      session.classSubjectId ==
          _teacherContext.activeAssignment?.classSubjectId;

  int _loadGeneration = 0;
  Future<void> loadCalendarData() async {
    final generation = ++_loadGeneration;
    bool stale() => isClosed || generation != _loadGeneration;

    if (_teacherContext.isLoading.value ||
        _teacherContext.teacherId.value == null) {
      sessions(const []);
      todaySessions(const []);
      return;
    }

    final classGroupIds = _teacherContext.visibleClassGroupIds;
    if (classGroupIds.isEmpty) {
      sessions(const []);
      todaySessions(const []);
      errorMessage('');
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final classLabelById = {
          for (final assigned in _teacherContext.assignedClasses.value)
            assigned.id: assigned.label,
        };
        final range = planningDateRangeForWeek(weekStart.value);
        final parsedSessions = <TeacherSession>[];

        final occurrences = await fetchTeacherTimetableOccurrences(
          client,
          _teacherContext.teacherId.value!,
          range: range,
        );
        for (final occurrence in occurrences) {
          parsedSessions.add(
            TeacherSession.fromOccurrence(
              occurrence,
              classLabel:
                  classLabelById[occurrence.classGroupId] ??
                  occurrence.classGroupId,
            ),
          );
        }

        if (stale()) return;
        parsedSessions.sort((a, b) => a.startsAt.compareTo(b.startsAt));
        sessions(parsedSessions.where(_matchesSelection).toList());
        todaySessions(
          (await _loadTeacherToday(
            client,
            classLabelById,
          )).where(_matchesSelection).toList(),
        );
        await _loadTodayAttendanceCompletion(parsedSessions);
        await _loadTodayLogbookCompletion(parsedSessions);
      } on api.ApiError catch (error) {
        if (stale()) return;
        errorMessage(systemL10n().couldNotLoadCalendar('$error'));
        sessions(const []);
      } on Object catch (error) {
        if (stale()) return;
        errorMessage(systemL10n().couldNotLoadCalendar('$error'));
        sessions(const []);
      }
    });
  }

  Future<void> _loadTodayAttendanceCompletion(
    List<TeacherSession> loadedSessions,
  ) async {
    final focus = resolveCalendarSessionFocus(
      sessions: loadedSessions,
      now: DateTime.now(),
    );
    final lessonSessions = focus.todaySessions
        .where((session) => session.kind == 'lesson')
        .toList();
    if (lessonSessions.isEmpty) {
      attendanceCompletionBySessionId(const {});
      return;
    }

    final client = _schoolClient();
    final academicYearId = _academicYear.selectedYearId.value;
    final completionBySessionId = <String, SessionAttendanceCompletion>{};

    for (final session in lessonSessions) {
      try {
        final enrollmentRows = await client.enrollments.list(
          activeEnrollmentsForClass(
            session.classGroupId,
            academicYearId: academicYearId,
          ),
        );
        final attendanceRows = await listAttendanceForOccurrence(
          client.attendance,
          kind: session.kind,
          occurrenceId: session.id,
        );
        completionBySessionId[session.id] = SessionAttendanceCompletion(
          sessionId: session.id,
          recordedCount: attendanceRows.length,
          totalCount: enrollmentRows.length,
        );
      } on Object {
        continue;
      }
    }

    attendanceCompletionBySessionId(completionBySessionId);
  }

  Future<void> _loadTodayLogbookCompletion(
    List<TeacherSession> loadedSessions,
  ) async {
    final now = DateTime.now();
    final focus = resolveCalendarSessionFocus(
      sessions: loadedSessions,
      now: now,
    );
    final endedLessons = focus.todaySessions
        .where(
          (session) => session.kind == 'lesson' && !session.endsAt.isAfter(now),
        )
        .toList();
    if (endedLessons.isEmpty) {
      logbookCompleteBySessionId(const {});
      return;
    }

    final client = _schoolClient();
    final completeBySessionId = <String, bool>{};
    for (final session in endedLessons) {
      try {
        final lesson = await client.lessonSessions.get(session.id);
        completeBySessionId[session.id] = sessionNoteIndicatesComplete(
          lesson['sessionNote'] as String?,
        );
      } on Object {
        completeBySessionId[session.id] = false;
      }
    }
    logbookCompleteBySessionId(completeBySessionId);
  }

  Future<List<TeacherSession>> _loadTeacherToday(
    api.SchoolClient client,
    Map<String, String> classLabelById,
  ) async {
    final teacherId = _teacherContext.teacherId.value;
    if (teacherId == null) {
      return const [];
    }
    final now = _teacherContext.schoolTime(DateTime.now());
    final day =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      final response = await client.runQuery('get-teacher-timetable', {
        'teacherId': teacherId,
        'startDate': day,
        'endDate': day,
      });
      final events = response['events'];
      if (events is! List) {
        return const [];
      }
      return [
        for (final raw in events)
          if (raw is Map)
            TeacherSession(
              id: raw['id'] as String,
              title: raw['title'] as String? ?? raw['id'] as String,
              kind: raw['kind'] as String? ?? 'lesson',
              startsAt: DateTime.parse(raw['startsAt'] as String),
              endsAt: DateTime.parse(raw['endsAt'] as String),
              classGroupId: raw['classGroupId'] as String,
              classLabel:
                  classLabelById[raw['classGroupId']] ??
                  raw['classGroupId'] as String,
              subjectLabel: raw['subjectLabel'] as String? ?? '',
              classSubjectId: raw['classSubjectId'] as String?,
              status: raw['status'] as String?,
            ),
      ];
    } on Object catch (error) {
      errorMessage(systemL10n().couldNotLoadCalendar('$error'));
      return const [];
    }
  }
}
