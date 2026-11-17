import '../context/teacher_context_controller.dart';
import '../../app/workspace_navigation.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';
import 'live_calendar_controller.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveCalendarPage();
    }
    return const _MockCalendarPage();
  }
}

class _MockCalendarPage extends LScopedView<StoreBoundController> {
  const _MockCalendarPage();

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final selectedId = GoRouterState.of(context).pathParameters['id'];

    return AdaptiveContent(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PrototypeSpacing.md,
              PrototypeSpacing.sm,
              PrototypeSpacing.md,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final picked = await showWorkspaceDatePicker(
                    context: context,
                    initialDate: store.selectedCalendarDate,
                    firstDate: DateTime(2018),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) store.selectCalendarDate(picked);
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(formatDate(store.selectedCalendarDate)),
              ),
            ),
          ),
          _WeekSelector(
            weekStart: store.dateForWeekDay(0),
            selectedDay: store.selectedCalendarDate,
            onSelectDay: (day) => store.selectCalendarDate(day),
          ),
          Expanded(
            child: store.selectedDaySessions.isEmpty
                ? EmptyState(title: context.tr.noSessionsToday)
                : ListView.separated(
                    padding: const EdgeInsets.all(PrototypeSpacing.md),
                    itemCount: store.selectedDaySessions.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: PrototypeSpacing.xs),
                    itemBuilder: (context, i) {
                      final s = store.selectedDaySessions[i];
                      final selected = selectedId == s.id;
                      return ListRow(
                        title: '${s.classLabel} · ${s.subject}',
                        subtitle: [
                          '${formatTimeRange(s.startHour, s.endHour)} · ${s.room}',
                          [
                            if (!s.attendanceComplete) context.tr.attendance,
                            if (!s.logbookComplete) context.tr.logbook,
                          ].join(' · '),
                        ].where((line) => line.isNotEmpty).join('\n'),
                        selected: selected,
                        onTap: () => context.push('/session/${s.id}'),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LiveCalendarPage extends LView<LiveCalendarController> {
  const _LiveCalendarPage();

  @override
  Widget buildView(BuildContext context, LiveCalendarController controller) {
    controller.start();
    return LWatch(() {
      controller.sessions.value;
      controller.selectedDay.value;
      controller.weekStart.value;
      controller.attendanceCompletionBySessionId.value;
      controller.logbookCompleteBySessionId.value;
      controller.errorMessage.value;
      final selectedId = GoRouterState.of(context).pathParameters['id'];
      final sessions = controller.sessionsForSelectedDay;
      final completion = controller.attendanceCompletionBySessionId.value;
      final logbookComplete = controller.logbookCompleteBySessionId.value;
      return AdaptiveContent(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PrototypeSpacing.md,
                PrototypeSpacing.sm,
                PrototypeSpacing.md,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await showWorkspaceDatePicker(
                      context: context,
                      initialDate: controller.selectedDay.value,
                      firstDate: DateTime(2018),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) controller.goToDate(picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(formatDate(controller.selectedDay.value)),
                ),
              ),
            ),
            _WeekSelector(
              weekStart: controller.weekStart.value,
              selectedDay: controller.selectedDay.value,
              onSelectDay: controller.goToDate,
            ),
            Expanded(
              child: controller.errorMessage.value.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(controller.errorMessage.value),
                          TextButton(
                            onPressed: controller.loadCalendarData,
                            child: Text(context.tr.retry),
                          ),
                        ],
                      ),
                    )
                  : controller.isBusy.value && sessions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : sessions.isEmpty
                  ? EmptyState(
                      title: context.tr.noSessionsToday,
                      message: controller.errorMessage.value,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(PrototypeSpacing.md),
                      itemCount: sessions.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: PrototypeSpacing.xs),
                      itemBuilder: (context, i) {
                        final s = sessions[i];
                        final selected = selectedId == s.id;
                        final attendanceDone =
                            completion[s.id]?.isComplete ?? false;
                        final cahierDone = logbookComplete[s.id] ?? false;
                        return ListRow(
                          key: ValueKey('agenda-lesson-${s.id}'),
                          title: '${s.classLabel} · ${s.subjectLabel}',
                          subtitle: [
                            formatClockRange(
                              context.levit
                                  .find<TeacherContextController>()
                                  .schoolTime(s.startsAt),
                              context.levit
                                  .find<TeacherContextController>()
                                  .schoolTime(s.endsAt),
                            ),
                            [
                              if (s.kind == 'lesson' && !attendanceDone)
                                context.tr.attendance,
                              if (s.kind == 'lesson' && !cahierDone)
                                context.tr.logbook,
                            ].join(' · '),
                          ].where((line) => line.isNotEmpty).join('\n'),
                          selected: selected,
                          onTap: () => context.push('/session/${s.id}'),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({
    required this.weekStart,
    required this.selectedDay,
    required this.onSelectDay,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PrototypeSpacing.md,
        vertical: PrototypeSpacing.sm,
      ),
      child: CalendarWeekStrip(
        days: List.generate(7, (i) => weekStart.add(Duration(days: i))),
        selected: selectedDay,
        onSelected: onSelectDay,
        daySpacing: PrototypeSpacing.xxs,
        onPreviousWeek: () => onSelectDay(
          DateTime(selectedDay.year, selectedDay.month, selectedDay.day - 7),
        ),
        onNextWeek: () => onSelectDay(
          DateTime(selectedDay.year, selectedDay.month, selectedDay.day + 7),
        ),
      ),
    );
  }
}
