import 'package:flutter/material.dart';

import 'package:edaya_shared/edaya_shared.dart';

class WeekDaySelector extends StatelessWidget {
  const WeekDaySelector({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.weekStart,
    required this.onDaySelected,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onPickDate,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final DateTime weekStart;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final ValueChanged<DateTime> onPickDate;

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.tr.dayLetterMon,
      context.tr.dayLetterTue,
      context.tr.dayLetterWed,
      context.tr.dayLetterThu,
      context.tr.dayLetterFri,
      context.tr.dayLetterSat,
      context.tr.dayLetterSun,
    ];

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: context.tr.tooltipPreviousWeek,
              onPressed: onPreviousWeek,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showDatePicker(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          context.formatWeekRange(weekStart),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: context.tr.tooltipNextWeek,
              onPressed: onNextWeek,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < days.length; index++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DayChip(
                    label: labels[index],
                    dayNumber: days[index].day,
                    selected: isSameCalendarDay(days[index], selectedDay),
                    onTap: () => onDaySelected(days[index]),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(selectedDay.year - 2),
      lastDate: DateTime(selectedDay.year + 2),
    );
    if (picked != null) {
      onPickDate(picked);
    }
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.dayNumber,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int dayNumber;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = selected
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final foreground = selected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: foreground),
              ),
              const SizedBox(height: 4),
              Text(
                '$dayNumber',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
