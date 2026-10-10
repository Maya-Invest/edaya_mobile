import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../calendar/live_calendar_controller.dart';
import '../context/store_bound_controller.dart';
import 'accueil_task.dart';
import 'home_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveHomePage();
    }
    return const _MockHomePage();
  }
}

class _MockHomePage extends LScopedView<StoreBoundController> {
  const _MockHomePage();

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final tasks =
        store.todayTasks
            .map(
              (task) => AccueilTask(
                id: task.id,
                kind: task.kind,
                title: task.title,
                subtitle: task.subtitle,
                route: task.route,
                priority: _mockPriority(task.kind),
              ),
            )
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));
    return _AccueilBody(
      currentTitle: store.currentSession == null
          ? null
          : 'En cours · ${store.currentSession!.classLabel}',
      currentSubtitle: store.currentSession == null
          ? null
          : '${store.currentSession!.subject} · ${formatTimeRange(store.currentSession!.startHour, store.currentSession!.endHour)}',
      currentRoute: store.currentSession == null
          ? null
          : '/session/${store.currentSession!.id}',
      nextTitle: store.nextSession == null
          ? null
          : 'Prochaine · ${store.nextSession!.classLabel}',
      nextSubtitle: store.nextSession == null
          ? null
          : '${store.nextSession!.subject} · ${formatTimeRange(store.nextSession!.startHour, store.nextSession!.endHour)}',
      nextRoute: store.nextSession == null
          ? null
          : '/session/${store.nextSession!.id}',
      tasks: tasks,
      todaySessions: [
        for (final s in store.sessionsForDay(DateTime.now()))
          _TodaySessionRow(
            title: s.classLabel,
            subtitle: '${formatTimeRange(s.startHour, s.endHour)} · ${s.room}',
            badges: [
              if (!s.attendanceComplete) 'Présences',
              if (!s.logbookComplete) 'Cahier',
            ],
            route: '/session/${s.id}',
          ),
      ],
      onOpenAgenda: () {
        store.openCalendarDay(0);
        context.go('/calendar');
      },
    );
  }
}

class _LiveHomePage extends LView<LiveHomeController> {
  const _LiveHomePage();

  @override
  Widget buildView(BuildContext context, LiveHomeController controller) {
    return LWatch(() {
      controller.tick.value;
      final calendar = context.levit.find<LiveCalendarController>();
      calendar.sessions.value;
      calendar.attendanceCompletionBySessionId.value;
      final focus = calendar.todayFocus;
      final current = focus.current;
      final next = focus.next;
      final completion = calendar.attendanceCompletionBySessionId.value;
      return _AccueilBody(
        currentTitle: current == null
            ? null
            : 'En cours · ${current.classLabel}',
        currentSubtitle: current == null
            ? null
            : '${current.subjectLabel} · ${formatClockRange(current.startsAt, current.endsAt)}',
        currentRoute: current == null ? null : '/session/${current.id}',
        nextTitle: next == null ? null : 'Prochaine · ${next.classLabel}',
        nextSubtitle: next == null
            ? null
            : '${next.subjectLabel} · ${formatClockRange(next.startsAt, next.endsAt)}',
        nextRoute: next == null ? null : '/session/${next.id}',
        tasks: controller.tasks,
        todaySessions: [
          for (final s in focus.todaySessions)
            _TodaySessionRow(
              title: s.classLabel,
              subtitle:
                  '${formatClockRange(s.startsAt, s.endsAt)} · ${s.subjectLabel}',
              badges: [
                if (s.kind == 'lesson' &&
                    !(completion[s.id]?.isComplete ?? false))
                  'Présences',
              ],
              route: '/session/${s.id}',
            ),
        ],
        onOpenAgenda: () {
          calendar.goToDate(DateTime.now());
          context.go('/calendar');
        },
      );
    });
  }
}

class _TodaySessionRow {
  const _TodaySessionRow({
    required this.title,
    required this.subtitle,
    required this.badges,
    required this.route,
  });

  final String title;
  final String subtitle;
  final List<String> badges;
  final String route;
}

class _AccueilBody extends StatelessWidget {
  const _AccueilBody({
    required this.tasks,
    required this.todaySessions,
    required this.onOpenAgenda,
    this.currentTitle,
    this.currentSubtitle,
    this.currentRoute,
    this.nextTitle,
    this.nextSubtitle,
    this.nextRoute,
  });

  final List<AccueilTask> tasks;
  final List<_TodaySessionRow> todaySessions;
  final VoidCallback onOpenAgenda;
  final String? currentTitle;
  final String? currentSubtitle;
  final String? currentRoute;
  final String? nextTitle;
  final String? nextSubtitle;
  final String? nextRoute;

  @override
  Widget build(BuildContext context) {
    final primary = tasks.isEmpty ? null : tasks.first;
    final remaining = tasks.length <= 1 ? 0 : tasks.length - 1;

    return AdaptiveContent(
      child: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          Text(
            formatFullDate(DateTime.now()),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: PrototypeSpacing.xl),
          if (primary != null) ...[
            const SectionHeader(title: 'À traiter'),
            const SizedBox(height: PrototypeSpacing.sm),
            AttentionCard(
              tone: switch (primary.kind) {
                'attendance' || 'logbook' => AttentionTone.important,
                'message' => AttentionTone.message,
                _ => AttentionTone.normal,
              },
              title: primary.title,
              subtitle: primary.subtitle,
              icon: switch (primary.kind) {
                'attendance' => Icons.how_to_reg_outlined,
                'logbook' => Icons.menu_book_outlined,
                'marks' => Icons.grade_outlined,
                'comments' => Icons.comment_outlined,
                'feedback' => Icons.campaign_outlined,
                _ => Icons.mail_outline,
              },
              onTap: () => context.go(primary.route),
            ),
            if (remaining > 0) ...[
              const SizedBox(height: PrototypeSpacing.sm),
              Text(
                remaining == 1
                    ? '1 autre élément à traiter'
                    : '$remaining autres éléments à traiter',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: PrototypeSpacing.md),
          ],
          const SectionHeader(title: 'Séances'),
          const SizedBox(height: PrototypeSpacing.sm),
          if (currentTitle != null)
            ListRow(
              title: currentTitle!,
              subtitle: currentSubtitle ?? '',
              leading: Icon(
                Icons.play_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              onTap: currentRoute == null
                  ? null
                  : () => context.go(currentRoute!),
              trailing: const Icon(Icons.chevron_right),
            )
          else if (nextTitle != null)
            ListRow(
              title: nextTitle!,
              subtitle: nextSubtitle ?? '',
              leading: const Icon(Icons.schedule),
              onTap: nextRoute == null ? null : () => context.go(nextRoute!),
              trailing: const Icon(Icons.chevron_right),
            )
          else
            const EmptyState(
              title: 'Aucune séance aujourd\'hui',
              message: 'Consultez l\'agenda pour la semaine.',
            ),
          const SizedBox(height: PrototypeSpacing.xl),
          SectionHeader(
            title: 'Aujourd\'hui',
            action: 'Agenda',
            onAction: onOpenAgenda,
          ),
          for (final s in todaySessions) ...[
            ListRow(
              title: s.title,
              subtitle: s.subtitle,
              badge: s.badges.join(' · '),
              onTap: () => context.go(s.route),
              trailing: const Icon(Icons.chevron_right),
            ),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
        ],
      ),
    );
  }
}

int _mockPriority(String kind) {
  return switch (kind) {
    'feedback' => 1,
    'attendance' => 2,
    'logbook' => 3,
    'marks' => 4,
    'comments' => 5,
    'message' => 6,
    _ => 9,
  };
}
