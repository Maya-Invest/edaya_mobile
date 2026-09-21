import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_mappers.dart';
import '../../mock/mock_store.dart';
import '../context/academic_year_controller.dart';
import '../context/store_bound_controller.dart';
import '../context/student_context_controller.dart';
import 'grade_detail_controller.dart';

class GradeDetailPage extends StatelessWidget {
  const GradeDetailPage({super.key, required this.gradeId});

  final String gradeId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveGradeDetailPage(gradeId: gradeId);
    }
    return _MockGradeDetailPage(gradeId: gradeId);
  }
}

class _MockGradeDetailPage extends LScopedView<StoreBoundController> {
  const _MockGradeDetailPage({required this.gradeId});

  final String gradeId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final mockGrade = controller.store.gradeById(gradeId);
    if (mockGrade == null) {
      return const PrototypeDetailScaffold(
        fallbackRoute: '/scolarite/notes',
        title: 'Détail de la note',
        body: EmptyState(title: 'Note introuvable'),
      );
    }
    final grade = gradeEntryFromMock(mockGrade);
    return PrototypeDetailScaffold(
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
                  '${grade.score!.toInt()} / ${grade.maxScore.toInt()}',
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveGradeDetailPage extends LScopedView<GradeDetailController> {
  const _LiveGradeDetailPage({required this.gradeId});

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
    if (controller.isBusy.value && controller.entry.value == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/scolarite/notes',
        title: 'Détail de la note',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final grade = controller.entry.value;
    if (grade == null) {
      return PrototypeDetailScaffold(
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
