import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';
import '../context/student_context_controller.dart';
import 'attendance_controller.dart';
import 'attendance_label.dart';

class AttendanceListPage extends StatelessWidget {
  const AttendanceListPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveAttendanceListPage();
    }
    return const _MockAttendanceListPage();
  }
}

class _MockAttendanceListPage extends LScopedView<StoreBoundController> {
  const _MockAttendanceListPage();

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final records = controller.store.attendance;
    if (records.isEmpty) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/calendar',
        title: context.tr.attendance,
        body: EmptyState(title: context.tr.noAttendanceRecorded),
      );
    }

    return PrototypeDetailScaffold(
      fallbackRoute: '/calendar',
      title: context.tr.attendance,
      body: ListView.separated(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        itemCount: records.length,
        separatorBuilder: (_, _) => const SizedBox(height: PrototypeSpacing.xs),
        itemBuilder: (context, i) {
          final a = records[i];
          final tone = a.status == 'Absent'
              ? SemanticTone.error
              : a.status == 'Retard'
              ? SemanticTone.warning
              : SemanticTone.success;
          return ListRow(
            title: a.subject,
            subtitle: formatDate(a.date),
            badge: attendanceLabel(context.tr, a.status),
            badgeTone: tone,
          );
        },
      ),
    );
  }
}

class _LiveAttendanceListPage extends LScopedView<AttendanceController> {
  const _LiveAttendanceListPage();

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
    final records = controller.records.value;
    final titles = controller.sessionTitles.value;

    if (controller.isBusy.value && records.isEmpty) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/calendar',
        title: context.tr.attendance,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (controller.errorMessage.value.isNotEmpty && records.isEmpty) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/calendar',
        title: context.tr.attendance,
        body: EmptyState(title: controller.errorMessage.value),
      );
    }

    if (records.isEmpty) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/calendar',
        title: context.tr.attendance,
        body: EmptyState(title: context.tr.noAttendanceRecorded),
      );
    }

    return PrototypeDetailScaffold(
      fallbackRoute: '/calendar',
      title: context.tr.attendance,
      body: ListView.separated(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        itemCount: records.length,
        separatorBuilder: (_, _) => const SizedBox(height: PrototypeSpacing.xs),
        itemBuilder: (context, i) {
          final a = records[i];
          final label = attendanceLabel(context.tr, a.status);
          final tone = a.status == 'absent'
              ? SemanticTone.error
              : a.status == 'late'
              ? SemanticTone.warning
              : SemanticTone.success;
          return ListRow(
            title: a.occurrenceKind == 'daily'
                ? context.tr.dailyAttendance
                : titles[a.occurrenceId] ?? a.occurrenceId,
            subtitle: formatDate(a.date),
            badge: label,
            badgeTone: tone,
          );
        },
      ),
    );
  }
}
