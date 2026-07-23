import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
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
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, FeeDetailController controller) {
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);

    if (controller.isBusy.value && controller.feeLine.value == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/fees',
        title: 'Détail des frais',
        embedded: embedded,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final fee = controller.feeLine.value;
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

    final installments = controller.installments.value;
    final payments = controller.payments.value;

    final installmentsSection = [
      const SectionHeader(title: 'Échéances'),
      for (final installment in installments) ...[
        InstallmentCard(installment: installment),
        const SizedBox(height: PrototypeSpacing.xs),
      ],
    ];

    final paymentsSection = [
      const SectionHeader(title: 'Paiements'),
      for (final payment in payments) ...[
        ListRow(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PrototypeColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.payments_outlined,
              size: 20,
              color: PrototypeColors.primary,
            ),
          ),
          title: frenchPaymentMethod(payment.method),
          subtitle: formatDate(payment.paymentDate),
          trailing: FeeAmountTrailing(
            amount: formatMoney(payment.amount, payment.currency),
            label: 'Reçu',
            showChevron: true,
          ),
          onTap: () => context.go('/fees/payment/${payment.id}'),
        ),
        const SizedBox(height: PrototypeSpacing.xs),
      ],
    ];

    return PrototypeDetailScaffold(
      fallbackRoute: '/fees',
      title: fee.label,
      embedded: embedded,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          FeeDetailSummaryCard(fee: fee),
          const SizedBox(height: PrototypeSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide =
                  constraints.maxWidth >= PrototypeBreakpoints.compact &&
                  installments.isNotEmpty &&
                  payments.isNotEmpty;
              if (!sideBySide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (installments.isNotEmpty) ...installmentsSection,
                    if (installments.isNotEmpty && payments.isNotEmpty)
                      const SizedBox(height: PrototypeSpacing.xl),
                    if (payments.isNotEmpty) ...paymentsSection,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: installmentsSection,
                    ),
                  ),
                  const SizedBox(width: PrototypeSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: paymentsSection,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
