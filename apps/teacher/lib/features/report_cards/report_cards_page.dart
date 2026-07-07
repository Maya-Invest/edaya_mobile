import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../evaluations/widgets/academic_period_picker.dart';
import 'report_cards_controller.dart';

class ReportCardsPage extends LView<ReportCardsController> {
  const ReportCardsPage({super.key});

  @override
  Widget buildView(BuildContext context, ReportCardsController controller) {
    return LWatch(
      () => DataState(
        status: controller.dataStatus,
        errorMessage: controller.errorMessage.value,
        emptyMessage: controller.emptyMessage,
        onRetry: controller.loadClassSummaries,
        child: RefreshIndicator(
          onRefresh: controller.loadClassSummaries,
          child: _ReportCardsBody(controller: controller),
        ),
      ),
    );
  }
}

class _ReportCardsBody extends StatelessWidget {
  const _ReportCardsBody({required this.controller});

  final ReportCardsController controller;

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final periods = controller.periods;
      final summaries = controller.classSummaries.value;

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (periods.isNotEmpty) ...[
            AcademicPeriodPicker(
              periods: periods,
              selectedPeriodId: controller.selectedPeriodId,
              onPeriodSelected: controller.selectPeriod,
            ),
            const SizedBox(height: 16),
          ],
          if (summaries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(child: Text(controller.emptyMessage)),
            )
          else
            for (var index = 0; index < summaries.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              _ReportCardClassCard(summary: summaries[index]),
            ],
        ],
      );
    });
  }
}

class _ReportCardClassCard extends StatelessWidget {
  const _ReportCardClassCard({required this.summary});

  final ReportCardClassSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = summary.generatedCount == 0
        ? context.tr.reportCardClassNoResults
        : context.tr.reportCardClassProgress(
            summary.commentFilledCount,
            summary.generatedCount,
          );

    return Card(
      child: ListTile(
        title: Text(summary.classLabel, style: theme.textTheme.titleSmall),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: summary.generatedCount == 0
            ? null
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr.reportCardRosterComingSoon),
                  ),
                );
              },
      ),
    );
  }
}
