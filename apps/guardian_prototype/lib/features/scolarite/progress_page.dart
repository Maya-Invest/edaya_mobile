import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import 'progress_controller.dart';

class ProgressOverviewPage extends LScopedView<ProgressController> {
  const ProgressOverviewPage({super.key});

  @override
  ProgressController onConfigScope(LevitScope scope) {
    return scope.put(() => ProgressController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, ProgressController controller) {
    return LWatch(() {
      controller.storeTick.value;
      controller.expandedSubjectIds.value;
      final embedded = PrototypeBreakpoints.detailDrawerActive(context);
      final store = controller.store;
      final summaries =
          store.subjectProgressSummaries.where((s) => s.hasProgramme).toList();
      final overall = store.overallProgramProgress;
      final expandedSubjectIds = controller.expandedSubjectIds.value;

      return PrototypeDetailScaffold(
        embedded: embedded,
        fallbackRoute: '/scolarite/notes',
        title: 'Avancement du programme',
        body: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(overall * 100).round()} % du programme couvert',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: PrototypeSpacing.xs),
                  PrototypeProgressBar(value: overall),
                  const SizedBox(height: PrototypeSpacing.xs),
                  Text(
                    'Moyenne indicative sur les matières suivies.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: PrototypeColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PrototypeSpacing.xl),
            for (var i = 0; i < summaries.length; i++) ...[
              if (i > 0) const SizedBox(height: PrototypeSpacing.xl),
              _SubjectProgressSectionHeader(
                summary: summaries[i],
                expanded: expandedSubjectIds.contains(summaries[i].subject),
                onOpenLogbook: () => context.go(
                  '/scolarite/subject/${MockStore.subjectRouteParam(summaries[i].subject)}/cahier',
                ),
                onToggle: () => controller.toggleSubject(summaries[i].subject),
              ),
              if (expandedSubjectIds.contains(summaries[i].subject)) ...[
                for (final topic
                    in store.topicsForSubject(summaries[i].subject)) ...[
                  const SizedBox(height: PrototypeSpacing.xs),
                  ListRow(
                    title: topic.title,
                    subtitle: topic.status,
                    trailing: Text(
                      '${(topic.progress * 100).round()} %',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: PrototypeColors.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: PrototypeSpacing.sm),
              ],
            ],
          ],
        ),
      );
    });
  }
}

class _SubjectProgressSectionHeader extends StatelessWidget {
  const _SubjectProgressSectionHeader({
    required this.summary,
    required this.expanded,
    required this.onOpenLogbook,
    required this.onToggle,
  });

  final SubjectProgressSummary summary;
  final bool expanded;
  final VoidCallback onOpenLogbook;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final percentLabel = '${(summary.progress * 100).round()} %';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PrototypeSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpenLogbook,
                borderRadius: BorderRadius.circular(PrototypeRadii.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    summary.subject,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                percentLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: PrototypeColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                summary.status,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(PrototypeRadii.sm),
              child: Padding(
                padding: const EdgeInsets.only(left: PrototypeSpacing.xs),
                child: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: PrototypeColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
