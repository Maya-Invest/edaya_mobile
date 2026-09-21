import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/academic_year_controller.dart';
import '../context/store_bound_controller.dart';
import '../context/student_context_controller.dart';
import 'results_controller.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveResultsPage();
    }
    return const _MockResultsPage();
  }
}

class _MockResultsPage extends LScopedView<StoreBoundController> {
  const _MockResultsPage();

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final periods = store.academicPeriods;
    return AdaptiveContent(
      child: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            onTap: () => context.push('/scolarite/progress'),
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
                        '${(store.overallProgramProgress * 100).round()} % couvert · '
                        '${store.subjectsWithProgrammeCount} matières',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: PrototypeSpacing.xs),
                      PrototypeProgressBar(value: store.overallProgramProgress),
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
              period: ResultsPeriod(
                id: periods[i].id,
                label: periods[i].label,
                isCurrent: periods[i].id == store.selectedPeriodId,
              ),
              expanded: true,
              onToggle: () {},
            ),
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
                onTap: () => context.push('/report-card/${reportCard.id}'),
              ),
            ],
            for (final result in store.subjectResultsForPeriod(
              periods[i].label,
            )) ...[
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
                onTap: () => context.push(
                  '/scolarite/period/${periods[i].id}/subject/${MockStore.subjectRouteParam(result.subject)}',
                ),
              ),
            ],
            const SizedBox(height: PrototypeSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _LiveResultsPage extends LScopedView<ResultsController> {
  const _LiveResultsPage();

  @override
  ResultsController onConfigScope(LevitScope scope) {
    return scope.put(
      () => ResultsController(
        studentContext: scope.find<StudentContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, ResultsController controller) {
    final periods = controller.periods.value;
    final overallProgress = controller.overallProgramProgress.value;
    final expandedPeriodIds = controller.expandedPeriodIds.value;

    if (controller.dataStatus == DataStatus.loading) {
      return const AdaptiveContent(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AdaptiveContent(
      child: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            onTap: () => context.push('/scolarite/progress'),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PrototypeColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.insights_outlined,
                    color: Colors.blue,
                  ),
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
                        '${controller.subjectsWithProgrammeCount.value} matières',
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
              if (controller.reportCardForPeriod(periods[i].id)
                  case final reportCard?) ...[
                const SizedBox(height: PrototypeSpacing.xs),
                ListRow(
                  title: 'Bulletin',
                  subtitle: reportCard.publishedAt == null
                      ? 'Publié'
                      : 'Publié le ${formatDate(reportCard.publishedAt!)}',
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
                        reportCard.overallAverage == null
                            ? '—'
                            : reportCard.overallAverage!
                                  .toStringAsFixed(1)
                                  .replaceAll('.', ','),
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
                  onTap: () => context.push('/report-card/${reportCard.id}'),
                ),
              ],
              for (final result in controller.subjectResultsForPeriod(
                periods[i].id,
              )) ...[
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
                        result.stateLabel,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  onTap: () => context.push(
                    '/scolarite/period/${periods[i].id}/subject/${ResultsController.subjectRouteParam(result.subject)}',
                  ),
                ),
              ],
              const SizedBox(height: PrototypeSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }
}

class _PeriodSectionHeader extends StatelessWidget {
  const _PeriodSectionHeader({
    required this.period,
    required this.expanded,
    required this.onToggle,
  });

  final ResultsPeriod period;
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
              if (period.isCurrent)
                const StatusChip(label: 'En cours', tone: SemanticTone.info),
              Icon(expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
      ),
    );
  }
}
