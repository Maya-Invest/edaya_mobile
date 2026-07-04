import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'calendar_controller.dart';
import 'widgets/school_event_tile.dart';
import 'widgets/session_tile.dart';
import 'widgets/week_day_selector.dart';

class CalendarPage extends LScopedView<CalendarController> {
  const CalendarPage({super.key});

  @override
  CalendarController onConfigScope(LevitScope scope) {
    return scope.put(
      () => CalendarController(
        studentContext: scope.find<StudentContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, CalendarController controller) {
    return LWatch(
      () {
        final status = controller.dataStatus;

        return DataState(
          status: status,
          errorMessage: controller.errorMessage.value,
          emptyMessage: controller.emptyMessage,
          onRetry: controller.loadCalendarData,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SegmentedButton<CalendarView>(
                  segments: [
                    ButtonSegment(
                      value: CalendarView.timetable,
                      label: Text(context.tr.calendarViewTimetable),
                      icon: const Icon(Icons.schedule),
                    ),
                    ButtonSegment(
                      value: CalendarView.events,
                      label: Text(context.tr.calendarViewEvents),
                      icon: const Icon(Icons.event),
                    ),
                  ],
                  selected: {controller.view.value},
                  onSelectionChanged: (selection) {
                    controller.selectView(selection.first);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: WeekDaySelector(
                  days: controller.weekDays,
                  selectedDay: controller.selectedDay.value,
                  onDaySelected: controller.selectDay,
                  onPreviousWeek: () => controller.shiftWeek(-1),
                  onNextWeek: () => controller.shiftWeek(1),
                ),
              ),
              if (controller.view.value == CalendarView.timetable)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.push('/calendar/attendance'),
                    icon: const Icon(Icons.list_alt_outlined),
                    label: Text(context.tr.allAttendance),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.loadCalendarData,
                  child: _CalendarBody(controller: controller),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.view.value == CalendarView.events) {
      final dayEvents = controller.eventsForSelectedDay;
      if (dayEvents.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 48),
            Center(child: Text(controller.emptyMessage)),
          ],
        );
      }

      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: dayEvents.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return SchoolEventTile(event: dayEvents[index]);
        },
      );
    }

    final daySessions = controller.sessionsForSelectedDay;
    if (daySessions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 48),
          Center(child: Text(controller.emptyMessage)),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: daySessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = daySessions[index];
        return SessionTile(
          session: session,
          onTap: () => context.push(
            '/calendar/session-details',
            extra: session,
          ),
        );
      },
    );
  }
}
