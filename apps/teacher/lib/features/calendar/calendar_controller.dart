import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/l10n/l10n_lookup.dart';
import '../context/academic_year_controller.dart';
import '../context/staff_context_controller.dart';
import 'models/teacher_session.dart';

class CalendarController extends LevitController with LevitReactiveTasksMixin {
  CalendarController({
    required StaffContextController staffContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _staffContext = staffContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final StaffContextController _staffContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final weekStart = LxVar(startOfWeek(defaultCalendarDay()));
  final selectedDay = LxVar(defaultCalendarDay());
  final sessions = LxVar<List<TeacherSession>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(weekStart);
    autoDispose(selectedDay);
    autoDispose(sessions);
    autoDispose(errorMessage);

    for (final subscription in [
      _staffContext.assignedClasses.stream,
      _staffContext.classFilterId.stream,
      _staffContext.taughtClassSubjectIds.stream,
      _staffContext.assignedClassGroupIds.stream,
      _staffContext.isLoading.stream,
      _academicYear.selectedYearId.stream,
      weekStart.stream,
    ]) {
      autoDispose(subscription.listen((_) => unawaited(loadCalendarData())));
    }

    unawaited(loadCalendarData());
  }

  DataStatus get dataStatus {
    if (_staffContext.isLoading.value && sessions.value.isEmpty) {
      return DataStatus.loading;
    }
    if (isBusy.value && sessions.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && sessions.value.isEmpty) {
      return DataStatus.error;
    }
    if (_staffContext.errorMessage.value.isNotEmpty &&
        sessions.value.isEmpty) {
      return DataStatus.error;
    }
    if (_staffContext.staffId.value == null) {
      return DataStatus.empty;
    }
    if (_staffContext.assignedClasses.value.isEmpty) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage {
    if (_staffContext.staffId.value == null) {
      return systemL10n().signInToViewCalendar;
    }
    if (_staffContext.assignedClasses.value.isEmpty) {
      return systemL10n().noClassesAssignedForYear;
    }
    return systemL10n().noClassesScheduledForDay;
  }

  List<TeacherSession> get sessionsForSelectedDay {
    final day = selectedDay.value;
    return sessions.value
        .where((session) => session.occursOn(day))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  String get displayErrorMessage {
    if (errorMessage.value.isNotEmpty) {
      return errorMessage.value;
    }
    return _staffContext.errorMessage.value;
  }

  List<DateTime> get weekDays {
    final start = weekStart.value;
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }

  void selectDay(DateTime day) {
    selectedDay(DateTime(day.year, day.month, day.day));
  }

  void shiftWeek(int deltaWeeks) {
    final nextWeek = weekStart.value.add(Duration(days: 7 * deltaWeeks));
    weekStart(nextWeek);
    selectedDay(nextWeek);
  }

  void goToDate(DateTime day) {
    final calendarDay = DateTime(day.year, day.month, day.day);
    weekStart(startOfWeek(calendarDay));
    selectedDay(calendarDay);
  }

  Future<void> loadCalendarData() async {
    if (_staffContext.isLoading.value || _staffContext.staffId.value == null) {
      return;
    }

    final classGroupIds = _staffContext.visibleClassGroupIds;
    if (classGroupIds.isEmpty) {
      sessions(const []);
      errorMessage('');
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final classLabelById = {
          for (final assigned in _staffContext.assignedClasses.value)
            assigned.id: assigned.label,
        };
        final range = planningDateRangeForWeek(weekStart.value);
        final parsedSessions = <TeacherSession>[];

        for (final classGroupId in classGroupIds) {
          final occurrences = await fetchClassTimetableOccurrences(
            client,
            classGroupId,
            range: range,
            unassignedTeacherLabel: systemL10n().teacherFallbackName,
          );
          for (final occurrence in occurrences) {
            if (!_staffContext.canTeachSession(
              sessionId: occurrence.id,
              classGroupId: classGroupId,
              classSubjectId: occurrence.classSubjectId,
            )) {
              continue;
            }

            parsedSessions.add(
              TeacherSession.fromOccurrence(
                occurrence,
                classLabel: classLabelById[classGroupId] ?? classGroupId,
              ),
            );
          }
        }

        parsedSessions.sort((a, b) => a.startsAt.compareTo(b.startsAt));
        sessions(parsedSessions);
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadCalendar('$error'));
        sessions(const []);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadCalendar('$error'));
        sessions(const []);
      }
    });
  }
}
