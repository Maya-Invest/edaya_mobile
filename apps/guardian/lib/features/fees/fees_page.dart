import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart' as proto;
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/academic_year_controller.dart';
import '../context/store_bound_controller.dart';
import '../context/student_context_controller.dart';
import 'fee_detail_controller.dart';
import 'fee_widgets.dart';
import 'fees_controller.dart';
import 'models/fee_formatting.dart';
import 'models/student_charge_line.dart';

class FeesPage extends StatelessWidget {
  const FeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveFeesPage();
    }
    return const _MockFeesPage();
  }
}

class _MockFeesPage extends LScopedView<StoreBoundController> {
  const _MockFeesPage();

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final path = GoRouterState.of(context).uri.path;
    final selectedFeeId = path.startsWith('/fees/fee/')
        ? path.split('/').last
        : null;
    final selectedPaymentId = path.startsWith('/fees/payment/')
        ? path.split('/').last
        : null;
    final progress = store.feeExpected == 0
        ? 0.0
        : (store.feePaid / store.feeExpected).clamp(0.0, 1.0);
    final currency = store.feeLines.isEmpty
        ? 'EUR'
        : store.feeLines.first.currency;

    return AdaptiveContent(
      child: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          const SectionHeader(title: 'Résumé'),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SummaryMetric(
                        label: 'Attendu',
                        value: proto.formatMoney(store.feeExpected, currency),
                      ),
                    ),
                    Expanded(
                      child: SummaryMetric(
                        label: 'Payé',
                        value: proto.formatMoney(store.feePaid, currency),
                      ),
                    ),
                    Expanded(
                      child: SummaryMetric(
                        label: 'Solde',
                        value: proto.formatMoney(store.feeBalance, currency),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                PrototypeProgressBar(value: progress),
                const SizedBox(height: PrototypeSpacing.xs),
                Text(
                  '${(progress * 100).round()} % réglé',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (store.overdueFeeCount > 0) ...[
                  const SizedBox(height: PrototypeSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: PrototypeSpacing.xxs),
                      Expanded(
                        child: Text(
                          '${store.overdueFeeCount} ligne de frais en retard',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.xl),
          const SectionHeader(title: 'Lignes de frais'),
          for (final fee in store.feeLines) ...[
            ListRow(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: fee.status == 'En retard'
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: fee.status == 'En retard'
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              title: fee.label,
              subtitle:
                  'Échéance ${fee.dueDate != null ? proto.formatDate(fee.dueDate!) : '—'} · '
                  '${fee.paymentCount} paiement${fee.paymentCount > 1 ? 's' : ''}',
              selected: selectedFeeId == fee.id,
              trailing: FeeAmountTrailing(
                amount: proto.formatMoney(fee.balance, fee.currency),
                label: fee.status,
                labelColor: fee.status == 'En retard'
                    ? Theme.of(context).colorScheme.error
                    : null,
                showChevron: true,
              ),
              onTap: () => context.push(
                Uri(
                  path: '/fees/fee/${fee.id}',
                  queryParameters: GoRouterState.of(
                    context,
                  ).uri.queryParameters,
                ).toString(),
              ),
            ),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
          const SizedBox(height: PrototypeSpacing.xl),
          const SectionHeader(title: 'Paiements'),
          for (final payment in store.payments) ...[
            ListRow(
              title: payment.method,
              subtitle:
                  '${payment.feeLabel} · ${proto.formatDate(payment.date)}',
              selected: selectedPaymentId == payment.id,
              trailing: FeeAmountTrailing(
                amount: proto.formatMoney(payment.amount, payment.currency),
                label: 'Reçu',
                showChevron: true,
              ),
              onTap: () => context.push(
                Uri(
                  path: '/fees/payment/${payment.id}',
                  queryParameters: GoRouterState.of(
                    context,
                  ).uri.queryParameters,
                ).toString(),
              ),
            ),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _LiveFeesPage extends LScopedView<FeesController> {
  const _LiveFeesPage();

  @override
  FeesController onConfigScope(LevitScope scope) {
    return scope.put(
      () => FeesController(
        studentContext: scope.find<StudentContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, FeesController controller) {
    final path = GoRouterState.of(context).uri.path;
    final selectedFeeId = path.startsWith('/fees/fee/')
        ? path.split('/').last
        : null;
    final selectedPaymentId = path.startsWith('/fees/payment/')
        ? path.split('/').last
        : null;

    if (controller.dataStatus == DataStatus.loading) {
      return const AdaptiveContent(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.dataStatus == DataStatus.error) {
      return AdaptiveContent(
        child: EmptyState(title: controller.errorMessage.value),
      );
    }
    if (controller.dataStatus == DataStatus.empty) {
      return AdaptiveContent(child: EmptyState(title: controller.emptyMessage));
    }

    final summary = controller.summary.value;
    final progress = controller.totalExpected == 0
        ? 0.0
        : (controller.totalPaid / controller.totalExpected).clamp(0.0, 1.0);
    final currency =
        summary?.currency ??
        (controller.charges.value.isNotEmpty
            ? controller.charges.value.first.currency
            : 'XOF');
    final schoolId = context.levit.find<AppSessionController>().schoolIdHeader;

    return AdaptiveContent(
      child: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          const SectionHeader(title: 'Résumé'),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SummaryMetric(
                        label: 'Attendu',
                        value: formatMoney(controller.totalExpected, currency),
                      ),
                    ),
                    Expanded(
                      child: SummaryMetric(
                        label: 'Payé',
                        value: formatMoney(controller.totalPaid, currency),
                      ),
                    ),
                    Expanded(
                      child: SummaryMetric(
                        label: 'Solde',
                        value: formatMoney(controller.totalBalance, currency),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                PrototypeProgressBar(value: progress),
                const SizedBox(height: PrototypeSpacing.xs),
                Text(
                  '${(progress * 100).round()} % réglé',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (controller.overdueCount > 0) ...[
                  const SizedBox(height: PrototypeSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: PrototypeSpacing.xxs),
                      Expanded(
                        child: Text(
                          '${controller.overdueCount} ligne de frais en retard',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: PrototypeSpacing.md),
                DocumentActionButton(
                  label: 'Relevé de compte',
                  run: () => controller.downloadStatement(schoolId: schoolId),
                ),
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.xl),
          const SectionHeader(title: 'Lignes de frais'),
          for (final fee in controller.charges.value) ...[
            ListRow(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: fee.status == ChargeStatus.overdue
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: fee.status == ChargeStatus.overdue
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              title: fee.label,
              subtitle:
                  'Échéance ${fee.dueDate != null ? context.formatShortDate(fee.dueDate!) : '—'} · '
                  '${fee.settlementCount} paiement${fee.settlementCount > 1 ? 's' : ''}',
              selected: selectedFeeId == fee.id,
              trailing: FeeAmountTrailing(
                amount: formatMoney(fee.remainingObligation, fee.currency),
                label: frenchChargeStatus(fee.status),
                labelColor: fee.status == ChargeStatus.overdue
                    ? Theme.of(context).colorScheme.error
                    : null,
                showChevron: true,
              ),
              onTap: () => context.push(
                Uri(
                  path: '/fees/fee/${fee.id}',
                  queryParameters: GoRouterState.of(
                    context,
                  ).uri.queryParameters,
                ).toString(),
              ),
            ),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
          const SizedBox(height: PrototypeSpacing.xl),
          const SectionHeader(title: 'Paiements'),
          for (final payment in controller.payments.value) ...[
            ListRow(
              title: frenchPaymentMethod(payment.method),
              subtitle:
                  '${payment.feeLabel} · ${context.formatShortDate(payment.paymentDate)}',
              selected: selectedPaymentId == payment.id,
              trailing: FeeAmountTrailing(
                amount: formatMoney(payment.amount, payment.currency),
                label: 'Reçu',
                showChevron: true,
              ),
              onTap: () => context.push(
                Uri(
                  path: '/fees/payment/${payment.id}',
                  queryParameters: GoRouterState.of(
                    context,
                  ).uri.queryParameters,
                ).toString(),
              ),
            ),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
        ],
      ),
    );
  }
}
