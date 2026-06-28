import 'package:flutter/material.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../models/report_card_summary.dart';

class ReportCardTile extends StatelessWidget {
  const ReportCardTile({
    super.key,
    required this.reportCard,
    required this.onTap,
  });

  final ReportCardSummary reportCard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final published = reportCard.publishedAt;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Text(reportCard.periodName),
        subtitle: Text(
          published == null
              ? 'Published report card'
              : 'Published ${formatShortDate(published)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (reportCard.overallAverage != null)
                  Text(
                    '${reportCard.overallAverage!.toStringAsFixed(1)} / 20',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                if (reportCard.rank != null && reportCard.classSize != null)
                  Text(
                    'Rank ${reportCard.rank}/${reportCard.classSize}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
