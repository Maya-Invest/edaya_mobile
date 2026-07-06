import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_api_client/edaya_api_client.dart' show SchoolClient;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/l10n/l10n_lookup.dart';
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
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

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
    if (!_studentContext.isEnrolled.value) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage {
    final l10n = systemL10n();
    if (_studentContext.activeStudent.value == null) {
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
    return sessions.value
        .where((session) => session.occursOn(day))
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
      final client = _schoolClient();
      final range = planningDateRangeForWeek(weekStart.value);
      Object? sessionsError;
      Object? eventsError;

      try {
        final occurrences = await fetchClassTimetableOccurrences(
          client,
          classGroupId,
          range: range,
        );
        sessions(
          occurrences
              .map(CalendarSession.fromOccurrence)
              .toList(growable: false),
        );
      } on api.ApiError catch (error) {
        sessionsError = error;
        sessions(const []);
      } on Object catch (error) {
        sessionsError = error;
        sessions(const []);
      }

      try {
        final eventRows = await client.calendarEvents.list(
          academicYearScope(yearId),
        );
        events(
          eventRows.map(SchoolEvent.fromJson).toList(growable: false),
        );
      } on api.ApiError catch (error) {
        eventsError = error;
        events(const []);
      } on Object catch (error) {
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

class SessionDetailsController extends LevitController
    with LevitReactiveTasksMixin {
  SessionDetailsController({
    required this.session,
    required StudentContextController studentContext,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _schoolClient = schoolClient;

  final CalendarSession session;
  final StudentContextController _studentContext;
  final SchoolClientFactory _schoolClient;

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
        final client = _schoolClient();
        final attendanceRows = await client.attendance.list({
          ...attendanceForOccurrence(
            kind: session.kind,
            occurrenceId: session.id,
          ),
          'studentId': studentId,
        });
        attendance(
          attendanceRows.isEmpty
              ? null
              : AttendanceRecord.fromJson(attendanceRows.first),
        );

        logbook(await _loadLogbook(client));
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadSessionDetails(error.toString()));
      }
    }, id: 'load-session-details');
  }

  Future<LogbookEntry?> _loadLogbook(api.SchoolClient client) async {
    if (session.kind != 'lesson' || session.classSubjectId == null) {
      if (session.kind == 'activity') {
        return _loadActivityLogbook(client);
      }
      return null;
    }

    List<Map<String, dynamic>> progressRows = const [];
    try {
      progressRows = await client.classSubjectProgress.list(
        progressForLessonSessions([session.id]),
      );
    } on api.ApiError catch (error) {
      if (error.status != 404 && error.status != 403) {
        rethrow;
      }
    }

    Map<String, dynamic>? lessonSession;
    try {
      lessonSession = await client.lessonSessions.get(session.id);
    } on api.ApiError catch (error) {
      if (error.status != 404 && error.status != 403) {
        rethrow;
      }
    }

    final sessionNote = lessonSession?['sessionNote'] as String?;
    final primaryProgress = progressRows.isEmpty ? null : progressRows.first;
    if (sessionNote == null && primaryProgress == null) {
      return null;
    }

    String chapter = session.title;
    if (primaryProgress != null) {
      try {
        final matterLinks = await client.classSubjectMatters.list({
          'classSubjectId': session.classSubjectId,
        });
        final matterLink = _firstWhereOrNull<Map<String, dynamic>>(
          matterLinks.cast<Map<String, dynamic>>(),
          (link) => link['id'] == primaryProgress['classSubjectMatterId'],
        );
        final subjectMatterId = matterLink?['subjectMatterId'] as String?;
        if (subjectMatterId != null) {
          final subjectMatter = await client.subjectMatters.get(subjectMatterId);
          chapter = subjectMatter['name'] as String? ?? chapter;
        }
      } on Object {
        chapter = session.title;
      }
    }

    return LogbookEntry(
      id: primaryProgress?['id'] as String? ?? session.id,
      chapter: chapter,
      content: sessionNote ?? primaryProgress?['notes'] as String? ?? '',
      objectives: primaryProgress?['notes'] != null
          ? [primaryProgress!['notes'] as String]
          : const [],
      progress: (primaryProgress?['completedPercentage'] as num?)?.toInt() ?? 0,
      date: session.startsAt,
    );
  }

  Future<LogbookEntry?> _loadActivityLogbook(api.SchoolClient client) async {
    try {
      final activitySession = await client.activitySessions.get(session.id);
      final notes = activitySession['notes'] as String?;
      if (notes == null || notes.isEmpty) {
        return null;
      }
      return LogbookEntry(
        id: session.id,
        chapter: session.title,
        content: notes,
        objectives: const [],
        progress: 0,
        date: session.startsAt,
      );
    } on api.ApiError catch (error) {
      if (error.status == 404 || error.status == 403) {
        return null;
      }
      rethrow;
    } on Object {
      return null;
    }
  }
}

class AttendanceListController extends LevitController
    with LevitReactiveTasksMixin {
  AttendanceListController({
    required StudentContextController studentContext,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _schoolClient = schoolClient;

  final StudentContextController _studentContext;
  final SchoolClientFactory _schoolClient;

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
        final client = _schoolClient();
        final rows = await client.attendance.list(studentScope(studentId));
        final parsed = rows.map(AttendanceRecord.fromJson).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        records(parsed);

        final sessionIds = parsed.map((record) => record.occurrenceId).toSet();
        final titles = <String, String>{};
        for (final occurrenceId in sessionIds) {
          final record = parsed.firstWhere(
            (entry) => entry.occurrenceId == occurrenceId,
          );
          try {
            final title = await _resolveOccurrenceTitle(
              client,
              occurrenceId: occurrenceId,
              kind: record.occurrenceKind,
            );
            titles[occurrenceId] = title;
          } on Object {
            titles[occurrenceId] = occurrenceId;
          }
        }
        sessionTitles(titles);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadAttendance(error.toString()));
        records(const []);
      }
    }, id: 'load-attendance-list');
  }
}

Future<String> _resolveOccurrenceTitle(
  SchoolClient client, {
  required String occurrenceId,
  required String kind,
}) async {
  switch (kind) {
    case 'activity':
      try {
        final session = await client.activitySessions.get(occurrenceId);
        return session['displayLabel'] as String? ??
            session['title'] as String? ??
            occurrenceId;
      } on api.ApiError catch (error) {
        if (error.status != 404) {
          rethrow;
        }
      }
      return occurrenceId;
    case 'assessment':
      final assessment = await client.assessments.get(occurrenceId);
      return assessment['title'] as String? ?? occurrenceId;
    default:
      try {
        final session = await client.lessonSessions.get(occurrenceId);
        return session['displayLabel'] as String? ??
            session['title'] as String? ??
            occurrenceId;
      } on api.ApiError catch (error) {
        if (error.status != 404) {
          rethrow;
        }
      }
      return occurrenceId;
  }
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
  for (final item in items) {
    if (test(item)) {
      return item;
    }
  }
  return null;
}
