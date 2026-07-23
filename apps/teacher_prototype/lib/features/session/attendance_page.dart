import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';

class AttendancePage extends LScopedView<StoreBoundController> {
  const AttendancePage({super.key, required this.sessionId});

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
                            DropdownMenuItem(
                              value: s,
                              child: Text(s.labelFr),
                            ),
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
