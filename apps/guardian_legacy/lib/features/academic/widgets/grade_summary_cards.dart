import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

import '../models/grade_entry.dart';

class GradeSummaryCards extends StatelessWidget {
  const GradeSummaryCards({
    super.key,
    required this.overallAverage,
    required this.gradedCount,
    required this.totalCount,
  });

  final double? overallAverage;
  final int gradedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.tr;
    return ResponsiveMetrics(
      minimumWidth: 100,
      children: [
        _SummaryCard(
          label: l10n.average,
          value: overallAverage == null
              ? l10n.noScoreDash
              : overallAverage!.toStringAsFixed(1),
          suffix: l10n.scoreOutOfTwenty,
        ),
        _SummaryCard(label: l10n.graded, value: '$gradedCount'),
        _SummaryCard(label: l10n.pending, value: '${totalCount - gradedCount}'),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, this.suffix});

  final String label;
  final String value;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                text: value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                children: suffix == null
                    ? null
                    : [
                        TextSpan(
                          text: suffix,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubjectGradeGroupTile extends StatelessWidget {
  const SubjectGradeGroupTile({
    super.key,
    required this.group,
    required this.onGradeTap,
  });

  final SubjectGradeGroup group;
  final ValueChanged<GradeEntry> onGradeTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.tr;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(group.subjectName),
        subtitle: Text(
          group.average == null
              ? l10n.assessmentCount(group.entries.length)
              : l10n.subjectAverage(group.average!.toStringAsFixed(1)),
        ),
        children: [
          for (final entry in group.entries)
            ListTile(
              title: Text(entry.title),
              subtitle: Text(
                [
                  entry.periodName,
                  if (entry.date != null)
                    '${entry.date!.day}/${entry.date!.month}/${entry.date!.year}',
                ].join(' · '),
              ),
              trailing: Text(
                entry.hasScore
                    ? '${entry.score!.toStringAsFixed(1)} / ${entry.maxScore.toStringAsFixed(0)}'
                    : l10n.noScoreDash,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              onTap: () => onGradeTap(entry),
            ),
        ],
      ),
    );
  }
}
