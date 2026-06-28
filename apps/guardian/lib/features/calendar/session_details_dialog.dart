import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import 'package:edaya_shared/edaya_shared.dart';
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
        studentContext: AppRuntime.studentContext,
      ),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    SessionDetailsController controller,
  ) {
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
                    session.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              formatLongDate(session.startsAt),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '${formatTimeOfDay(session.startsAt)} – ${formatTimeOfDay(session.endsAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            LWatch(
              () {
                if (controller.isBusy.value &&
                    controller.attendance.value == null &&
                    controller.logbook.value == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final error = controller.errorMessage.value;
                if (error.isNotEmpty) {
                  return Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                }

                final attendance = controller.attendance.value;
                final logbook = controller.logbook.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (attendance == null)
                      const Text('No attendance recorded.')
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
                      'Class logbook',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (logbook == null)
                      const Text('No logbook entry for this session.')
                    else ...[
                      Text(logbook.chapter, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(logbook.content),
                      if (logbook.homework != null) ...[
                        const SizedBox(height: 8),
                        Text('Homework: ${logbook.homework}'),
                      ],
                      const SizedBox(height: 8),
                      Text('Progress: ${logbook.progress}%'),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
