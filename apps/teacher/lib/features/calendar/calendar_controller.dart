import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/l10n/l10n_lookup.dart';
import '../context/academic_year_controller.dart';
import '../context/staff_context_controller.dart';
import 'models/teacher_session.dart';

class CalendarController extends LevitController with LevitReactiveTasksMixin {
  CalendarController({
    required StaffContextController staffContext,
    required AcademicYearController academicYear,
  }) : _staffContext = staffContext,
       _academicYear = academicYear;

  final StaffContextController _staffContext;
  final AcademicYearController _academicYear;

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
        .map((session) => session.projectOntoDay(day))
        .whereType<TeacherSession>()
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
        final client = AppRuntime.schoolClient();
        final classLabelById = {
          for (final assigned in _staffContext.assignedClasses.value)
            assigned.id: assigned.label,
        };

        final taughtIds = _staffContext.taughtClassSubjectIds.value.toList();
        final classSubjectRows = taughtIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.classSubjects.list(entitiesByIds(taughtIds));
        final subjectLabelByClassSubjectId = <String, String>{};
        final subjectIds = classSubjectRows
            .map((row) => row['subjectId'] as String?)
            .whereType<String>()
            .toSet()
            .toList();
        final subjectRows = subjectIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.subjects.list(entitiesByIds(subjectIds));
        final subjectNameById = {
          for (final subject in subjectRows)
            subject['id'] as String:
                subject['name'] as String? ?? systemL10n().subjectFallback,
        };
        for (final row in classSubjectRows) {
          final id = row['id'] as String;
          final subjectId = row['subjectId'] as String?;
          subjectLabelByClassSubjectId[id] = subjectId == null
              ? systemL10n().subjectFallback
              : subjectNameById[subjectId] ?? systemL10n().subjectFallback;
        }

        final parsedSessions = <TeacherSession>[];
        for (final classGroupId in classGroupIds) {
          final sessionRows = await client.sessions.list(
            classGroupScope(classGroupId),
          );
          for (final row in sessionRows) {
            final sessionId = row['id'] as String;
            final classSubjectId = row['classSubjectId'] as String?;
            if (!_staffContext.canTeachSession(
              sessionId: sessionId,
              classGroupId: classGroupId,
              classSubjectId: classSubjectId,
            )) {
              continue;
            }

            parsedSessions.add(
              TeacherSession.fromJson(
                row,
                classGroupId: classGroupId,
                classLabel: classLabelById[classGroupId] ?? classGroupId,
                subjectLabel: classSubjectId == null
                    ? systemL10n().classSessionFallback
                    : subjectLabelByClassSubjectId[classSubjectId] ??
                          systemL10n().subjectFallback,
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
