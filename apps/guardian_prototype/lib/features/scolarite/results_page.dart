import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import 'results_controller.dart';

/// Main Scolarité tab — grades and report cards.
class ResultsPage extends LScopedView<ResultsController> {
  const ResultsPage({super.key});

  @override
  ResultsController onConfigScope(LevitScope scope) {
    return scope.put(() => ResultsController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, ResultsController controller) {
    return LWatch(() {
      controller.storeTick.value;
      controller.expandedPeriodIds.value;
      final store = controller.store;
      final periods = store.academicPeriods;
      final overallProgress = store.overallProgramProgress;
      final expandedPeriodIds = controller.expandedPeriodIds.value;

      return AdaptiveContent(
        child: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            onTap: () => context.go('/scolarite/progress'),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PrototypeColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insights_outlined, color: Colors.blue),
                ),
                const SizedBox(width: PrototypeSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avancement du programme',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${(overallProgress * 100).round()} % couvert · '
                        '${store.subjectsWithProgrammeCount} matières',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: PrototypeSpacing.xs),
                      PrototypeProgressBar(value: overallProgress),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.xl),
          for (var i = 0; i < periods.length; i++) ...[
            if (i > 0) const SizedBox(height: PrototypeSpacing.xl),
            _PeriodSectionHeader(
              period: periods[i],
              expanded: expandedPeriodIds.contains(periods[i].id),
              onToggle: () => controller.togglePeriod(periods[i].id),
            ),
            if (expandedPeriodIds.contains(periods[i].id)) ...[
              if (store.reportCardForPeriod(periods[i].label)
                  case final reportCard?) ...[
                const SizedBox(height: PrototypeSpacing.xs),
                ListRow(
                  title: 'Bulletin',
                  subtitle: 'Publié le ${formatDate(reportCard.publishedAt)}',
                  tint: PrototypeColors.primaryContainer,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PrototypeColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: PrototypeColors.primary,
                    ),
                  ),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        reportCard.average,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: PrototypeColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Moyenne',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  onTap: () => context.go('/report-card/${reportCard.id}'),
                ),
              ],
              for (final result
                  in store.subjectResultsForPeriod(periods[i].label)) ...[
                const SizedBox(height: PrototypeSpacing.xs),
                ListRow(
                  title: result.subject,
                  subtitle: result.gradeCount == 0
                      ? 'Aucune évaluation'
                      : result.gradeCount == 1
                      ? '1 évaluation'
                      : '${result.gradeCount} évaluations',
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result.averageLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: result.hasAverage
                              ? PrototypeColors.primary
                              : PrototypeColors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        result.state.label,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  onTap: () => context.go(
                    '/scolarite/period/${periods[i].id}/subject/${MockStore.subjectRouteParam(result.subject)}',
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

class _PeriodSectionHeader extends StatelessWidget {
  const _PeriodSectionHeader({
    required this.period,
    required this.expanded,
    required this.onToggle,
  });

  final MockAcademicPeriod period;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(PrototypeRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PrototypeSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  period.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusChip(
                label: period.status == MockPeriodStatus.open
                    ? 'En cours'
                    : 'À venir',
                tone: period.status == MockPeriodStatus.open
                    ? SemanticTone.info
                    : SemanticTone.neutral,
              ),
              const SizedBox(width: PrototypeSpacing.xs),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: PrototypeColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
