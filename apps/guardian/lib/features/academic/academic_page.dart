import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import '../../common/widgets/data_state.dart';
import 'academic_controller.dart';
import 'models/grade_entry.dart';
import 'models/report_card_summary.dart';
import 'widgets/curriculum_progress_tile.dart';
import 'widgets/grade_summary_cards.dart';
import 'widgets/report_card_tile.dart';

class AcademicPage extends LScopedView<AcademicController> {
  const AcademicPage({super.key});

  @override
  AcademicController onConfigScope(LevitScope scope) {
    return scope.put(
      () => AcademicController(
        studentContext: AppRuntime.studentContext,
        academicYear: AppRuntime.academicYear,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, AcademicController controller) {
    return LWatch(
      () {
        final status = controller.dataStatus;

        return DataState(
          status: status,
          errorMessage: controller.errorMessage.value,
          emptyMessage: controller.emptyMessage,
          onRetry: controller.loadAcademicData,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SegmentedButton<AcademicView>(
                  segments: const [
                    ButtonSegment(
                      value: AcademicView.grades,
                      label: Text('Grades'),
                      icon: Icon(Icons.grade_outlined),
                    ),
                    ButtonSegment(
                      value: AcademicView.curriculum,
                      label: Text('Curriculum'),
                      icon: Icon(Icons.menu_book_outlined),
                    ),
                    ButtonSegment(
                      value: AcademicView.reportCards,
                      label: Text('Reports'),
                      icon: Icon(Icons.description_outlined),
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
                  onRefresh: controller.loadAcademicData,
                  child: _AcademicBody(controller: controller),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AcademicBody extends StatelessWidget {
  const _AcademicBody({required this.controller});

  final AcademicController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.view.value) {
      case AcademicView.grades:
        return _GradesBody(controller: controller);
      case AcademicView.curriculum:
        return _CurriculumBody(controller: controller);
      case AcademicView.reportCards:
        return _ReportCardsBody(controller: controller);
    }
  }
}

class _GradesBody extends StatelessWidget {
  const _GradesBody({required this.controller});

  final AcademicController controller;

  @override
  Widget build(BuildContext context) {
    final groups = controller.filteredGradeGroups;
    final totalCount = groups.fold<int>(
      0,
      (count, group) => count + group.entries.length,
    );

    if (groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 48),
          Center(child: Text(controller.emptyMessage)),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (controller.periods.value.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All periods'),
                  selected: controller.selectedPeriodId.value == null,
                  onSelected: (_) => controller.selectPeriod(null),
                ),
                const SizedBox(width: 8),
                for (final period in controller.periods.value) ...[
                  FilterChip(
                    label: Text(period.name),
                    selected: controller.selectedPeriodId.value == period.id,
                    onSelected: (_) => controller.selectPeriod(period.id),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
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
    );
  }

  void _openGradeDetails(BuildContext context, GradeEntry entry) {
    context.push('/academic/grade-details', extra: entry);
  }
}

class _CurriculumBody extends StatelessWidget {
  const _CurriculumBody({required this.controller});

  final AcademicController controller;

  @override
  Widget build(BuildContext context) {
    final subjects = controller.curriculumSubjects.value;
    if (subjects.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 48),
          Center(child: Text(controller.emptyMessage)),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: subjects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return CurriculumProgressTile(subject: subjects[index]);
      },
    );
  }
}

class _ReportCardsBody extends StatelessWidget {
  const _ReportCardsBody({required this.controller});

  final AcademicController controller;

  @override
  Widget build(BuildContext context) {
    final cards = controller.reportCards.value;
    if (cards.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 48),
          Center(child: Text(controller.emptyMessage)),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final card = cards[index];
        return ReportCardTile(
          reportCard: card,
          onTap: () => _openReportCardDetails(context, card),
        );
      },
    );
  }

  void _openReportCardDetails(BuildContext context, ReportCardSummary card) {
    context.push('/academic/report-card-details', extra: card);
  }
}
