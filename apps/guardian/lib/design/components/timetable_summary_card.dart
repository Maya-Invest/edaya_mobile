import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

import '../../mock/mock_store.dart';
import '../colors.dart';
import '../spacing.dart';
import 'status_chip.dart';
import 'surface_card.dart';

class TimetableSummaryCard extends StatelessWidget {
  const TimetableSummaryCard({super.key, required this.summary, this.onTap});

  final TimetableDaySummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.schedule_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: PrototypeSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.calendarViewTimetable,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: PrototypeSpacing.xs),
                if (summary.isEmpty)
                  Text(
                    context.tr.noClassesScheduled,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  Wrap(
                    spacing: PrototypeSpacing.xs,
                    runSpacing: PrototypeSpacing.xs,
                    children: [
                      if (summary.lessonCount > 0)
                        StatusChip(
                          label: _countLabel(summary.lessonCount, 'cours'),
                          tone: SemanticTone.info,
                        ),
                      if (summary.activityCount > 0)
                        StatusChip(
                          label: _countLabel(
                            summary.activityCount,
                            'activité',
                            'activités',
                          ),
                          tone: SemanticTone.success,
                        ),
                      if (summary.assessmentCount > 0)
                        StatusChip(
                          label: _countLabel(
                            summary.assessmentCount,
                            'évaluation',
                            'évaluations',
                          ),
                          tone: SemanticTone.warning,
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  String _countLabel(int count, String singular, [String? plural]) {
    final label = count > 1 ? (plural ?? singular) : singular;
    return '$count $label';
  }
}
