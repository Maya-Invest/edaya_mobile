import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import '../academic/models/grade_entry.dart';
import '../academic/models/report_card_summary.dart';
import '../academic/widgets/grade_summary_cards.dart';
import '../academic/widgets/report_card_tile.dart';
import 'evaluations_controller.dart';
import 'widgets/academic_period_picker.dart';

class EvaluationsPage extends LScopedView<EvaluationsController> {
  const EvaluationsPage({super.key});

  @override
  EvaluationsController onConfigScope(LevitScope scope) {
    return scope.put(
      () => EvaluationsController(
        studentContext: scope.find<StudentContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, EvaluationsController controller) {
    return LWatch(
      () {
        final status = controller.dataStatus;

        return DataState(
          status: status,
          errorMessage: controller.errorMessage.value,
          emptyMessage: controller.emptyMessage,
          onRetry: controller.reloadData,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SegmentedButton<EvaluationsView>(
                  segments: [
                    ButtonSegment(
                      value: EvaluationsView.grades,
                      label: Text(context.tr.academicViewGrades),
                      icon: const Icon(Icons.grade_outlined),
                    ),
                    ButtonSegment(
                      value: EvaluationsView.reportCards,
                      label: Text(context.tr.academicViewReports),
                      icon: const Icon(Icons.description_outlined),
                    ),
                  ],
                  selected: {controller.view.value},
                  onSelectionChanged: (selection) {
                    controller.selectView(selection.first);
                  },
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.reloadData,
                  child: LWatch(
                    () {
                      switch (controller.view.value) {
                        case EvaluationsView.grades:
                          return _GradesBody(controller: controller);
                        case EvaluationsView.reportCards:
                          return _ReportCardsBody(controller: controller);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GradesBody extends StatelessWidget {
  const _GradesBody({required this.controller});

  final EvaluationsController controller;

  @override
  Widget build(BuildContext context) {
    return LWatch(
      () {
        final periods = controller.periods.value;
        final groups = controller.filteredGradeGroups;
        final totalCount = groups.fold<int>(
          0,
          (count, group) => count + group.entries.length,
        );

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (periods.isNotEmpty) ...[
              AcademicPeriodPicker(
                periods: periods,
                selectedPeriodId: controller.selectedPeriodId.value,
                onPeriodSelected: controller.selectPeriod,
              ),
              const SizedBox(height: 16),
            ],
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(child: Text(controller.emptyMessage)),
              )
            else ...[
              GradeSummaryCards(
                overallAverage: controller.overallAverage,
                gradedCount: controller.gradedCount,
                totalCount: totalCount,
              ),
              const SizedBox(height: 12),
              for (final group in groups) ...[
                SubjectGradeGroupTile(
                  group: group,
                  onGradeTap: (entry) => _openGradeDetails(context, entry),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        );
      },
    );
  }

  void _openGradeDetails(BuildContext context, GradeEntry entry) {
    context.push('/evaluations/grade-details', extra: entry);
  }
}

class _ReportCardsBody extends StatelessWidget {
  const _ReportCardsBody({required this.controller});

  final EvaluationsController controller;

  @override
  Widget build(BuildContext context) {
    return LWatch(
      () {
        final cards = controller.filteredReportCards;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (cards.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(child: Text(controller.emptyMessage)),
              )
            else
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                ReportCardTile(
                  reportCard: cards[index],
                  onTap: () => _openReportCardDetails(context, cards[index]),
                ),
              ],
          ],
        );
      },
    );
  }

  void _openReportCardDetails(BuildContext context, ReportCardSummary card) {
    context.push('/evaluations/report-card-details', extra: card);
  }
}
