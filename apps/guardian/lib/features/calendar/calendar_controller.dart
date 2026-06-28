import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import 'package:edaya_shared/edaya_shared.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'models/attendance_record.dart';
import 'models/calendar_session.dart';
import 'models/logbook_entry.dart';
import 'models/school_event.dart';

enum CalendarView { timetable, events }

class CalendarController extends LevitController with LevitReactiveTasksMixin {
  CalendarController({
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
  }) : _studentContext = studentContext,
       _academicYear = academicYear;

  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;

  final view = LxVar(CalendarView.timetable);
  final weekStart = LxVar(startOfWeek(defaultCalendarDay()));
  final selectedDay = LxVar(defaultCalendarDay());
  final sessions = LxVar<List<CalendarSession>>(const []);
  final events = LxVar<List<SchoolEvent>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(view);
    autoDispose(weekStart);
    autoDispose(selectedDay);
    autoDispose(sessions);
    autoDispose(events);
    autoDispose(errorMessage);

    autoDispose(
      _studentContext.classGroupId.stream.listen((_) {
        unawaited(loadCalendarData());
      }),
    );
    autoDispose(
      _studentContext.activeStudent.stream.listen((_) {
        unawaited(loadCalendarData());
      }),
    );
    autoDispose(
      _studentContext.isEnrolled.stream.listen((_) {
        unawaited(loadCalendarData());
      }),
    );
    autoDispose(
      _academicYear.selectedYearId.stream.listen((_) {
        unawaited(loadCalendarData());
      }),
    );

    unawaited(loadCalendarData());
  }

  DataStatus get dataStatus {
    if (isBusy.value && sessions.value.isEmpty && events.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty &&
        sessions.value.isEmpty &&
        events.value.isEmpty) {
      return DataStatus.error;
    }
    if (_studentContext.activeStudent.value == null) {
      return DataStatus.empty;
    }
    if (!_studentContext.isEnrolled.value) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage {
    if (_studentContext.activeStudent.value == null) {
      return 'Select a student to view the calendar.';
    }
    if (!_studentContext.isEnrolled.value) {
      return 'This student is not enrolled for the selected school year.';
    }
    if (view.value == CalendarView.timetable) {
      return 'No classes scheduled for this day.';
    }
    return 'No school events for this period.';
  }

  List<CalendarSession> get sessionsForSelectedDay {
    final day = selectedDay.value;
    return sessions.value
        .map((session) => session.projectOntoDay(day))
        .whereType<CalendarSession>()
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  List<SchoolEvent> get eventsForSelectedDay {
    final day = selectedDay.value;
    return events.value.where((event) => event.occursOn(day)).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  List<DateTime> get weekDays {
    final start = weekStart.value;
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }

  void selectView(CalendarView nextView) {
    view(nextView);
  }

  void selectDay(DateTime day) {
    selectedDay(DateTime(day.year, day.month, day.day));
  }

  void shiftWeek(int deltaWeeks) {
    final nextWeek = weekStart.value.add(Duration(days: 7 * deltaWeeks));
    weekStart(nextWeek);
    selectedDay(nextWeek);
  }

  Future<void> loadCalendarData() async {
    final classGroupId = _studentContext.classGroupId.value;
    final yearId = _academicYear.selectedYearId.value;

    if (classGroupId == null || yearId == null) {
      sessions(const []);
      events(const []);
      errorMessage('');
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = AppRuntime.schoolClient();
        final sessionRows = await client.sessions.list(
          classGroupScope(classGroupId),
        );
        final eventRows = await client.calendarEvents.list(
          academicYearScope(yearId),
        );

        sessions(
          sessionRows
              .map(CalendarSession.fromJson)
              .toList(growable: false),
        );
        events(
          eventRows.map(SchoolEvent.fromJson).toList(growable: false),
        );
      } on api.ApiError catch (error) {
        errorMessage('Could not load calendar: $error');
        sessions(const []);
        events(const []);
      } on Object catch (error) {
        errorMessage('Could not load calendar: $error');
        sessions(const []);
        events(const []);
      }
    });
  }
}

class SessionDetailsController extends LevitController
    with LevitReactiveTasksMixin {
  SessionDetailsController({
    required this.session,
    required StudentContextController studentContext,
  }) : _studentContext = studentContext;

  final CalendarSession session;
  final StudentContextController _studentContext;

  final attendance = LxVar<AttendanceRecord?>(null);
  final logbook = LxVar<LogbookEntry?>(null);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(attendance);
    autoDispose(logbook);
    autoDispose(errorMessage);
    unawaited(loadDetails());
  }

  Future<void> loadDetails() async {
    final studentId = _studentContext.activeStudentId;
    final classGroupId = _studentContext.classGroupId.value;
    if (studentId == null || classGroupId == null) {
      return;
    }

    await runTask(() async {
      try {
        final client = AppRuntime.schoolClient();
        final attendanceRows = await client.attendance.list({
          ...studentScope(studentId),
          ...sessionScope(session.id),
        });
        attendance(
          attendanceRows.isEmpty
              ? null
              : AttendanceRecord.fromJson(attendanceRows.first),
        );

        if (session.classSubjectId == null) {
          logbook(null);
          return;
        }

        final logbookRows = await client.classLogbookEntries.list({
          ...classGroupScope(classGroupId),
          'classSubjectId': session.classSubjectId,
        });

        final sessionDate = DateTime(
          session.startsAt.year,
          session.startsAt.month,
          session.startsAt.day,
        );
        LogbookEntry? matched;
        for (final row in logbookRows) {
          final entry = LogbookEntry.fromJson(row);
          if (isSameCalendarDay(entry.date, sessionDate)) {
            matched = entry;
            break;
          }
        }
        logbook(matched);
      } on Object catch (error) {
        errorMessage('Could not load session details: $error');
      }
    }, id: 'load-session-details');
  }
}

class AttendanceListController extends LevitController
    with LevitReactiveTasksMixin {
  AttendanceListController({
    required StudentContextController studentContext,
  }) : _studentContext = studentContext;

  final StudentContextController _studentContext;

  final records = LxVar<List<AttendanceRecord>>(const []);
  final sessionTitles = LxVar<Map<String, String>>(const {});
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(records);
    autoDispose(sessionTitles);
    autoDispose(errorMessage);
    unawaited(loadAttendance());
  }

  Future<void> loadAttendance() async {
    final studentId = _studentContext.activeStudentId;
    if (studentId == null) {
      return;
    }

    await runTask(() async {
      try {
        final client = AppRuntime.schoolClient();
        final rows = await client.attendance.list(studentScope(studentId));
        final parsed = rows.map(AttendanceRecord.fromJson).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        records(parsed);

        final sessionIds = parsed.map((record) => record.sessionId).toSet();
        final titles = <String, String>{};
        for (final sessionId in sessionIds) {
          try {
            final sessionJson = await client.sessions.get(sessionId);
            titles[sessionId] = sessionJson['title'] as String? ?? sessionId;
          } on Object {
            titles[sessionId] = sessionId;
          }
        }
        sessionTitles(titles);
      } on Object catch (error) {
        errorMessage('Could not load attendance: $error');
        records(const []);
      }
    }, id: 'load-attendance-list');
  }
}
