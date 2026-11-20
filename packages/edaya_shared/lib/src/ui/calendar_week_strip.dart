import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/edaya_tokens.g.dart';
import '../l10n/l10n_extension.dart';

/// A week of labeled, selected-state-aware targets that never shrink below 48dp.
/// Narrow windows and large text scroll horizontally instead of shrinking dates.
class CalendarWeekStrip extends StatelessWidget {
  const CalendarWeekStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelected,
    this.onPreviousWeek,
    this.onNextWeek,
    this.daySpacing = 0,
  });

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback? onPreviousWeek;
  final VoidCallback? onNextWeek;

  /// Optional separation between day buttons; minimum touch targets are retained.
  final double daySpacing;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onPreviousWeek != null || onNextWeek != null)
          Row(
            children: [
              IconButton(
                onPressed: onPreviousWeek,
                tooltip: context.tr.tooltipPreviousWeek,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${DateFormat.MMMd(locale).format(days.first)} – ${DateFormat.yMMMd(locale).format(days.last)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              IconButton(
                onPressed: onNextWeek,
                tooltip: context.tr.tooltipNextWeek,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = math.max(
              kMinInteractiveDimension *
                  math.max(1, MediaQuery.textScalerOf(context).scale(1)),
              (constraints.maxWidth - daySpacing * (days.length - 1)) /
                  days.length,
            );
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (index, day) in days.indexed) ...[
                    if (index > 0) SizedBox(width: daySpacing),
                    SizedBox(
                      width: width,
                      child: Semantics(
                        selected: DateUtils.isSameDay(day, selected),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: EdayaTokens.spaceXs,
                            ),
                            backgroundColor: DateUtils.isSameDay(day, selected)
                                ? colors.primary
                                : colors.surface,
                            foregroundColor: DateUtils.isSameDay(day, selected)
                                ? colors.onPrimary
                                : colors.onSurface,
                            minimumSize: const Size(
                              kMinInteractiveDimension,
                              kMinInteractiveDimension,
                            ),
                          ),
                          onPressed: () => onSelected(day),
                          child: Semantics(
                            label: MaterialLocalizations.of(
                              context,
                            ).formatFullDate(day),
                            excludeSemantics: true,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat.E(
                                    locale,
                                  ).format(day).replaceAll('.', ''),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: DateUtils.isSameDay(day, selected)
                                        ? colors.onPrimary
                                        : colors.onSurface,
                                  ),
                                ),
                                Text('${day.day}'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
