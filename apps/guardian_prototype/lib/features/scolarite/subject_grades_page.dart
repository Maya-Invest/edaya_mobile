import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import 'subject_grades_controller.dart';

class SubjectGradesPage extends LScopedView<SubjectGradesController> {
  const SubjectGradesPage({
    super.key,
    required this.periodId,
    required this.subject,
  });

  final String periodId;
  final String subject;

  @override
  SubjectGradesController onConfigScope(LevitScope scope) {
    return scope.put(
      () => SubjectGradesController(
        scope.find<MockStore>(),
        periodId: periodId,
        subject: subject,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, SubjectGradesController controller) {
    return LWatch(() {
      controller.storeTick.value;
      final embedded = PrototypeBreakpoints.detailDrawerActive(context);
      final store = controller.store;
      final period = store.periodById(controller.periodId);
      if (period == null) {
        return PrototypeDetailScaffold(
          embedded: embedded,
          fallbackRoute: '/scolarite/notes',
          title: controller.subject,
          body: const EmptyState(title: 'Période introuvable'),
        );
      }

      final results = store.subjectResultsFor(controller.subject, period.label);
      final grades =
          store.gradesForSubjectAndPeriod(controller.subject, period.label);

      return PrototypeDetailScaffold(
        embedded: embedded,
        fallbackRoute: '/scolarite/notes',
        title: controller.subject,
        body: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            if (results != null)
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            period.label,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              results.averageLabel,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: results.hasAverage
                                    ? PrototypeColors.primary
                                    : PrototypeColors.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              results.state.label,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (results.hasTeacherFeedback) ...[
                      const SizedBox(height: PrototypeSpacing.md),
                      const Divider(height: 1),
                      const SizedBox(height: PrototypeSpacing.md),
                      if (results.teacherName != null) ...[
                        Text(
                          'Enseignant',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          results.teacherName!,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: PrototypeSpacing.sm),
                      ],
                      if (results.teacherComment != null) ...[
                        Text(
                          'Appréciation',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          results.teacherComment!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            const SizedBox(height: PrototypeSpacing.md),
            const SectionHeader(title: 'Évaluations'),
            if (grades.isEmpty)
              const EmptyState(
                title: 'Aucune évaluation',
                message: 'Les notes de cette matière ne sont pas encore disponibles.',
              )
            else
              for (final grade in grades) ...[
                ListRow(
                  title: grade.title,
                  subtitle: formatDate(grade.date),
                  trailing: Text(
                    '${grade.score.toInt()}/${grade.maxScore.toInt()}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: PrototypeColors.primary,
                    ),
                  ),
                  onTap: () => context.go('/grade/${grade.id}'),
                ),
                const SizedBox(height: PrototypeSpacing.xs),
              ],
          ],
        ),
      );
    });
  }
}
