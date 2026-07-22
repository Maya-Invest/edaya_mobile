import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import 'grade_detail_controller.dart';

class GradeDetailPage extends LScopedView<GradeDetailController> {
  const GradeDetailPage({super.key, required this.gradeId});

  final String gradeId;

  @override
  GradeDetailController onConfigScope(LevitScope scope) {
    return scope.put(
      () => GradeDetailController(
        scope.find<MockStore>(),
        gradeId: gradeId,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, GradeDetailController controller) {
    return LWatch(() {
      controller.storeTick.value;
      final embedded = PrototypeBreakpoints.detailDrawerActive(context);
      final store = controller.store;
      final grade = store.gradeById(controller.gradeId);
      if (grade == null) {
        return PrototypeDetailScaffold(
          embedded: embedded,
          fallbackRoute: '/scolarite/notes',
          title: 'Détail de la note',
          body: const EmptyState(title: 'Note introuvable'),
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
                  Text(grade.title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: PrototypeSpacing.sm),
                  Text(
                    '${grade.score.toInt()} / ${grade.maxScore.toInt()}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: PrototypeColors.primary,
                    ),
                  ),
                  const SizedBox(height: PrototypeSpacing.md),
                  SummaryMetric(label: 'Matière', value: grade.subject),
                  const SizedBox(height: PrototypeSpacing.sm),
                  SummaryMetric(label: 'Période', value: grade.period),
                  const SizedBox(height: PrototypeSpacing.sm),
                  SummaryMetric(
                    label: 'Coefficient',
                    value: grade.coefficient.toString(),
                  ),
                  const SizedBox(height: PrototypeSpacing.md),
                  const StatusChip(
                    label: 'Moyenne provisoire',
                    tone: SemanticTone.warning,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
