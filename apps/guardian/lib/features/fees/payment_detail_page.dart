import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart' as proto;
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/academic_year_controller.dart';
import '../context/store_bound_controller.dart';
import '../context/student_context_controller.dart';
import 'models/fee_formatting.dart';
import 'payment_detail_controller.dart';

class PaymentDetailPage extends StatelessWidget {
  const PaymentDetailPage({super.key, required this.paymentId});

  final String paymentId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LivePaymentDetailPage(paymentId: paymentId);
    }
    return _MockPaymentDetailPage(paymentId: paymentId);
  }
}

class _MockPaymentDetailPage extends LScopedView<StoreBoundController> {
  const _MockPaymentDetailPage({required this.paymentId});

  final String paymentId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final payment = controller.store.paymentById(paymentId);
    if (payment == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/fees',
        title: context.tr.paymentDetails,
        body: EmptyState(title: context.tr.paymentNotFound),
      );
    }
    return PrototypeDetailScaffold(
      fallbackRoute: '/fees',
      title: context.tr.paymentReceipt,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        context.tr.amount,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    Text(
                      proto.formatDate(payment.date),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: PrototypeSpacing.xs),
                Text(
                  proto.formatMoney(payment.amount, payment.currency),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Divider(height: PrototypeSpacing.xl),
                SummaryMetric(
                  label: context.tr.navFees,
                  value: payment.feeLabel,
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                SummaryMetric(
                  label: context.tr.paymentMethod,
                  value: formatPaymentMethod(context.tr, payment.method),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePaymentDetailPage extends LScopedView<PaymentDetailController> {
  const _LivePaymentDetailPage({required this.paymentId});

  final String paymentId;

  @override
  PaymentDetailController onConfigScope(LevitScope scope) {
    return scope.put(
      () => PaymentDetailController(
        paymentId: paymentId,
        schoolClient: scope.find<SchoolClientFactory>(),
        studentId: scope.find<StudentContextController>().activeStudentId,
        academicYearId: scope
            .find<AcademicYearController>()
            .selectedYearId
            .value,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, PaymentDetailController controller) {
    if (controller.isBusy.value && controller.payment.value == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/fees',
        title: context.tr.paymentDetails,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final payment = controller.payment.value;
    if (payment == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/fees',
        title: context.tr.paymentDetails,
        body: EmptyState(
          title: controller.errorMessage.value.isEmpty
              ? context.tr.paymentNotFound
              : controller.errorMessage.value,
        ),
      );
    }

    return PrototypeDetailScaffold(
      fallbackRoute: '/fees',
      title: payment.kind == 'disbursement'
          ? context.tr.paymentKindDisbursement
          : context.tr.paymentReceipt,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        formatPaymentKind(context.tr, payment.kind),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    Text(
                      context.formatShortDate(payment.paymentDate),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: PrototypeSpacing.xs),
                Text(
                  formatMoney(
                    payment.amount,
                    payment.currency,
                    context.tr.localeName,
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Divider(height: PrototypeSpacing.xl),
                SummaryMetric(
                  label: context.tr.navFees,
                  value: payment.feeLabel,
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                SummaryMetric(
                  label: context.tr.paymentMethod,
                  value: formatPaymentMethod(context.tr, payment.method),
                ),
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          DocumentActionButton(
            label: context.tr.downloadReceipt,
            run: controller.downloadReceipt,
          ),
        ],
      ),
    );
  }
}
