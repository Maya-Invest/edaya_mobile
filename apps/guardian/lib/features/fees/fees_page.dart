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
          SectionHeader(title: context.tr.summary),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FeeSummaryMetrics(
                  metrics: [
                    SummaryMetric(
                      label: context.tr.expected,
                      value: proto.formatMoney(store.feeExpected, currency),
                    ),
                    SummaryMetric(
                      label: context.tr.feeStatusPaid,
                      value: proto.formatMoney(store.feePaid, currency),
                    ),
                    SummaryMetric(
                      label: context.tr.balance,
                      value: proto.formatMoney(store.feeBalance, currency),
                    ),
                  ],
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                PrototypeProgressBar(value: progress),
                const SizedBox(height: PrototypeSpacing.xs),
                Text(
                  context.tr.paidLabel((progress * 100).round()),
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
                          context.tr.overdueChargesCount(store.overdueFeeCount),
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
          SectionHeader(title: context.tr.feeLinesSection),
          for (final fee in store.feeLines) ...[
            ListRow(
              stackTrailingAtLargeText: true,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: fee.status == 'overdue'
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: fee.status == 'overdue'
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              title: fee.label,
              subtitle:
                  '${context.tr.dueDate(fee.dueDate != null ? proto.formatDate(fee.dueDate!) : '—')} · ${context.tr.paymentCount(fee.paymentCount)}',
              selected: selectedFeeId == fee.id,
              trailing: FeeAmountTrailing(
                amount: proto.formatMoney(fee.balance, fee.currency),
                label: formatChargeStatus(
                  context.tr,
                  parseChargeStatus(fee.status),
                ),
                labelColor: fee.status == 'overdue'
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
          SectionHeader(title: context.tr.paymentsSection),
          for (final payment in store.payments) ...[
            ListRow(
              stackTrailingAtLargeText: true,
              title: formatPaymentMethod(context.tr, payment.method),
              subtitle:
                  '${payment.feeLabel} · ${proto.formatDate(payment.date)}',
              selected: selectedPaymentId == payment.id,
              trailing: FeeAmountTrailing(
                amount: proto.formatMoney(payment.amount, payment.currency),
                label: context.tr.paymentKindReceipt,
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
        child: EmptyState(
          title: controller.errorMessage.value,
          actionLabel: context.tr.retry,
          onAction: controller.loadFeesData,
        ),
      );
    }
    if (controller.dataStatus == DataStatus.empty) {
      return AdaptiveContent(child: EmptyState(title: controller.emptyMessage));
    }

    final totals = controller.chargeTotals.value;
    final progress = controller.totalExpected == 0
        ? 0.0
        : (controller.totalPaid / controller.totalExpected).clamp(0.0, 1.0);
    final currency = controller.summary.value!.currency;
    final schoolId = context.levit.find<AppSessionController>().schoolIdHeader;

    final phone = phoneActions(context);
    final statement = DocumentActionButton(
      label: context.tr.featureDownloadStatement,
      floating: phone,
      icon: Icons.download_outlined,
      run: () => controller.downloadStatement(schoolId: schoolId),
    );
    final content = Column(
      children: [
        Expanded(
          child: AdaptiveContent(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(PrototypeSpacing.md),
              children: [
                SectionHeader(title: context.tr.summary),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FeeSummaryMetrics(
                        metrics: [
                          if (totals != null)
                            SummaryMetric(
                              label: context.tr.expected,
                              value: formatMoney(
                                controller.totalExpected,
                                currency,
                                context.tr.localeName,
                              ),
                            ),
                          if (totals != null)
                            SummaryMetric(
                              label: context.tr.feeStatusPaid,
                              value: formatMoney(
                                controller.totalPaid,
                                currency,
                                context.tr.localeName,
                              ),
                            ),
                          SummaryMetric(
                            label: context.tr.balance,
                            value: formatMoney(
                              controller.totalBalance,
                              currency,
                              context.tr.localeName,
                            ),
                          ),
                        ],
                      ),
                      if (totals != null) ...[
                        const SizedBox(height: PrototypeSpacing.sm),
                        PrototypeProgressBar(value: progress),
                        const SizedBox(height: PrototypeSpacing.xs),
                        Text(
                          context.tr.paidLabel((progress * 100).round()),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
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
                                context.tr.overdueChargesCount(
                                  controller.overdueCount,
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: PrototypeSpacing.md),
                      if (!phone) statement,
                    ],
                  ),
                ),
                const SizedBox(height: PrototypeSpacing.xl),
                if (controller.historyStatus.value != DataStatus.ready)
                  DataState(
                    status: controller.historyStatus.value,
                    errorMessage: controller.errorMessage.value,
                    onRetry: controller.loadFeesData,
                    child: const SizedBox.shrink(),
                  )
                else ...[
                  SectionHeader(title: context.tr.feeLinesSection),
                  for (final fee in controller.charges.value) ...[
                    ListRow(
                      stackTrailingAtLargeText: true,
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
                          '${context.tr.dueDate(fee.dueDate != null ? context.formatShortDate(fee.dueDate!) : '—')} · ${context.tr.paymentCount(fee.settlementCount)}',
                      selected: selectedFeeId == fee.id,
                      trailing: FeeAmountTrailing(
                        amount: formatMoney(
                          fee.remainingObligation,
                          fee.currency,
                          context.tr.localeName,
                        ),
                        label: formatChargeStatus(context.tr, fee.status),
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
                  if (controller.chargePageError.value.isNotEmpty)
                    Text(controller.chargePageError.value),
                  if (controller.nextChargeCursor.value != null)
                    TextButton(
                      onPressed: controller.loadingCharges.value
                          ? null
                          : controller.loadMoreCharges,
                      child: Text(
                        controller.chargePageError.value.isEmpty
                            ? context.tr.showMore
                            : context.tr.retry,
                      ),
                    ),
                  const SizedBox(height: PrototypeSpacing.xl),
                  SectionHeader(title: context.tr.paymentsSection),
                  for (final payment in controller.payments.value) ...[
                    ListRow(
                      stackTrailingAtLargeText: true,
                      title: formatPaymentMethod(context.tr, payment.method),
                      subtitle:
                          '${payment.feeLabel} · ${context.formatShortDate(payment.paymentDate)}',
                      selected: selectedPaymentId == payment.id,
                      trailing: FeeAmountTrailing(
                        amount: formatMoney(
                          payment.amount,
                          payment.currency,
                          context.tr.localeName,
                        ),
                        label: formatPaymentKind(context.tr, payment.kind),
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
                  if (controller.paymentPageError.value.isNotEmpty)
                    Text(controller.paymentPageError.value),
                  if (controller.nextPaymentCursor.value != null)
                    TextButton(
                      onPressed: controller.loadingPayments.value
                          ? null
                          : controller.loadMorePayments,
                      child: Text(
                        controller.paymentPageError.value.isEmpty
                            ? context.tr.showMore
                            : context.tr.retry,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (phone && path == '/fees') statement,
      ],
    );
    return RefreshIndicator(onRefresh: controller.loadFeesData, child: content);
  }
}

class _FeeSummaryMetrics extends StatelessWidget {
  const _FeeSummaryMetrics({required this.metrics});

  final List<SummaryMetric> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final textScale = MediaQuery.textScalerOf(context);
      if (box.maxWidth / metrics.length < textScale.scale(88)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: PrototypeSpacing.sm,
          children: metrics,
        );
      }
      return Row(
        children: [for (final metric in metrics) Expanded(child: metric)],
      );
    },
  );
}
