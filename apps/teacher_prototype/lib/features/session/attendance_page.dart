import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../calendar/live_calendar_controller.dart';
import '../context/academic_year_controller.dart';
import '../context/store_bound_controller.dart';
import 'live_session_controller.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveAttendancePage(sessionId: sessionId);
    }
    return _MockAttendancePage(sessionId: sessionId);
  }
}

class _MockAttendancePage extends LScopedView<StoreBoundController> {
  const _MockAttendancePage({required this.sessionId});

  final String sessionId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final session = store.sessionById(sessionId);
    if (session == null) {
      return const PrototypeDetailScaffold(
        title: 'Présences',
        body: EmptyState(title: 'Séance introuvable'),
      );
    }

    final records = store.getAttendance(sessionId);

    return PrototypeDetailScaffold(
      title: 'Présences · ${session.classLabel}',
      fallbackRoute: '/session/$sessionId',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(PrototypeSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => store.markAllPresent(sessionId),
                    child: const Text('Tous présents'),
                  ),
                ),
                const SizedBox(width: PrototypeSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      store.completeAttendance(sessionId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Présences enregistrées')),
                      );
                    },
                    child: const Text('Terminer'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                PrototypeSpacing.md,
                0,
                PrototypeSpacing.md,
                PrototypeSpacing.md,
              ),
              itemCount: records.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: PrototypeSpacing.xs),
              itemBuilder: (context, i) {
                final record = records[i];
                final student = store.studentById(record.studentId);
                if (student == null) return const SizedBox.shrink();
                return SurfaceCard(
                  child: Row(
                    children: [
                      PersonAvatar(initials: student.initials, radius: 20),
                      const SizedBox(width: PrototypeSpacing.sm),
                      Expanded(child: Text(student.fullName)),
                      DropdownButton<AttendanceStatus>(
                        value: record.status,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final s in AttendanceStatus.values)
                            DropdownMenuItem(value: s, child: Text(s.labelFr)),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          store.setAttendanceStatus(
                            sessionId,
                            student.id,
                            value,
                          );
                        },
                      ),
                    ],
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

class _LiveAttendancePage extends LScopedView<LiveSessionController> {
  const _LiveAttendancePage({required this.sessionId});

  final String sessionId;

  @override
  LiveSessionController onConfigScope(LevitScope scope) {
    return scope.put(
      () => LiveSessionController(
        sessionId: sessionId,
        calendar: scope.find<LiveCalendarController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, LiveSessionController controller) {
    return LWatch(() {
      controller.session.value;
      controller.students.value;
      controller.saveMessage.value;
      final session = controller.session.value;
      if (session == null) {
        return const PrototypeDetailScaffold(
          title: 'Présences',
          body: EmptyState(title: 'Séance introuvable'),
        );
      }
      final records = controller.students.value;
      return PrototypeDetailScaffold(
        title: 'Présences · ${session.classLabel}',
        fallbackRoute: '/session/$sessionId',
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(PrototypeSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controller.markAllPresent,
                      child: const Text('Tous présents'),
                    ),
                  ),
                  const SizedBox(width: PrototypeSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await controller.completeAttendance();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.saveMessage.value.isEmpty
                                  ? 'Présences enregistrées'
                                  : controller.saveMessage.value,
                            ),
                          ),
                        );
                      },
                      child: const Text('Terminer'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? const EmptyState(title: 'Aucun élève')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        PrototypeSpacing.md,
                        0,
                        PrototypeSpacing.md,
                        PrototypeSpacing.md,
                      ),
                      itemCount: records.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: PrototypeSpacing.xs),
                      itemBuilder: (context, i) {
                        final record = records[i];
                        return SurfaceCard(
                          child: Row(
                            children: [
                              PersonAvatar(
                                initials: record.initials,
                                photoUrl: record.photoUrl,
                                radius: 20,
                              ),
                              const SizedBox(width: PrototypeSpacing.sm),
                              Expanded(child: Text(record.fullName)),
                              DropdownButton<AttendanceStatus>(
                                value:
                                    record.status ?? AttendanceStatus.present,
                                underline: const SizedBox.shrink(),
                                items: [
                                  for (final s in AttendanceStatus.values)
                                    DropdownMenuItem(
                                      value: s,
                                      child: Text(s.labelFr),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  controller.setAttendanceStatus(
                                    record.studentId,
                                    value,
                                  );
                                },
                              ),
                            ],
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
