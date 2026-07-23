import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:intl/intl.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/session_category.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart' show HomeDayCategory;
import '../context/academic_year_controller.dart';
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
  final fmt = DateFormat('HH:mm', 'fr_FR');
  return '${fmt.format(session.startsAt)} – ${fmt.format(session.endsAt)}';
}

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
            child: Row(
              children: [
                Flexible(child: _CalendarDatePicker(controller: controller)),
                TextButton.icon(
                  onPressed: () => context.go('/attendance'),
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: const Text('Toutes les présences'),
                ),
              ],
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
      label: Text(DateFormat('d MMM yyyy', 'fr_FR').format(selected)),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({required this.controller});

  final CalendarController controller;

  static const _dayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  bool _showsMonthLabel(List<DateTime> weekDates, int index) {
    if (index == 0) return true;
    final current = weekDates[index];
    final previous = weekDates[index - 1];
    return current.month != previous.month;
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = controller.weekDays;
    final selected = controller.selectedDay.value;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 9,
      height: 1,
      color: PrototypeColors.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: PrototypeSpacing.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Semaine précédente',
            onPressed: () => controller.shiftWeek(-1),
            icon: const Icon(Icons.chevron_left),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: SizedBox(
                          height: 12,
                          child: _showsMonthLabel(weekDates, i)
                              ? Text(
                                  DateFormat('MMM', 'fr_FR')
                                      .format(weekDates[i])
                                      .replaceAll('.', '')
                                      .substring(0, 3),
                                  textAlign: TextAlign.center,
                                  style: labelStyle,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: PrototypeSpacing.xxs),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: isSameCalendarDay(
                                    weekDates[i],
                                    selected,
                                  )
                                  ? PrototypeColors.primary
                                  : PrototypeColors.surface,
                              foregroundColor: isSameCalendarDay(
                                    weekDates[i],
                                    selected,
                                  )
                                  ? Colors.white
                                  : PrototypeColors.onBackground,
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            onPressed: () => controller.selectDay(weekDates[i]),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _dayLabels[i],
                                  style: const TextStyle(fontSize: 10),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${weekDates[i].day}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Semaine suivante',
            onPressed: () => controller.shiftWeek(1),
            icon: const Icon(Icons.chevron_right),
            visualDensity: VisualDensity.compact,
          ),
        ],
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
            ? 'Impossible de charger le calendrier'
            : controller.errorMessage.value,
      );
    }
    if (controller.dataStatus == DataStatus.empty) {
      return EmptyState(title: controller.emptyMessage);
    }

    final sessions = controller.sessionsForSelectedDay;
    final events = controller.eventsForSelectedDay;
    final noSchoolDay = events.where((e) => e.isNonSchoolDay).firstOrNull;
    final schoolEvents = events.where((e) => !e.isNonSchoolDay).toList();
    final hasContent =
        noSchoolDay != null || schoolEvents.isNotEmpty || sessions.isNotEmpty;

    if (!hasContent) {
      return const EmptyState(title: 'Rien de prévu ce jour');
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
              'Emploi du temps',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: PrototypeColors.onSurfaceVariant,
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
            onTap: () => context.go('/session/${sessions[i].id}'),
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
      tint: PrototypeColors.errorContainer.withValues(alpha: 0.45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_busy_outlined, color: PrototypeColors.error),
          const SizedBox(width: PrototypeSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pas d\'école',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: PrototypeColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(event.title, style: Theme.of(context).textTheme.titleSmall),
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
          StatusChip(label: event.kind, tone: SemanticTone.error),
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
        event.kind,
        if ((event.description ?? '').isNotEmpty) event.description!,
      ].join(' · '),
      leading: const Icon(Icons.event_outlined),
    );
  }
}
