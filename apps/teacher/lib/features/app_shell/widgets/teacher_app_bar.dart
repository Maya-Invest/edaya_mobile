import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../../access/app_runtime.dart';
import '../../../common/utils/date_time_parse.dart';

class TeacherAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TeacherAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 28);

  @override
  Widget build(BuildContext context) {
    final isEvaluations =
        GoRouterState.of(context).uri.toString().startsWith('/evaluations');

    return AppBar(
      leading: IconButton(
        tooltip: 'Account',
        icon: const Icon(Icons.account_circle_outlined),
        onPressed: () => context.push('/account'),
      ),
      title: LWatch(
        () {
          final staffContext = AppRuntime.staffContext;
          final classLabel =
              staffContext.classFilterLabel ?? 'All classes';

          if (isEvaluations) {
            final evaluations = AppRuntime.evaluations;
            final count = evaluations.evaluations.value.length;
            final countLabel =
                count == 1 ? '1 evaluation' : '$count evaluations';
            final periodLabel = evaluations.selectedPeriodLabel;
            final periodPart =
                periodLabel == null ? countLabel : '$periodLabel · $countLabel';
            return _AppBarTitle(
              title: 'Evaluations',
              subtitle: '$classLabel · $periodPart',
            );
          }

          final calendar = AppRuntime.calendar;
          final dayLabel = formatShortDate(calendar.selectedDay.value);
          final sessionCount = calendar.sessionsForSelectedDay.length;
          final sessionLabel = sessionCount == 1
              ? '1 session'
              : '$sessionCount sessions';

          return _AppBarTitle(
            title: 'Calendar',
            subtitle: '$classLabel · $dayLabel · $sessionLabel',
          );
        },
      ),
      actions: [
        if (isEvaluations)
          IconButton(
            tooltip: 'New evaluation',
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/evaluations/create'),
          ),
        IconButton(
          tooltip: 'Filter',
          icon: const Icon(Icons.filter_list),
          onPressed: () => context.push('/class-filter'),
        ),
      ],
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
