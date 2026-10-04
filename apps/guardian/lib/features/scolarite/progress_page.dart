import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart' show PrototypeRadii, PrototypeSpacing;
import '../../live/runtime.dart';
import '../../mock/mock_store.dart' hide SubjectProgressSummary;
import '../context/academic_year_controller.dart';
import '../context/store_bound_controller.dart';
import '../context/student_context_controller.dart';
import 'progress_controller.dart';
import 'results_controller.dart';

class ProgressOverviewPage extends StatelessWidget {
  const ProgressOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveProgressOverviewPage();
    }
    return const _MockProgressOverviewPage();
  }
}

class _MockProgressOverviewPage extends LScopedView<StoreBoundController> {
  const _MockProgressOverviewPage();

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final summaries = store.subjectProgressSummaries
        .where((s) => s.hasProgramme)
        .toList();
    return PrototypeDetailScaffold(
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
                  '${(store.overallProgramProgress * 100).round()} % du programme couvert',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: PrototypeSpacing.xs),
                PrototypeProgressBar(value: store.overallProgramProgress),
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
              summary: SubjectProgressSummary(
                subject: summaries[i].subject,
                classSubjectId: summaries[i].subject,
                progress: summaries[i].progress,
                status: summaries[i].status,
                topicCount: summaries[i].topicCount,
              ),
              expanded: true,
              onOpenLogbook: () => context.push(
                '/scolarite/subject/${MockStore.subjectRouteParam(summaries[i].subject)}/cahier',
              ),
              onToggle: () {},
            ),
            for (final topic in store.topicsForSubject(
              summaries[i].subject,
            )) ...[
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
      ),
    );
  }
}

class _LiveProgressOverviewPage extends LScopedView<ProgressController> {
  const _LiveProgressOverviewPage();

  @override
  ProgressController onConfigScope(LevitScope scope) {
    return scope.put(
      () => ProgressController(
        studentContext: scope.find<StudentContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, ProgressController controller) {
    final summaries = controller.summaries.value
        .where((s) => s.hasProgramme)
        .toList();
    final overall = controller.overallProgress.value;
    final expandedSubjectIds = controller.expandedSubjectIds.value;

    if (controller.isBusy.value && summaries.isEmpty) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/scolarite/notes',
        title: 'Avancement du programme',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PrototypeDetailScaffold(
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
              onOpenLogbook: () => context.push(
                '/scolarite/subject/${ResultsController.subjectRouteParam(summaries[i].subject)}/cahier',
              ),
              onToggle: () => controller.toggleSubject(summaries[i].subject),
            ),
            if (expandedSubjectIds.contains(summaries[i].subject)) ...[
              for (final topic in controller.topicsForSubject(
                summaries[i].subject,
              )) ...[
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
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(PrototypeRadii.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: PrototypeSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.subject,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          summary.status,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenLogbook,
                    child: const Text('Cahier'),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
        ),
        PrototypeProgressBar(value: summary.progress),
      ],
    );
  }
}
