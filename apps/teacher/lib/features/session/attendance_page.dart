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

LiveSessionController putLiveSessionController(
  LevitScope scope,
  String sessionId,
) {
  return scope.put(
    () => LiveSessionController(
      sessionId: sessionId,
      calendar: scope.find<LiveCalendarController>(),
      academicYear: scope.find<AcademicYearController>(),
      schoolClient: scope.find<SchoolClientFactory>(),
      outboxStore: scope.find<TeacherOutboxStore>(),
    ),
  );
}

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
    return putLiveSessionController(scope, sessionId);
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
      if (!controller.supportsAttendanceRecording) {
        return PrototypeDetailScaffold(
          title: 'Présences · ${session.classLabel}',
          fallbackRoute: '/session/$sessionId',
          body: const EmptyState(
            title: 'Présences',
            message: 'La saisie des présences est réservée aux séances de cours.',
          ),
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(record.fullName),
                                    if (record.reason != null &&
                                        record.reason!.isNotEmpty)
                                      Text(
                                        record.reason!,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                              DropdownButton<AttendanceStatus>(
                                hint: const Text('À saisir'),
                                value: record.status,
                                underline: const SizedBox.shrink(),
                                items: [
                                  for (final s in AttendanceStatus.values)
                                    DropdownMenuItem(
                                      value: s,
                                      child: Text(s.labelFr),
                                    ),
                                ],
                                onChanged: (value) async {
                                  if (value == null) return;
                                  if (value == AttendanceStatus.present) {
                                    await controller.setAttendanceStatus(
                                      record.studentId,
                                      value,
                                    );
                                    return;
                                  }
                                  final exception =
                                      await showAttendanceExceptionSheet(
                                        context: context,
                                        studentName: record.fullName,
                                        initialStatus: value,
                                        initialReason: record.reason,
                                        initialNotes: record.notes,
                                      );
                                  if (exception == null) return;
                                  await controller.setAttendanceStatus(
                                    record.studentId,
                                    exception.status,
                                    reason: exception.reason,
                                    notes: exception.notes,
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

class AttendanceExceptionResult {
  const AttendanceExceptionResult({
    required this.status,
    this.reason,
    this.notes,
  });

  final AttendanceStatus status;
  final String? reason;
  final String? notes;
}

Future<AttendanceExceptionResult?> showAttendanceExceptionSheet({
  required BuildContext context,
  required String studentName,
  required AttendanceStatus initialStatus,
  String? initialReason,
  String? initialNotes,
}) {
  return showModalBottomSheet<AttendanceExceptionResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      var status = initialStatus;
      final reason = TextEditingController(text: initialReason ?? '');
      final notes = TextEditingController(text: initialNotes ?? '');
      return Padding(
        padding: EdgeInsets.only(
          left: PrototypeSpacing.md,
          right: PrototypeSpacing.md,
          top: PrototypeSpacing.md,
          bottom:
              MediaQuery.viewInsetsOf(context).bottom + PrototypeSpacing.md,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  studentName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: PrototypeSpacing.md),
                DropdownButtonFormField<AttendanceStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Statut',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final value in AttendanceStatus.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.labelFr),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => status = value);
                  },
                ),
                const SizedBox(height: PrototypeSpacing.md),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                    labelText: 'Motif',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: PrototypeSpacing.md),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: PrototypeSpacing.md),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      AttendanceExceptionResult(
                        status: status,
                        reason: reason.text.trim(),
                        notes: notes.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
