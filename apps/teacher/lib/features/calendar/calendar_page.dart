import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../../navigation/teacher_route_paths.dart';
import 'calendar_controller.dart';
import 'widgets/calendar_today_segment.dart';
import 'widgets/teacher_session_tile.dart';
import 'widgets/week_day_selector.dart';

class CalendarPage extends LView<CalendarController> {
  const CalendarPage({super.key});

  @override
  Widget buildView(BuildContext context, CalendarController controller) {
    return LWatch(
      () => DataState(
        status: controller.dataStatus,
        errorMessage: controller.displayErrorMessage,
        emptyMessage: controller.emptyMessage,
        onRetry: controller.loadCalendarData,
        child: Column(
          children: [
            LWatch(
              () => CalendarTodaySegment(
                focus: controller.todayFocus,
                incompleteAttendanceSessions:
                    controller.incompleteAttendanceSessions,
                showGoToToday: !controller.isSelectedDayToday,
                onGoToToday: controller.goToToday,
                onSessionTap: (session) =>
                    context.push(TeacherRoutePaths.session(session.id)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: WeekDaySelector(
                days: controller.weekDays,
                selectedDay: controller.selectedDay.value,
                weekStart: controller.weekStart.value,
                onDaySelected: controller.selectDay,
                onPreviousWeek: () => controller.shiftWeek(-1),
                onNextWeek: () => controller.shiftWeek(1),
                onPickDate: controller.goToDate,
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
      ),
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
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
        return TeacherSessionTile(
          session: session,
          completion: controller.completionForSession(session.id),
          onTap: () =>
              context.push(TeacherRoutePaths.session(session.id)),
        );
      },
    );
  }
}
