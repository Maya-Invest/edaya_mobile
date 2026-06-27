import 'package:flutter/material.dart';

import '../models/fee_formatting.dart';
import '../models/payment_record.dart';

class FeesSummaryCard extends StatelessWidget {
  const FeesSummaryCard({super.key, required this.summary});

  final FeesSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Expected',
                    value: formatMoney(
                      summary.totalExpected,
                      summary.currency,
                    ),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Paid',
                    value: formatMoney(summary.totalPaid, summary.currency),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Balance',
                    value: formatMoney(
                      summary.totalBalance,
                      summary.currency,
                    ),
                  ),
                ),
              ],
            ),
            if (summary.overdueCount > 0) ...[
              const SizedBox(height: 12),
              Text(
                '${summary.overdueCount} overdue fee line(s)',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}
