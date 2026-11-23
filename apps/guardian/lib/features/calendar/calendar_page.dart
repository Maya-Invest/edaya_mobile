import 'session_history_page.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:intl/intl.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/session_category.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_mappers.dart';
import '../../mock/mock_store.dart' show HomeDayCategory, MockStore;
import '../context/academic_year_controller.dart';
import '../context/store_bound_controller.dart';
import '../context/student_context_controller.dart';
import 'models/calendar_session.dart';
import 'models/school_event.dart';
import 'calendar_controller.dart';

HomeDayCategory _categoryForKind(String kind) {
  return switch (kind) {
    'activity' => HomeDayCategory.activity,
    'assessment' => HomeDayCategory.assessment,
    _ => HomeDayCategory.lesson,
  };
}

String _formatSessionTime(CalendarSession session) {
  final fmt = AppDateFormatting.clockFormat(
    AppSettingsStorage.cached.timeFormat,
    systemL10n().localeName,
  );
  return '${fmt.format(session.startsAt)} – ${fmt.format(session.endsAt)}';
}

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkspaceTabs(
      values: const ['schedule', 'history'],
      labels: [context.tr.workspaceSchedule, context.tr.workspaceHistory],
      children: [
        prototypeIsLive(context)
            ? const _LiveCalendarPage()
            : const _MockCalendarPage(),
        const SessionHistoryPage(),
      ],
    );
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
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: store.selectedCalendarDate,
                      firstDate: DateTime(2018),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) store.selectCalendarDate(picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    DateFormat.yMMMd(
                      context.tr.localeName,
                    ).format(store.selectedCalendarDate),
                  ),
                ),
              ],
            ),
          ),
          _MockWeekSelector(store: store),
          Expanded(
            child: _MockMergedDayList(
              sessions: store.sessionsForSelectedDay
                  .map(calendarSessionFromMock)
                  .where((s) => s.endsAt.isAfter(SchoolClock.now()))
                  .toList(),
              events: store.eventsForSelectedDay
                  .map(schoolEventFromMock)
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockWeekSelector extends StatelessWidget {
  const _MockWeekSelector({required this.store});

  final MockStore store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PrototypeSpacing.sm),
      child: CalendarWeekStrip(
        days: List.generate(7, store.dateForWeekDay),
        selected: store.selectedCalendarDate,
        onSelected: store.selectCalendarDate,
        onPreviousWeek: store.goToPreviousWeek,
        onNextWeek: store.goToNextWeek,
      ),
    );
  }
}

class _MockMergedDayList extends StatelessWidget {
  const _MockMergedDayList({required this.sessions, required this.events});

  final List<CalendarSession> sessions;
  final List<SchoolEvent> events;

  @override
  Widget build(BuildContext context) {
    final noSchoolDay = events.where((e) => e.isNonSchoolDay).firstOrNull;
    final schoolEvents = events.where((e) => !e.isNonSchoolDay).toList();
    final hasContent =
        noSchoolDay != null || schoolEvents.isNotEmpty || sessions.isNotEmpty;
    if (!hasContent) {
      return EmptyState(title: context.tr.nothingScheduledForThisDay);
    }
    return _DayAgenda(
      noSchoolDay: noSchoolDay,
      schoolEvents: schoolEvents,
      sessions: sessions,
    );
  }
}

class _LiveCalendarPage extends LScopedView<CalendarController> {
  const _LiveCalendarPage();

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
    // Subscribe under LScopedView autoWatch (child widgets alone do not).
    controller.isBusy.value;
    controller.sessions.value;
    controller.events.value;
    controller.selectedDay.value;
    controller.weekStart.value;
    controller.errorMessage.value;
    controller.view.value;

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
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [_CalendarDatePicker(controller: controller)],
            ),
          ),
          _WeekSelector(controller: controller),
          Expanded(child: _MergedDayList(controller: controller)),
        ],
      ),
    );
  }
}

class _CalendarDatePicker extends StatelessWidget {
  const _CalendarDatePicker({required this.controller});

  final CalendarController controller;

  Future<void> _pickDate(BuildContext context) async {
    final selected = controller.selectedDay.value;
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2018),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      controller.selectDay(picked);
      controller.weekStart(startOfWeek(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedDay.value;
    return TextButton.icon(
      onPressed: () => _pickDate(context),
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(DateFormat.yMMMd(context.tr.localeName).format(selected)),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PrototypeSpacing.sm),
      child: CalendarWeekStrip(
        days: controller.weekDays,
        selected: controller.selectedDay.value,
        onSelected: controller.selectDay,
        onPreviousWeek: () => controller.shiftWeek(-1),
        onNextWeek: () => controller.shiftWeek(1),
      ),
    );
  }
}

