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
    final overdueStyle = summary.overdue > 0
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.error,
            fontFeatures: const [FontFeature.tabularFigures()],
          )
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.summary, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ResponsiveMetrics(
              children: [
                _Metric(
                  label: l10n.availableAmount,
                  value: formatMoney(summary.available, summary.currency),
                ),
                _Metric(
                  label: l10n.outstandingAmount,
                  value: formatMoney(summary.outstanding, summary.currency),
                ),
                _Metric(
                  label: l10n.overdueAmount,
                  value: formatMoney(summary.overdue, summary.currency),
                  valueStyle: overdueStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(
          value,
          style:
              valueStyle ??
              Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }
}
