import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../context/student_context_controller.dart';
import 'calendar_controller.dart';
import 'models/calendar_session.dart';

class SessionDetailsDialog extends LScopedView<SessionDetailsController> {
  const SessionDetailsDialog({super.key, required this.session});

  final CalendarSession session;

  @override
  SessionDetailsController onConfigScope(LevitScope scope) {
    return scope.put(
      () => SessionDetailsController(
        session: session,
        studentContext: scope.find<StudentContextController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, SessionDetailsController controller) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.subjectLabel ?? session.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ),
            Text(
              [
                timetableSessionKindLabel(context.tr, session.kind),
                context.formatLongDate(session.startsAt),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              context.tr.timeRange(
                context.formatTimeOfDay(session.startsAt),
                context.formatTimeOfDay(session.endsAt),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            LWatch(() {
              if (controller.isBusy.value &&
                  controller.attendance.value == null &&
                  controller.logbook.value == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final error = controller.errorMessage.value;
              final attendance = controller.attendance.value;
              final logbook = controller.logbook.value;

              if (error.isNotEmpty && attendance == null && logbook == null) {
                return Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (error.isNotEmpty) ...[
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    context.tr.attendance,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (attendance == null)
                    Text(context.tr.noAttendanceRecorded)
                  else
                    Text(
                      [
                        attendance.status,
                        if (attendance.reason != null) attendance.reason!,
                        if (attendance.justificationStatus != 'none')
                          attendance.justificationStatus,
                      ].join(' · '),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    context.tr.classLogbook,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (logbook == null)
                    Text(context.tr.noLogbookEntryForSession)
                  else ...[
                    Text(
                      logbook.chapter,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(logbook.content),
                    if (logbook.homework != null) ...[
                      const SizedBox(height: 8),
                      Text(context.tr.homeworkValue(logbook.homework!)),
                    ],
                    const SizedBox(height: 8),
                    Text(context.tr.progressPercent(logbook.progress)),
                  ],
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
