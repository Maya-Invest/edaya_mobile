import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../context/student_context_controller.dart';
import 'attendance_controller.dart';

String _frenchAttendanceStatus(String status) {
  return switch (status) {
    'present' => 'Présent',
    'absent' => 'Absent',
    'late' => 'Retard',
    'excused' => 'Excusé',
    _ => status,
  };
}

class AttendanceListPage extends LScopedView<AttendanceController> {
  const AttendanceListPage({super.key});

  @override
  AttendanceController onConfigScope(LevitScope scope) {
    return scope.put(
      () => AttendanceController(
        studentContext: scope.find<StudentContextController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, AttendanceController controller) {
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);
    final records = controller.records.value;
    final titles = controller.sessionTitles.value;

    if (controller.isBusy.value && records.isEmpty) {
      return PrototypeDetailScaffold(
        embedded: embedded,
        fallbackRoute: '/calendar',
        title: 'Présences',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (controller.errorMessage.value.isNotEmpty && records.isEmpty) {
      return PrototypeDetailScaffold(
        embedded: embedded,
        fallbackRoute: '/calendar',
        title: 'Présences',
        body: EmptyState(title: controller.errorMessage.value),
      );
    }

    if (records.isEmpty) {
      return PrototypeDetailScaffold(
        embedded: embedded,
        fallbackRoute: '/calendar',
        title: 'Présences',
        body: const EmptyState(title: 'Aucune présence enregistrée'),
      );
    }

    return PrototypeDetailScaffold(
      embedded: embedded,
      fallbackRoute: '/calendar',
      title: 'Présences',
      body: ListView.separated(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        itemCount: records.length,
        separatorBuilder: (_, _) => const SizedBox(height: PrototypeSpacing.xs),
        itemBuilder: (context, i) {
          final a = records[i];
          final label = _frenchAttendanceStatus(a.status);
          final tone = label == 'Absent'
              ? SemanticTone.error
              : label == 'Retard'
              ? SemanticTone.warning
              : SemanticTone.success;
          return ListRow(
            title: titles[a.occurrenceId] ?? a.occurrenceId,
            subtitle: formatDate(a.date),
            badge: label,
            badgeTone: tone,
          );
        },
      ),
    );
  }
}
