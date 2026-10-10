import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_mappers.dart';
import '../../mock/mock_store.dart';
import '../context/academic_year_controller.dart';
import '../context/store_bound_controller.dart';
import '../context/student_context_controller.dart';
import 'subject_grades_controller.dart';

class SubjectGradesPage extends StatelessWidget {
  const SubjectGradesPage({
    super.key,
    required this.periodId,
    required this.subject,
  });

  final String periodId;
  final String subject;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveSubjectGradesPage(periodId: periodId, subject: subject);
    }
    return _MockSubjectGradesPage(periodId: periodId, subject: subject);
  }
}

class _MockSubjectGradesPage extends LScopedView<StoreBoundController> {
  const _MockSubjectGradesPage({required this.periodId, required this.subject});

  final String periodId;
  final String subject;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final resolvedSubject = MockStore.subjectFromRouteParam(subject);
    final period = store.periodById(periodId);
    final periodLabel = period?.label ?? periodId;
    final result = store.subjectResultsFor(resolvedSubject, periodLabel);
    final grades = store.gradesForSubjectAndPeriod(
      resolvedSubject,
      periodLabel,
    );
    return PrototypeDetailScaffold(
      fallbackRoute: '/scolarite/notes',
      title: resolvedSubject,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        periodLabel,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          result?.averageLabel ?? '—',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: result?.hasAverage == true
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          'Moyenne',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          const SectionHeader(title: 'Évaluations'),
          if (grades.isEmpty)
            const EmptyState(
              title: 'Aucune évaluation',
              message:
                  'Les notes de cette matière ne sont pas encore disponibles.',
            )
          else
            for (final grade in grades.map(gradeEntryFromMock)) ...[
              ListRow(
                title: grade.title,
                subtitle: grade.date == null
                    ? grade.periodName
                    : formatDate(grade.date!),
                trailing: Text(
                  grade.scoreLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                onTap: () => context.push('/grade/${grade.id}'),
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
        ],
      ),
    );
  }
}

class _LiveSubjectGradesPage extends LScopedView<SubjectGradesController> {
  const _LiveSubjectGradesPage({required this.periodId, required this.subject});

  final String periodId;
  final String subject;

  @override
  SubjectGradesController onConfigScope(LevitScope scope) {
    return scope.put(
      () => SubjectGradesController(
        periodId: periodId,
        subject: subject,
        studentContext: scope.find<StudentContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, SubjectGradesController controller) {
    final grades = controller.grades.value;

    if (controller.isBusy.value && grades.isEmpty) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/scolarite/notes',
        title: controller.subject,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PrototypeDetailScaffold(
      fallbackRoute: '/scolarite/notes',
      title: controller.subject,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        controller.periodLabel.value,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          controller.averageLabel,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: controller.average.value != null
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          'Moyenne',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          const SectionHeader(title: 'Évaluations'),
          if (grades.isEmpty)
            const EmptyState(
              title: 'Aucune évaluation',
              message:
                  'Les notes de cette matière ne sont pas encore disponibles.',
            )
          else
            for (final grade in grades) ...[
              ListRow(
                title: grade.title,
                subtitle: grade.date == null
                    ? grade.periodName
                    : formatDate(grade.date!),
                trailing: Text(
                  grade.scoreLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                onTap: () => context.push('/grade/${grade.id}'),
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
        ],
      ),
    );
  }
}
