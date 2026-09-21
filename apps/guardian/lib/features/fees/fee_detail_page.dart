import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/academic_year_controller.dart';
import '../context/store_bound_controller.dart';
import '../context/student_context_controller.dart';
import 'fee_detail_controller.dart';
import 'fee_widgets.dart';

class FeeDetailPage extends StatelessWidget {
  const FeeDetailPage({super.key, required this.feeId});

  final String feeId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveFeeDetailPage(feeId: feeId);
    }
    return _MockFeeDetailPage(feeId: feeId);
  }
}

class _MockFeeDetailPage extends LScopedView<StoreBoundController> {
  const _MockFeeDetailPage({required this.feeId});

  final String feeId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final fee = controller.store.feeById(feeId);
    if (fee == null) {
      return const PrototypeDetailScaffold(
        fallbackRoute: '/fees',
        title: 'Détail des frais',
        body: EmptyState(title: 'Frais introuvables'),
      );
    }
    final installments = controller.store.installmentsForFee(feeId);
    return PrototypeDetailScaffold(
      fallbackRoute: '/fees',
      title: fee.label,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SummaryMetric(
                  label: 'Attendu',
                  value: formatMoney(fee.expected, fee.currency),
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                SummaryMetric(
                  label: 'Payé',
                  value: formatMoney(fee.paid, fee.currency),
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                SummaryMetric(
                  label: 'Solde',
                  value: formatMoney(fee.balance, fee.currency),
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                PrototypeProgressBar(value: fee.progress),
                if ((fee.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: PrototypeSpacing.md),
                  Text(
                    fee.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          if (installments.isNotEmpty) ...[
            const SizedBox(height: PrototypeSpacing.xl),
            const SectionHeader(title: 'Échéances'),
            for (final installment in installments) ...[
              ListRow(
                title: installment.label,
                subtitle: 'Échéance ${formatDate(installment.dueDate)}',
                trailing: Text(
                  formatMoney(installment.balance, installment.currency),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                badge: installment.status,
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
          ],
        ],
      ),
    );
  }
}

class _LiveFeeDetailPage extends LScopedView<FeeDetailController> {
  const _LiveFeeDetailPage({required this.feeId});

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
    if (controller.isBusy.value && controller.charge.value == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/fees',
        title: 'Détail des frais',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final fee = controller.charge.value;
    if (fee == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/fees',
        title: 'Détail des frais',
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
              ChargeInstallmentCard(
                installment: installment,
                currency: fee.currency,
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
          ],
        ],
      ),
    );
  }
}
