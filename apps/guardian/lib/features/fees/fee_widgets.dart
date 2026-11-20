import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import 'models/fee_formatting.dart';
import 'models/student_charge_line.dart';

class FeeAmountTrailing extends StatelessWidget {
  const FeeAmountTrailing({
    super.key,
    required this.amount,
    required this.label,
    this.labelColor,
    this.showChevron = false,
  });

  final String amount;
  final String label;
  final Color? labelColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              amount,
              style: textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (labelColor != null) ...[
              Icon(Icons.error_outline, size: 12, color: labelColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(color: labelColor),
            ),
          ],
        ),
      ],
    );
  }
}

SemanticTone _chargeStatusTone(ChargeStatus status) {
  return switch (status) {
    ChargeStatus.overdue => SemanticTone.error,
    ChargeStatus.paid => SemanticTone.success,
    ChargeStatus.partial => SemanticTone.warning,
    _ => SemanticTone.neutral,
  };
}

class ChargeDetailSummaryCard extends StatelessWidget {
  const ChargeDetailSummaryCard({super.key, required this.charge});

  final StudentChargeLine charge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusLabel = formatChargeStatus(context.tr, charge.status);
    final isOverdue = charge.status == ChargeStatus.overdue;
    final progress = charge.expectedAmount == 0
        ? 0.0
        : (charge.allocatedAmount / charge.expectedAmount).clamp(0.0, 1.0);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: PrototypeSpacing.sm,
            runSpacing: PrototypeSpacing.xs,
            children: [
              StatusChip(
                label: statusLabel,
                tone: _chargeStatusTone(charge.status),
              ),
              if (charge.dueDate != null)
                Text(
                  context.tr.dueDate(context.formatShortDate(charge.dueDate!)),
                  style: textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: PrototypeSpacing.md),
          Row(
            children: [
              Expanded(
                child: SummaryMetric(
                  label: context.tr.expected,
                  value: formatMoney(
                    charge.expectedAmount,
                    charge.currency,
                    context.tr.localeName,
                  ),
                ),
              ),
              Expanded(
                child: SummaryMetric(
                  label: context.tr.feeStatusPaid,
                  value: formatMoney(
                    charge.allocatedAmount,
                    charge.currency,
                    context.tr.localeName,
                  ),
                  valueColor: charge.allocatedAmount > 0
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              Expanded(
                child: SummaryMetric(
                  label: context.tr.balance,
                  value: formatMoney(
                    charge.remainingObligation,
                    charge.currency,
                    context.tr.localeName,
                  ),
                  valueColor: charge.remainingObligation > 0 && isOverdue
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: PrototypeSpacing.sm),
          PrototypeProgressBar(value: progress),
          const SizedBox(height: PrototypeSpacing.xs),
          Text(
            context.tr.paidLabel((progress * 100).round()),
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class ChargeInstallmentCard extends StatelessWidget {
  const ChargeInstallmentCard({
    super.key,
    required this.installment,
    required this.currency,
  });

  final ChargeInstallment installment;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.event_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: PrototypeSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  installment.label.isEmpty
                      ? context.tr.dueDateLabel
                      : installment.label,
                  style: textTheme.titleSmall,
                ),
                if (installment.dueDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.tr.dueDate(
                      context.formatShortDate(installment.dueDate!),
                    ),
                    style: textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          FeeAmountTrailing(
            amount: formatMoney(
              installment.expectedAmount,
              currency,
              context.tr.localeName,
            ),
            label: context.tr.expected,
          ),
        ],
      ),
    );
  }
}
