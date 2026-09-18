import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
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
                                    ? PrototypeColors.primary
                                    : PrototypeColors.onSurfaceVariant,
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
                  grade.score == null
                      ? '—'
                      : '${grade.score!.toInt()}/${grade.maxScore.toInt()}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: PrototypeColors.primary,
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
