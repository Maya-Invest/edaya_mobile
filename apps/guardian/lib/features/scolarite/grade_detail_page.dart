import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'grade_detail_controller.dart';

class GradeDetailPage extends LScopedView<GradeDetailController> {
  const GradeDetailPage({super.key, required this.gradeId});

  final String gradeId;

  @override
  GradeDetailController onConfigScope(LevitScope scope) {
    return scope.put(
      () => GradeDetailController(
        gradeId: gradeId,
        studentContext: scope.find<StudentContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, GradeDetailController controller) {
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);

    if (controller.isBusy.value && controller.entry.value == null) {
      return PrototypeDetailScaffold(
        embedded: embedded,
        fallbackRoute: '/scolarite/notes',
        title: 'Détail de la note',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final grade = controller.entry.value;
    if (grade == null) {
      return PrototypeDetailScaffold(
        embedded: embedded,
        fallbackRoute: '/scolarite/notes',
        title: 'Détail de la note',
        body: EmptyState(
          title: controller.errorMessage.value.isEmpty
              ? 'Note introuvable'
              : controller.errorMessage.value,
        ),
      );
    }

    return PrototypeDetailScaffold(
      embedded: embedded,
      fallbackRoute: '/scolarite/notes',
      title: 'Détail de la note',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grade.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                Text(
                  grade.score == null
                      ? '—'
                      : '${grade.score!.toInt()} / ${grade.maxScore.toInt()}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: PrototypeColors.primary,
                  ),
                ),
                const SizedBox(height: PrototypeSpacing.md),
                SummaryMetric(label: 'Matière', value: grade.subjectName),
                const SizedBox(height: PrototypeSpacing.sm),
                SummaryMetric(label: 'Période', value: grade.periodName),
                const SizedBox(height: PrototypeSpacing.sm),
                SummaryMetric(
                  label: 'Coefficient',
                  value: grade.coefficient.toString(),
                ),
                if ((grade.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: PrototypeSpacing.md),
                  Text(
                    grade.notes!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
