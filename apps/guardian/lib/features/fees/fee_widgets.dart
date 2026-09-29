import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import 'fee_detail_controller.dart';
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              amount,
              style: textTheme.titleSmall?.copyWith(
                color: PrototypeColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: PrototypeColors.onSurfaceVariant,
              ),
            ],
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
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
    final statusLabel = frenchChargeStatus(charge.status);
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
                  'Échéance ${context.formatShortDate(charge.dueDate!)}',
                  style: textTheme.labelSmall?.copyWith(
                    color: PrototypeColors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: PrototypeSpacing.md),
          Row(
            children: [
              Expanded(
                child: SummaryMetric(
                  label: 'Attendu',
                  value: formatMoney(charge.expectedAmount, charge.currency),
                ),
              ),
              Expanded(
                child: SummaryMetric(
                  label: 'Payé',
                  value: formatMoney(charge.allocatedAmount, charge.currency),
                  valueColor: charge.allocatedAmount > 0
                      ? PrototypeColors.primary
                      : null,
                ),
              ),
              Expanded(
                child: SummaryMetric(
                  label: 'Solde',
                  value: formatMoney(
                    charge.remainingObligation,
                    charge.currency,
                  ),
                  valueColor: charge.remainingObligation > 0 && isOverdue
                      ? PrototypeColors.error
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: PrototypeSpacing.sm),
          PrototypeProgressBar(value: progress),
          const SizedBox(height: PrototypeSpacing.xs),
          Text(
            '${(progress * 100).round()} % réglé',
            style: textTheme.bodySmall?.copyWith(
              color: PrototypeColors.onSurfaceVariant,
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
              color: PrototypeColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.event_outlined,
              size: 20,
              color: PrototypeColors.primary,
            ),
          ),
          const SizedBox(width: PrototypeSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  installment.label.isEmpty ? 'Échéance' : installment.label,
                  style: textTheme.titleSmall,
                ),
                if (installment.dueDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Échéance ${context.formatShortDate(installment.dueDate!)}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          FeeAmountTrailing(
            amount: formatMoney(installment.expectedAmount, currency),
            label: 'Attendu',
          ),
        ],
      ),
    );
  }
}
