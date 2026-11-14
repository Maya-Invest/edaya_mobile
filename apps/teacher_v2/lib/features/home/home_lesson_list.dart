import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../app/formatters.dart';
import '../../design/components/surface_card.dart';
import '../../design/spacing.dart';
import '../calendar/teacher_session.dart';
import 'home_timetable_controller.dart';

class HomeLessonList extends LScopedView<HomeTimetableController> {
  const HomeLessonList({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.classLabel,
    required this.subjectId,
    required this.location,
  });
  final String teacherId, classId, classLabel;
  final String? subjectId;
  final tz.Location location;

  @override
  HomeTimetableController onConfigScope(LevitScope scope) {
    final client = scope.find<SchoolClientFactory>();
    return scope.put(
      () => HomeTimetableController(
        classId: classId,
        schoolNow: () => tz.TZDateTime.now(location),
        read: (range) async {
          final events = await fetchTeacherTimetableOccurrences(
            client(),
            teacherId,
            range: range,
          );
          return [
            for (final e in events)
              if (e.classGroupId == classId &&
                  e.classSubjectId == subjectId &&
                  e.kind == 'lesson')
                TeacherSession.fromOccurrence(e, classLabel: classLabel),
          ];
        },
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, HomeTimetableController controller) =>
      _Preview(controller: controller);
}

class _Preview extends StatefulWidget {
  const _Preview({required this.controller});
  final HomeTimetableController controller;
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> with WidgetsBindingObserver {
  bool routeVisible = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeVisible =
        ModalRoute.isCurrentOf(context) != false &&
        TickerMode.valuesOf(context).enabled;
    _syncVisibility(WidgetsBinding.instance.lifecycleState);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _syncVisibility(state);
  void _syncVisibility(AppLifecycleState? state) {
    widget.controller.setVisible(
      routeVisible && (state == null || state == AppLifecycleState.resumed),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.setVisible(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LWatch(() {
    final c = widget.controller;
    final lessons = c.preview;
    final now = c.clock.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.failed.value)
          TextButton.icon(
            onPressed: c.refresh,
            icon: const Icon(Icons.refresh),
            label: Text(context.tr.retry),
          ),
        if (c.entries.value == null && !c.failed.value)
          const LinearProgressIndicator(),
        if (c.entries.value != null && lessons.isEmpty) ...[
          Text(
            context.tr.teacherNoUpcomingSessions,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: PrototypeSpacing.xxs),
          Text(
            context.tr.teacherSessionsAgendaHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        for (final s in lessons)
          Padding(
            key: ValueKey(s.id),
            padding: const EdgeInsets.only(bottom: PrototypeSpacing.xs),
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                key: ValueKey('home-lesson-${s.id}'),
                title: Text('${s.classLabel} · ${s.subjectLabel}'),
                subtitle: Text(
                  '${s.startsAt.isAfter(now) ? context.tr.calendarNextSession : context.tr.calendarCurrentSession} · ${formatClockRange(tz.TZDateTime.from(s.startsAt, now.location), tz.TZDateTime.from(s.endsAt, now.location))}',
                ),
                onTap: () => context.push('/session/${s.id}'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
      ],
    );
  });
}
