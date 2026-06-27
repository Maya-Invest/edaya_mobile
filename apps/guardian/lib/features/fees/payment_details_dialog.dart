import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../common/utils/date_time_parse.dart';
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
  Widget buildView(
    BuildContext context,
    PaymentDetailsController controller,
  ) {
    final payment = controller.payment;

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
                    'Payment details',
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
              label: 'Amount',
              value: formatMoney(payment.amount, payment.currency),
            ),
            _DetailRow(
              label: 'Date',
              value: formatLongDate(payment.paymentDate),
            ),
            _DetailRow(
              label: 'Method',
              value: formatPaymentMethod(payment.method),
            ),
            if (payment.reference != null && payment.reference!.isNotEmpty)
              _DetailRow(label: 'Reference', value: payment.reference!),
            if (payment.notes != null && payment.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Notes',
                style: Theme.of(context).textTheme.labelLarge,
              ),
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
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