class _MergedDayList extends StatelessWidget {
  const _MergedDayList({required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.dataStatus == DataStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.dataStatus == DataStatus.error) {
      return EmptyState(
        title: controller.errorMessage.value.isEmpty
            ? context.tr.couldNotLoadTheCalendar
            : controller.errorMessage.value,
      );
    }
    if (controller.dataStatus == DataStatus.empty) {
      return EmptyState(title: controller.emptyMessage);
    }

    final sessions = controller.sessionsForSelectedDay
        .where((s) => s.endsAt.isAfter(SchoolClock.now()))
        .toList();
    final events = controller.eventsForSelectedDay;
    final noSchoolDay = events.where((e) => e.isNonSchoolDay).firstOrNull;
    final schoolEvents = events.where((e) => !e.isNonSchoolDay).toList();
    final hasContent =
        noSchoolDay != null || schoolEvents.isNotEmpty || sessions.isNotEmpty;

    if (!hasContent) {
      return EmptyState(title: context.tr.nothingScheduledForThisDay);
    }

    return ListView(
      padding: const EdgeInsets.all(PrototypeSpacing.md),
      children: [
        if (noSchoolDay != null) ...[
          _NoSchoolBanner(event: noSchoolDay),
          if (schoolEvents.isNotEmpty || sessions.isNotEmpty)
            const SizedBox(height: PrototypeSpacing.sm),
        ],
        for (var i = 0; i < schoolEvents.length; i++) ...[
          if (i > 0) const SizedBox(height: PrototypeSpacing.xs),
          _SchoolEventRow(event: schoolEvents[i]),
        ],
        if (schoolEvents.isNotEmpty && sessions.isNotEmpty)
          const SizedBox(height: PrototypeSpacing.sm),
        if (sessions.isNotEmpty &&
            (noSchoolDay != null || schoolEvents.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: PrototypeSpacing.xs),
            child: Text(
              context.tr.calendarViewTimetable,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (var i = 0; i < sessions.length; i++) ...[
          if (i > 0) const SizedBox(height: PrototypeSpacing.xs),
          ListRow(
            title: sessions[i].subjectLabel ?? sessions[i].title,
            subtitle: _formatSessionTime(sessions[i]),
            leading: SessionCategoryIcon(
              category: _categoryForKind(sessions[i].kind),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              '/session/${Uri.encodeComponent(sessions[i].id)}',
              extra: sessions[i].kind,
            ),
          ),
        ],
      ],
    );
  }
}

class _DayAgenda extends StatelessWidget {
  const _DayAgenda({
    required this.noSchoolDay,
    required this.schoolEvents,
    required this.sessions,
  });

  final SchoolEvent? noSchoolDay;
  final List<SchoolEvent> schoolEvents;
  final List<CalendarSession> sessions;

  @override
  Widget build(BuildContext context) {
    final closedDay = noSchoolDay;
    return ListView(
      padding: const EdgeInsets.all(PrototypeSpacing.md),
      children: [
        if (closedDay != null) ...[
          _NoSchoolBanner(event: closedDay),
          if (schoolEvents.isNotEmpty || sessions.isNotEmpty)
            const SizedBox(height: PrototypeSpacing.sm),
        ],
        for (var i = 0; i < schoolEvents.length; i++) ...[
          if (i > 0) const SizedBox(height: PrototypeSpacing.xs),
          _SchoolEventRow(event: schoolEvents[i]),
        ],
        if (schoolEvents.isNotEmpty && sessions.isNotEmpty)
          const SizedBox(height: PrototypeSpacing.sm),
        if (sessions.isNotEmpty &&
            (closedDay != null || schoolEvents.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: PrototypeSpacing.xs),
            child: Text(
              context.tr.calendarViewTimetable,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (var i = 0; i < sessions.length; i++) ...[
          if (i > 0) const SizedBox(height: PrototypeSpacing.xs),
          ListRow(
            title: sessions[i].subjectLabel ?? sessions[i].title,
            subtitle: _formatSessionTime(sessions[i]),
            leading: SessionCategoryIcon(
              category: _categoryForKind(sessions[i].kind),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              '/session/${Uri.encodeComponent(sessions[i].id)}',
              extra: sessions[i].kind,
            ),
          ),
        ],
      ],
    );
  }
}

class _NoSchoolBanner extends StatelessWidget {
  const _NoSchoolBanner({required this.event});

  final SchoolEvent event;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      tint: Theme.of(
        context,
      ).colorScheme.errorContainer.withValues(alpha: 0.45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_busy_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: PrototypeSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.noSchool,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if ((event.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          StatusChip(
            label: event.kindLabel(context.tr),
            tone: SemanticTone.error,
          ),
        ],
      ),
    );
  }
}

class _SchoolEventRow extends StatelessWidget {
  const _SchoolEventRow({required this.event});

  final SchoolEvent event;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: event.title,
      subtitle: [
        event.kindLabel(context.tr),
        if ((event.description ?? '').isNotEmpty) event.description!,
      ].join(' · '),
      leading: const Icon(Icons.event_outlined),
    );
  }
}
