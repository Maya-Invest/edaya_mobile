import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';

class CalendarPage extends LScopedView<StoreBoundController> {
  const CalendarPage({super.key});

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final selectedId = GoRouterState.of(context).pathParameters['id'];

    return AdaptiveContent(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PrototypeSpacing.md,
              PrototypeSpacing.sm,
              PrototypeSpacing.md,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: store.selectedCalendarDate,
                    firstDate: DateTime(2018),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) store.selectCalendarDate(picked);
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(formatDate(store.selectedCalendarDate)),
              ),
            ),
          ),
          _WeekSelector(store: store),
          Expanded(
            child: store.selectedDaySessions.isEmpty
                ? const EmptyState(title: 'Aucune séance ce jour')
                : ListView.separated(
                    padding: const EdgeInsets.all(PrototypeSpacing.md),
                    itemCount: store.selectedDaySessions.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: PrototypeSpacing.xs),
                    itemBuilder: (context, i) {
                      final s = store.selectedDaySessions[i];
                      final selected = selectedId == s.id;
                      return ListRow(
                        title: '${s.classLabel} · ${s.subject}',
                        subtitle:
                            '${formatTimeRange(s.startHour, s.endHour)} · ${s.room}',
                        selected: selected,
                        badge: [
                          if (!s.attendanceComplete) 'Présences',
                          if (!s.logbookComplete) 'Cahier',
                        ].where((e) => e.isNotEmpty).join(' · '),
                        onTap: () => context.go('/session/${s.id}'),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: selected
                              ? PrototypeColors.primary
                              : PrototypeColors.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({required this.store});
  final MockStore store;

  static const _dayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PrototypeSpacing.md,
        vertical: PrototypeSpacing.sm,
      ),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => store.selectDay(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: store.selectedDayIndex == i
                          ? PrototypeColors.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _dayLabels[i],
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          '${store.dateForWeekDay(i).day}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: store.selectedDayIndex == i
                                    ? PrototypeColors.primary
                                    : null,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
