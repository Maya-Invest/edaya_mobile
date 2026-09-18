import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'fee_detail_controller.dart';
import 'fee_widgets.dart';

class FeeDetailPage extends LScopedView<FeeDetailController> {
  const FeeDetailPage({super.key, required this.feeId});

  final String feeId;

  @override
  FeeDetailController onConfigScope(LevitScope scope) {
    return scope.put(
      () => FeeDetailController(
        feeId: feeId,
        schoolClient: scope.find<SchoolClientFactory>(),
        studentId: scope.find<StudentContextController>().activeStudentId,
        academicYearId: scope
            .find<AcademicYearController>()
            .selectedYearId
            .value,
        schoolId: scope.find<AppSessionController>().schoolIdHeader,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, FeeDetailController controller) {
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);

    if (controller.isBusy.value && controller.charge.value == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/fees',
        title: 'Détail des frais',
        embedded: embedded,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final fee = controller.charge.value;
    if (fee == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/fees',
        title: 'Détail des frais',
        embedded: embedded,
        body: EmptyState(
          title: controller.errorMessage.value.isEmpty
              ? 'Frais introuvables'
              : controller.errorMessage.value,
        ),
      );
    }

    return PrototypeDetailScaffold(
      fallbackRoute: '/fees',
      title: fee.label,
      embedded: embedded,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          ChargeDetailSummaryCard(charge: fee),
          const SizedBox(height: PrototypeSpacing.md),
          DocumentActionButton(
            label: 'Facture',
            run: controller.downloadInvoice,
          ),
          if (fee.installments.isNotEmpty) ...[
            const SizedBox(height: PrototypeSpacing.xl),
            const SectionHeader(title: 'Échéances'),
            for (final installment in fee.installments) ...[
              ChargeInstallmentCard(installment: installment, currency: fee.currency),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
          ],
        ],
      ),
    );
  }
}
