import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'models/calendar_session.dart';
import 'models/school_event.dart';

enum CalendarView { timetable, events }

class CalendarController extends LevitController with LevitReactiveTasksMixin {
  CalendarController({
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  int _loadGeneration = 0;

  @override
  void onClose() {
    _loadGeneration++;
    super.onClose();
  }

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
    autoDispose(
      weekStart.stream.listen((_) {
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
    if (!_studentContext.isEnrolled.value &&
        sessions.value.isEmpty &&
        events.value.isEmpty) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage {
    final l10n = systemL10n();
    if (_studentContext.activeStudent.value == null) {
      if (_studentContext.linkedStudentsResolved.value &&
          !_studentContext.hasLinkedStudents) {
        return l10n.noChildrenLinkedYet;
      }
      return l10n.selectStudentToViewCalendar;
    }
    if (!_studentContext.isEnrolled.value) {
      return l10n.studentNotEnrolledForYear;
    }
    if (view.value == CalendarView.timetable) {
      return l10n.noClassesScheduledForDay;
    }
    return l10n.noSchoolEventsForPeriod;
  }

  List<CalendarSession> get sessionsForSelectedDay {
    final day = selectedDay.value;
    return sessions.value.where((session) => session.occursOn(day)).toList()
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
    final generation = ++_loadGeneration;
    final studentId = _studentContext.activeStudentId;
    final requestedWeek = weekStart.value;
    final yearId = _academicYear.selectedYearId.value;

    bool isCurrent() =>
        generation == _loadGeneration &&
        studentId == _studentContext.activeStudentId &&
        yearId == _academicYear.selectedYearId.value &&
        requestedWeek == weekStart.value;
    sessions(const []);
    events(const []);
    if (studentId == null || yearId == null) {
      sessions(const []);
      events(const []);
      errorMessage('');
      return;
    }

    errorMessage('');
    await runTask(() async {
      final client = _schoolClient();
      if (!isCurrent()) return;
      final range = planningDateRangeForWeek(requestedWeek);
      Object? sessionsError;
      Object? eventsError;

      try {
        final occurrences = await fetchStudentTimetableOccurrences(
          client,
          studentId,
          range: range,
        );
        if (!isCurrent()) return;
        sessions(
          occurrences
              .map(CalendarSession.fromOccurrence)
              .toList(growable: false),
        );
      } on api.ApiError catch (error) {
        if (!isCurrent()) return;
        sessionsError = error;
        sessions(const []);
      } on Object catch (error) {
        if (!isCurrent()) return;
        sessionsError = error;
        sessions(const []);
      }

      try {
        final eventRows = await client.calendarEvents.list(
          academicYearScope(yearId),
        );
        if (!isCurrent()) return;
        events(eventRows.map(SchoolEvent.fromJson).toList(growable: false));
      } on api.ApiError catch (error) {
        if (!isCurrent()) return;
        eventsError = error;
        events(const []);
      } on Object catch (error) {
        if (!isCurrent()) return;
        eventsError = error;
        events(const []);
      }

      if (sessionsError != null && eventsError != null) {
        errorMessage(
          systemL10n().couldNotLoadCalendar(sessionsError.toString()),
        );
      } else {
        errorMessage('');
      }
    });
  }
}
