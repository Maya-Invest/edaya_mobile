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
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous week',
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
                          formatWeekRange(weekStart),
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
              tooltip: 'Next week',
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

    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(
                '$dayNumber',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
