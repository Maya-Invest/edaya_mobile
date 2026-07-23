import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'fees_controller.dart';
import 'models/fee_formatting.dart';
import 'models/payment_record.dart';

class PaymentDetailsDialog extends LScopedView<PaymentDetailsController> {
  const PaymentDetailsDialog({super.key, required this.payment});

  final PaymentRecord payment;

  @override
  PaymentDetailsController onConfigScope(LevitScope scope) {
    return scope.put(() => PaymentDetailsController(payment: payment));
  }

  @override
  Widget buildView(BuildContext context, PaymentDetailsController controller) {
    final payment = controller.payment;
    final l10n = context.tr;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.paymentDetails,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(payment.feeLabel),
            const SizedBox(height: 16),
            _DetailRow(
              label: l10n.amount,
              value: formatMoney(payment.amount, payment.currency),
            ),
            _DetailRow(
              label: l10n.date,
              value: context.formatLongDate(payment.paymentDate),
            ),
            _DetailRow(
              label: l10n.method,
              value: formatPaymentMethod(l10n, payment.method),
            ),
            if (payment.reference != null && payment.reference!.isNotEmpty)
              _DetailRow(label: l10n.reference, value: payment.reference!),
            if (payment.notes != null && payment.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.notes, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(payment.notes!),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
