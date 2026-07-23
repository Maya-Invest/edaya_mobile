import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import 'attendance_controller.dart';

class AttendanceListPage extends LScopedView<AttendanceController> {
  const AttendanceListPage({super.key});

  @override
  AttendanceController onConfigScope(LevitScope scope) {
    return scope.put(() => AttendanceController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, AttendanceController controller) {
        controller.storeTick.value;
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);
    final store = controller.store;

    return PrototypeDetailScaffold(
      embedded: embedded,
      fallbackRoute: '/calendar',
      title: 'Présences',
      body: ListView.separated(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        itemCount: store.attendance.length,
        separatorBuilder: (_, _) => const SizedBox(height: PrototypeSpacing.xs),
        itemBuilder: (context, i) {
          final a = store.attendance[i];
          final tone = a.status == 'Absent'
              ? SemanticTone.error
              : a.status == 'Retard'
              ? SemanticTone.warning
              : SemanticTone.success;
          return ListRow(
            title: a.subject,
            subtitle: formatDate(a.date),
            badge: a.status,
            badgeTone: tone,
          );
        },
      ),
    );
  }
}
