import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

import '../models/fee_formatting.dart';
import '../models/payment_record.dart';

class FeesSummaryCard extends StatelessWidget {
  const FeesSummaryCard({super.key, required this.summary});

  final FeesSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.tr;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.summary,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: l10n.expected,
                    value: formatMoney(
                      summary.totalExpected,
                      summary.currency,
                    ),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: l10n.paid,
                    value: formatMoney(summary.totalPaid, summary.currency),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: l10n.balance,
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
                l10n.overdueFeeLinesCount(summary.overdueCount),
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
