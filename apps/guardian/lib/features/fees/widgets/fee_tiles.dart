import 'package:flutter/material.dart';

import '../../../common/utils/date_time_parse.dart';
import '../models/fee_formatting.dart';
import '../models/payment_record.dart';
import '../models/student_fee_line.dart';

class StudentFeeTile extends StatelessWidget {
  const StudentFeeTile({super.key, required this.line});

  final StudentFeeLine line;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = switch (line.status) {
      StudentFeeStatus.paid => colorScheme.primary,
      StudentFeeStatus.overdue => colorScheme.error,
      StudentFeeStatus.partial => colorScheme.tertiary,
      StudentFeeStatus.cancelled => colorScheme.outline,
      StudentFeeStatus.pending => colorScheme.onSurfaceVariant,
    };

    return Card(
      child: ListTile(
        title: Text(line.label),
        subtitle: Text(
          [
            formatFeeStatus(line.status),
            if (line.dueDate != null)
              'Due ${formatShortDate(line.dueDate!)}',
            if (line.paymentCount > 0)
              '${line.paymentCount} payment(s)',
          ].join(' · '),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(line.expectedAmount, line.currency),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              'Paid ${formatMoney(line.paidAmount, line.currency)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentTile extends StatelessWidget {
  const PaymentTile({
    super.key,
    required this.payment,
    required this.onTap,
  });

  final PaymentRecord payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Text(payment.feeLabel),
        subtitle: Text(
          '${formatPaymentMethod(payment.method)} · ${formatShortDate(payment.paymentDate)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMoney(payment.amount, payment.currency),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
