import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'calendar_controller.dart';
import 'widgets/teacher_session_tile.dart';
import 'widgets/week_day_selector.dart';

class CalendarPage extends LScopedView<CalendarController> {
  const CalendarPage({super.key});

  @override
  CalendarController onConfigScope(LevitScope scope) {
    return AppRuntime.calendar;
  }

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
          onTap: () => context.push(
            '/calendar/session-details',
            extra: session,
          ),
        );
      },
    );
  }
}
