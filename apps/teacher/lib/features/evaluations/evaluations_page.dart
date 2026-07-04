import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'evaluations_controller.dart';
import 'models/evaluation_models.dart';
import 'widgets/academic_period_picker.dart';

class EvaluationsPage extends LView<EvaluationsController> {
  const EvaluationsPage({super.key});

  @override
  Widget buildView(BuildContext context, EvaluationsController controller) {
    return LWatch(
      () => DataState(
        status: controller.dataStatus,
        errorMessage: controller.errorMessage.value,
        emptyMessage: controller.emptyMessage,
        onRetry: controller.loadEvaluations,
        child: RefreshIndicator(
          onRefresh: controller.reloadPeriodsAndEvaluations,
          child: _EvaluationsBody(controller: controller),
        ),
      ),
    );
  }
}

class _EvaluationsBody extends StatelessWidget {
  const _EvaluationsBody({required this.controller});

  final EvaluationsController controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.evaluations.value;
    final periods = controller.periods.value;
    final selectedPeriodId = controller.selectedPeriodId.value;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (periods.isNotEmpty) ...[
          AcademicPeriodPicker(
            periods: periods,
            selectedPeriodId: selectedPeriodId,
            onPeriodSelected: controller.selectPeriod,
          ),
          const SizedBox(height: 16),
        ],
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Center(child: Text(controller.emptyMessage)),
          )
        else
          ...[
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              _EvaluationCard(
                controller: controller,
                evaluation: items[index],
              ),
            ],
          ],
      ],
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  const _EvaluationCard({
    required this.controller,
    required this.evaluation,
  });

  final EvaluationsController controller;
  final EvaluationSummary evaluation;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () async {
          await controller.loadMarks(evaluation);
          if (!context.mounted) {
            return;
          }
          context.push('/evaluations/marks', extra: evaluation);
        },
        title: Text(evaluation.title),
        subtitle: Text(
          '${evaluation.classLabel} · ${evaluation.subjectLabel}\n'
          '${context.tr.evaluationGradedProgress(evaluation.gradedCount, evaluation.totalStudents)}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
