import 'package:edaya_api_client/edaya_api_client.dart';
import 'dart:async';

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
       _schoolClient = schoolClient {
    final now = teacherContext.schoolTime(DateTime.now());
    final day = DateTime(now.year, now.month, now.day);
    selectedDay(day);
    weekStart(startOfWeek(day));
  }

  final TeacherContextController _teacherContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final weekStart = LxVar(startOfWeek(DateTime.now()));
  final selectedDay = LxVar(DateTime.now());
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
      _teacherContext.schoolTimeZone.stream,
      weekStart.stream,
    ]) {
      autoDispose(
        subscription.listen((_) {
          if (_started && !isClosed) unawaited(loadCalendarData());
        }),
      );
    }
  }

  bool _started = false;

  /// Home owns a day-only preview. Begin reading Agenda data at its first consumer.
  void start() {
    if (_started || isClosed) return;
    _started = true;
    scheduleMicrotask(loadCalendarData);
  }

  CalendarSessionFocus get todayFocus => resolveCalendarSessionFocus(
    sessions: todaySessions.value,
    schoolTime: _teacherContext.schoolTime,
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

  bool _explicitDay = false;
  void goToDate(DateTime day) {
    _explicitDay = true;
    final calendarDay = DateTime(day.year, day.month, day.day);
    weekStart(startOfWeek(calendarDay));
    selectedDay(calendarDay);
  }

  bool _matchesSelection(TeacherSession session) =>
      session.classGroupId == _teacherContext.activeAssignment?.classGroupId &&
      session.classSubjectId ==
          _teacherContext.activeAssignment?.classSubjectId;

  int _loadGeneration = 0;
  String? _selectionKey;
  Future<void> loadCalendarData() async {
    if (isClosed) return;
    final generation = ++_loadGeneration;
    bool stale() => isClosed || generation != _loadGeneration;

    final workspace = _teacherContext.selection;
    final teacherId = _teacherContext.teacherId.value;
    final selectionKey = workspace == null
        ? null
        : '${workspace.schoolId}/${workspace.academicYearId}/$teacherId/${_teacherContext.activeAssignmentId.value}';
    if (selectionKey != _selectionKey) {
      _selectionKey = selectionKey;
      sessions(const []);
      todaySessions(const []);
      attendanceCompletionBySessionId(const {});
      logbookCompleteBySessionId(const {});
      errorMessage('');
    }
    if (workspace == null ||
        teacherId == null ||
        _teacherContext.isLoading.value)
      return;
    final now = _teacherContext.schoolTime(DateTime.now());
    if (!_explicitDay) {
      final day = DateTime(now.year, now.month, now.day);
      selectedDay(day);
      weekStart(startOfWeek(day));
    }
    final range = planningDateRangeForWeek(weekStart.value);
    final labels = {
      for (final group in _teacherContext.assignedClasses.value)
        group.id: group.label,
    };
    errorMessage('');
    await runTask(() async {
      if (stale()) return;
      try {
        final client = _schoolClient();
        Future<List<TeacherSession>> read(PlanningDateRange dates) async {
          final occurrences = await fetchTeacherTimetableOccurrences(
            client,
            teacherId,
            range: dates,
          );
          return [
              for (final event in occurrences)
                TeacherSession.fromOccurrence(
                  event,
                  classLabel: labels[event.classGroupId] ?? event.classGroupId,
                ),
            ].where(_matchesSelection).toList()
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        }

        final week = await read(range);
        if (stale()) return;
        sessions(week);
        // The teacher query uses UTC calendar dates. Cover both sides of local midnight.
        final utcDay = now.toUtc();
        String key(DateTime d) => d.toIso8601String().substring(0, 10);
        final todayRange = PlanningDateRange(
          startDate: key(utcDay.subtract(const Duration(days: 1))),
          endDate: key(utcDay.add(const Duration(days: 1))),
        );
        final coversToday =
            range.startDate.compareTo(todayRange.startDate) <= 0 &&
            range.endDate.compareTo(todayRange.endDate) >= 0;
        final candidates = coversToday ? week : await read(todayRange);
        if (stale()) return;
        final today = candidates
            .where(
              (s) => isSameCalendarDay(
                _teacherContext.schoolTime(s.startsAt),
                now,
              ),
            )
            .toList();
        todaySessions(today);
        await Future.wait([
          _loadTodayAttendanceCompletion(today, stale),
          _loadTodayLogbookCompletion(today, stale),
        ]);
      } on Object catch (error) {
        if (stale()) return;
        errorMessage(systemL10n().couldNotLoadCalendar('$error'));
      }
    });
  }

  Future<void> _loadTodayAttendanceCompletion(
    List<TeacherSession> loadedSessions,
    bool Function() stale,
  ) async {
    final lessonSessions = loadedSessions
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

    if (!stale()) attendanceCompletionBySessionId(completionBySessionId);
  }

  Future<void> _loadTodayLogbookCompletion(
    List<TeacherSession> loadedSessions,
    bool Function() stale,
  ) async {
    final now = DateTime.now();
    final endedLessons = loadedSessions
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
    if (!stale()) logbookCompleteBySessionId(completeBySessionId);
  }
}
