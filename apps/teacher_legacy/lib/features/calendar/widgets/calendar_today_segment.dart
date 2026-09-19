import 'package:flutter/material.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../calendar_today_logic.dart';
import '../models/teacher_session.dart';

class CalendarTodaySegment extends StatelessWidget {
  const CalendarTodaySegment({
    super.key,
    required this.focus,
    required this.incompleteAttendanceSessions,
    required this.onSessionTap,
    required this.onGoToToday,
    required this.showGoToToday,
  });

  final CalendarSessionFocus focus;
  final List<TeacherSession> incompleteAttendanceSessions;
  final ValueChanged<TeacherSession> onSessionTap;
  final VoidCallback onGoToToday;
  final bool showGoToToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr.calendarTodayTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (showGoToToday)
                  TextButton(
                    onPressed: onGoToToday,
                    child: Text(context.tr.calendarGoToToday),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (focus.current != null)
              _FocusSessionRow(
                label: context.tr.calendarCurrentSession,
                session: focus.current!,
                onTap: () => onSessionTap(focus.current!),
              )
            else if (focus.next != null)
              _FocusSessionRow(
                label: context.tr.calendarNextSession,
                session: focus.next!,
                onTap: () => onSessionTap(focus.next!),
              )
            else if (focus.todaySessions.isEmpty)
              Text(
                context.tr.calendarNoSessionsToday,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (incompleteAttendanceSessions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final session in incompleteAttendanceSessions)
                    ActionChip(
                      avatar: const Icon(Icons.fact_check_outlined, size: 18),
                      label: Text(
                        context.tr.calendarIncompleteAttendance(
                          session.classLabel,
                          session.subjectLabel,
                        ),
                      ),
                      onPressed: () => onSessionTap(session),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FocusSessionRow extends StatelessWidget {
  const _FocusSessionRow({
    required this.label,
    required this.session,
    required this.onTap,
  });

  final String label;
  final TeacherSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.classLabel} · ${session.subjectLabel}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    context.tr.timeRange(
                      context.formatTimeOfDay(session.startsAt),
                      context.formatTimeOfDay(session.endsAt),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
