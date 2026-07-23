import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';

class HomePage extends LScopedView<StoreBoundController> {
  const HomePage({super.key});

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final current = store.currentSession;
    final next = store.nextSession;
    final tasks = store.todayTasks;

    return AdaptiveContent(
      child: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          Text(
            formatFullDate(DateTime.now()),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: PrototypeSpacing.xl),
          if (tasks.isNotEmpty) ...[
            const SectionHeader(title: 'À traiter'),
            const SizedBox(height: PrototypeSpacing.sm),
            for (final task in tasks) ...[
              AttentionCard(
                tone: switch (task.kind) {
                  'attendance' || 'logbook' => AttentionTone.important,
                  'message' => AttentionTone.message,
                  _ => AttentionTone.normal,
                },
                title: task.title,
                subtitle: task.subtitle,
                icon: switch (task.kind) {
                  'attendance' => Icons.how_to_reg_outlined,
                  'logbook' => Icons.menu_book_outlined,
                  'marks' => Icons.grade_outlined,
                  'comments' => Icons.comment_outlined,
                  _ => Icons.mail_outline,
                },
                onTap: () => context.go(task.route),
              ),
              const SizedBox(height: PrototypeSpacing.sm),
            ],
            const SizedBox(height: PrototypeSpacing.md),
          ],
          const SectionHeader(title: 'Séances'),
          const SizedBox(height: PrototypeSpacing.sm),
          if (current != null)
            ListRow(
              title: 'En cours · ${current.classLabel}',
              subtitle:
                  '${current.subject} · ${formatTimeRange(current.startHour, current.endHour)}',
              leading: Icon(Icons.play_circle_outline, color: PrototypeColors.primary),
              onTap: () => context.go('/session/${current.id}'),
              trailing: const Icon(Icons.chevron_right),
            )
          else if (next != null)
            ListRow(
              title: 'Prochaine · ${next.classLabel}',
              subtitle:
                  '${next.subject} · ${formatTimeRange(next.startHour, next.endHour)}',
              leading: const Icon(Icons.schedule),
              onTap: () => context.go('/session/${next.id}'),
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
            onAction: () {
              store.openCalendarDay(0);
              context.go('/calendar');
            },
          ),
          for (final s in store.sessionsForDay(DateTime.now())) ...[
            ListRow(
              title: s.classLabel,
              subtitle:
                  '${formatTimeRange(s.startHour, s.endHour)} · ${s.room}',
              badge: [
                if (!s.attendanceComplete) 'Présences',
                if (!s.logbookComplete) 'Cahier',
              ].join(' · '),
              onTap: () => context.go('/session/${s.id}'),
              trailing: const Icon(Icons.chevron_right),
            ),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
        ],
      ),
    );
  }
}
