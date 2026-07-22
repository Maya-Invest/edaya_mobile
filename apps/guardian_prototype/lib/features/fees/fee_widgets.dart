import 'package:flutter/material.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';

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
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(color: labelColor),
        ),
      ],
    );
  }
}

SemanticTone _feeStatusTone(String status) {
  return switch (status) {
    'En retard' => SemanticTone.error,
    'Payé' => SemanticTone.success,
    'Partiel' => SemanticTone.warning,
    _ => SemanticTone.neutral,
  };
}

class FeeDetailSummaryCard extends StatelessWidget {
  const FeeDetailSummaryCard({super.key, required this.fee});

  final MockFeeLine fee;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isOverdue = fee.status == 'En retard';

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(label: fee.status, tone: _feeStatusTone(fee.status)),
              const Spacer(),
              if (fee.dueDate != null)
                Text(
                  'Échéance ${formatDate(fee.dueDate!)}',
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
                  value: formatMoney(fee.expected, fee.currency),
                ),
              ),
              Expanded(
                child: SummaryMetric(
                  label: 'Payé',
                  value: formatMoney(fee.paid, fee.currency),
                  valueColor: fee.paid > 0 ? PrototypeColors.primary : null,
                ),
              ),
              Expanded(
                child: SummaryMetric(
                  label: 'Solde',
                  value: formatMoney(fee.balance, fee.currency),
                  valueColor: fee.balance > 0 && isOverdue
                      ? PrototypeColors.error
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: PrototypeSpacing.sm),
          PrototypeProgressBar(value: fee.progress),
          const SizedBox(height: PrototypeSpacing.xs),
          Text(
            '${(fee.progress * 100).round()} % réglé',
            style: textTheme.bodySmall?.copyWith(
              color: PrototypeColors.onSurfaceVariant,
            ),
          ),
          if (fee.description != null) ...[
            const SizedBox(height: PrototypeSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: PrototypeSpacing.md),
            Text(
              fee.description!,
              style: textTheme.bodyMedium?.copyWith(
                color: PrototypeColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class InstallmentCard extends StatelessWidget {
  const InstallmentCard({super.key, required this.installment});

  final MockFeeInstallment installment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isOverdue = installment.status == 'En retard';
    final isPaid = installment.isPaid;
    final tone = _feeStatusTone(installment.status);

    final icon = isPaid
        ? Icons.check_circle_outline
        : isOverdue
        ? Icons.warning_amber_rounded
        : Icons.event_outlined;
    final (iconBg, iconColor) = switch (tone) {
      SemanticTone.error => (
        PrototypeColors.errorContainer,
        PrototypeColors.error,
      ),
      SemanticTone.success => (
        PrototypeColors.primaryContainer,
        PrototypeColors.primary,
      ),
      _ => (
        PrototypeColors.primaryContainer,
        PrototypeColors.primary,
      ),
    };

    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: PrototypeSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(installment.label, style: textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Échéance ${formatDate(installment.dueDate)}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          FeeAmountTrailing(
            amount: formatMoney(
              isPaid ? installment.amount : installment.balance,
              installment.currency,
            ),
            label: installment.status,
            labelColor: isOverdue ? PrototypeColors.error : null,
          ),
        ],
      ),
    );
  }
}

