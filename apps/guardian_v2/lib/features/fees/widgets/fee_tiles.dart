import 'package:flutter/material.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../models/fee_formatting.dart';
import '../models/payment_record.dart';
import '../models/student_charge_line.dart';

class ChargeTile extends StatelessWidget {
  const ChargeTile({super.key, required this.line, required this.onTap});

  final StudentChargeLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.tr;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = switch (line.status) {
      ChargeStatus.paid => colorScheme.primary,
      ChargeStatus.overdue => colorScheme.error,
      ChargeStatus.partial => colorScheme.tertiary,
      ChargeStatus.cancelled => colorScheme.outline,
      ChargeStatus.waived => colorScheme.outline,
      ChargeStatus.pending => colorScheme.onSurfaceVariant,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        isThreeLine: line.dueDate != null || line.settlementCount > 0,
        title: Text(line.label),
        subtitle: Text(
          [
            formatChargeStatus(l10n, line.status),
            if (line.dueDate != null)
              l10n.dueDate(context.formatShortDate(line.dueDate!)),
            l10n.paidAmount(formatMoney(line.allocatedAmount, line.currency)),
            if (line.settlementCount > 0)
              l10n.paymentCount(line.settlementCount),
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMoney(line.remainingObligation, line.currency),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: statusColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class PaymentTile extends StatelessWidget {
  const PaymentTile({super.key, required this.payment, required this.onTap});

  final PaymentRecord payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.tr;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Text(payment.feeLabel),
        subtitle: Text(
          l10n.paymentMethodAndDate(
            formatPaymentMethod(l10n, payment.method),
            context.formatShortDate(payment.paymentDate),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMoney(payment.amount, payment.currency),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
