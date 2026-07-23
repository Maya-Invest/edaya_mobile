import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/session_category.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import 'calendar_controller.dart';

class CalendarPage extends LScopedView<CalendarController> {
  const CalendarPage({super.key});

  @override
  CalendarController onConfigScope(LevitScope scope) {
    return scope.put(() => CalendarController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, CalendarController controller) {
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
          child: Row(
            children: [
              Flexible(child: _CalendarDatePicker(store: store)),
              TextButton.icon(
                onPressed: () => context.go('/attendance'),
                icon: const Icon(Icons.list_alt_outlined, size: 18),
                label: const Text('Toutes les présences'),
              ),
            ],
          ),
        ),
        _WeekSelector(store: store),
        Expanded(child: _MergedDayList(store: store)),
      ],
      ),
    );
  }
}

class _CalendarDatePicker extends StatelessWidget {
  const _CalendarDatePicker({required this.store});

  final MockStore store;

  Future<void> _pickDate(BuildContext context) async {
    final selected = store.selectedCalendarDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2018),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      store.selectCalendarDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _pickDate(context),
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(formatDate(store.selectedCalendarDate)),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({required this.store});
  final MockStore store;

  static const _dayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  bool _showsMonthLabel(List<DateTime> weekDates, int index) {
    if (index == 0) return true;
    final current = weekDates[index];
    final previous = weekDates[index - 1];
    return current.month != previous.month;
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = List.generate(7, store.dateForWeekDay);
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
            onPressed: store.goToPreviousWeek,
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
                                  formatMonthAbbrev(weekDates[i]),
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
                              backgroundColor: store.selectedDayIndex == i
                                  ? PrototypeColors.primary
                                  : PrototypeColors.surface,
                              foregroundColor: store.selectedDayIndex == i
                                  ? Colors.white
                                  : PrototypeColors.onBackground,
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            onPressed: () => store.selectDay(i),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _dayLabels[i],
                                  style: const TextStyle(fontSize: 10),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatDayOfMonth(weekDates[i]),
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
            onPressed: store.goToNextWeek,
            icon: const Icon(Icons.chevron_right),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _MergedDayList extends StatelessWidget {
  const _MergedDayList({required this.store});

  final MockStore store;

  @override
  Widget build(BuildContext context) {
    final noSchoolDay = store.noSchoolDayForSelectedDay;
    final schoolEvents = store.schoolEventsForSelectedDay;
    final sessions = store.sessionsForSelectedDay;
    final hasContent =
        noSchoolDay != null || schoolEvents.isNotEmpty || sessions.isNotEmpty;

    if (!hasContent) {
      return const EmptyState(title: 'Rien de prévu ce jour');
    }

    return ListView(
      padding: const EdgeInsets.all(PrototypeSpacing.md),
      children: [
        if (noSchoolDay != null) ...[
          NoSchoolDayBanner(event: noSchoolDay),
          if (schoolEvents.isNotEmpty || sessions.isNotEmpty)
            const SizedBox(height: PrototypeSpacing.sm),
        ],
        for (var i = 0; i < schoolEvents.length; i++) ...[
          if (i > 0) const SizedBox(height: PrototypeSpacing.xs),
          SchoolEventRow(event: schoolEvents[i]),
        ],
        if (schoolEvents.isNotEmpty && sessions.isNotEmpty)
          const SizedBox(height: PrototypeSpacing.sm),
        if (sessions.isNotEmpty && (noSchoolDay != null || schoolEvents.isNotEmpty))
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
            title: sessions[i].subject,
            subtitle:
                '${formatTimeRange(sessions[i].startHour, sessions[i].endHour)} · ${sessions[i].teacher}',
            leading: SessionCategoryIcon(category: sessions[i].category),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/session/${sessions[i].id}'),
          ),
        ],
      ],
    );
  }
}
