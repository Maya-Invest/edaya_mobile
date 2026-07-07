import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../calendar/calendar_controller.dart';
import '../../context/teacher_context_controller.dart';
import '../../evaluations/evaluations_controller.dart';
import '../../report_cards/report_cards_controller.dart';
import '../../teaching/teaching_controller.dart';

class TeacherAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TeacherAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 28);

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final isEvaluations = location.startsWith('/evaluations');
    final isTeaching = location.startsWith('/teaching');
    final isReportCards = location.startsWith('/report-cards');

    return AppBar(
      leading: IconButton(
        tooltip: context.tr.tooltipAccount,
        icon: const Icon(Icons.account_circle_outlined),
        onPressed: () => context.push('/account'),
      ),
      title: LWatch(() {
        final teacherContext = context.levit.find<TeacherContextController>();

        if (isTeaching) {
          final teaching = context.levit.find<TeachingController>();
          return _AppBarTitle(
            title: context.tr.teachingTitle,
            subtitle: teaching.selectedScopeLabel ?? '—',
          );
        }

        if (isReportCards) {
          final reportCards = context.levit.find<ReportCardsController>();
          final periodLabel = reportCards.selectedPeriodLabel ?? '—';
          return _AppBarTitle(
            title: context.tr.reportCardsTitle,
            subtitle: periodLabel,
          );
        }

        final classLabel =
            teacherContext.classFilterLabel ?? context.tr.allClasses;

        if (isEvaluations) {
          final evaluations = context.levit.find<EvaluationsController>();
          final count = evaluations.evaluations.value.length;
          final countLabel = context.tr.evaluationCount(count);
          final periodLabel = evaluations.selectedPeriodLabel;
          final periodPart = periodLabel == null
              ? countLabel
              : '$periodLabel · $countLabel';
          return _AppBarTitle(
            title: context.tr.evaluationsTitle,
            subtitle: '$classLabel · $periodPart',
          );
        }

        final calendar = context.levit.find<CalendarController>();
        final dayLabel = context.formatShortDate(calendar.selectedDay.value);
        final sessionCount = calendar.sessionsForSelectedDay.length;
        final sessionLabel = context.tr.sessionCount(sessionCount);

        return _AppBarTitle(
          title: context.tr.calendarTitle,
          subtitle: '$classLabel · $dayLabel · $sessionLabel',
        );
      }),
      actions: [
        if (isEvaluations)
          IconButton(
            tooltip: context.tr.tooltipNewEvaluation,
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/evaluations/create'),
          ),
        if (!isTeaching && !isReportCards)
          IconButton(
            tooltip: context.tr.tooltipFilter,
            icon: const Icon(Icons.filter_list),
            onPressed: () => context.push('/class-filter'),
          ),
      ],
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
