import '../teaching/teaching_models.dart';
import '../../design/workspace_layout.dart';
import '../evaluations/evaluations_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:edaya_shared/edaya_shared.dart';
import '../context/teacher_context_controller.dart';
import '../evaluations/live_evaluations_controller.dart';
import '../teaching/live_class_workspace_controller.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../../app/formatters.dart';
import 'teacher_discipline_page.dart';

class ClassSections extends StatelessWidget {
  const ClassSections({super.key, required this.builder});
  final Widget Function(AssignedClass) builder;

  @override
  Widget build(BuildContext context) {
    if (!prototypeIsLive(context)) {
      return Center(child: Text(context.tr.chooseAClass));
    }
    final scope = context.levit.find<TeacherContextController>();
    return LWatch(() {
      final classes = scope.assignedClasses.value;
      final selected = classes
          .where((c) => c.id == scope.activeAssignment?.classGroupId)
          .firstOrNull;
      if (selected != null) return builder(selected);
      if (scope.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Text(
          scope.errorMessage.value.isEmpty
              ? context.tr.noAssignedClasses
              : scope.errorMessage.value,
        ),
      );
    });
  }
}

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});
  @override
  Widget build(BuildContext context) => ClassSections(
    builder: (c) => _Progress(
      key: ValueKey(
        context.levit.find<TeacherContextController>().activeAssignmentId.value,
      ),
      id: c.id,
    ),
  );
}

class _Progress extends LScopedView<LiveClassWorkspaceController> {
  const _Progress({super.key, required this.id});
  final String id;
  @override
  LiveClassWorkspaceController onConfigScope(LevitScope scope) => scope.put(
    () => LiveClassWorkspaceController(
      classGroupId: id,
      teacherContext: scope.find<TeacherContextController>(),
      schoolClient: scope.find<SchoolClientFactory>(),
    ),
  );
  @override
  Widget buildView(BuildContext context, LiveClassWorkspaceController c) {
    final entries = c.logbookEntries.value
        .where((entry) => entry.hasContent || entry.matterSnapshots.isNotEmpty)
        .toList();
    return Column(
      children: [
        if (c.isBusy.value) const LinearProgressIndicator(),
        if (c.errorMessage.value.isNotEmpty)
          ListTile(
            title: Text(c.errorMessage.value),
            trailing: TextButton(
              onPressed: c.load,
              child: Text(context.tr.retry),
            ),
          ),

        Expanded(
          child: WorkspaceTabs(
            values: const ['chapters', 'logbook'],
            labels: [context.tr.workspaceChapters, context.tr.logbook],
            children: [
              ListView(
                key: PageStorageKey(('chapters', id)),
                padding: const EdgeInsets.all(16),
                children: [
                  if (c.progressOverview.value case final overview?)
                    Text(
                      overview.chapterCount == 0
                          ? context.tr.logbookEmptyCurriculum
                          : '${overview.classSubjectCompletedPercentage}% · ${context.tr.logbookChapterCounts(overview.completedChapterCount, overview.chapterCount, overview.ongoingChapterCount)}',
                    ),
                  for (final m
                      in c.progressOverview.value?.matters ??
                          const <TeachingMatterProgress>[])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(m.name),
                      trailing: Text(switch (m.status) {
                        TeachingMatterStatus.completed =>
                          context.tr.matterStatusCompleted,
                        TeachingMatterStatus.inProgress =>
                          context.tr.matterStatusInProgress,
                        TeachingMatterStatus.notStarted =>
                          context.tr.matterStatusNotStarted,
                      }),
                    ),
                ],
              ),
              ListView(
                key: PageStorageKey(('logbook', id)),
                padding: const EdgeInsets.all(16),
                children: [
                  if (entries.isEmpty && !c.isBusy.value)
                    ListTile(contentPadding: EdgeInsets.zero, title: Text(context.tr.noCompletedLogbook)),
                  for (final l in entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.displayLabel),
                      subtitle: Text(
                        '${formatDate(l.startsAt)} · ${context.tr.logbookCompleted}',
                      ),
                      onTap: () => context.push(
                        '/session/${l.lessonSessionId}?tab=logbook',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BulletinsPage extends StatelessWidget {
  const BulletinsPage({super.key});
  @override
  Widget build(BuildContext context) {
    if (!prototypeIsLive(context)) {
      final reports = context.levit.find<MockStore>().reportCardClasses;
      if (reports.isEmpty) {
        return Center(child: Text(context.tr.noReportCardsPrepared));
      }
      return ReportCardRosterPage(
        classId: reports.first.classId,
        periodId: reports.first.periodId,
      );
    }
    final ev = context.levit.find<LiveEvaluationsController>();
    final tc = context.levit.find<TeacherContextController>();
    return LWatch(() {
      final active = tc.activeAssignment;
      if (active?.isHomeroom != true) {
        return Center(
          child: Text(context.tr.reportCardsAreAvailableToTheHomeroomTeacher),
        );
      }
      final periodId = ev.selectedPeriodId.value;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              key: ValueKey(periodId),
              initialValue: periodId,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.tr.periodFallback),
              items: [
                for (final p in ev.periods.value)
                  DropdownMenuItem(
                    value: p['id'] as String,
                    child: Text(p['name'] as String),
                  ),
              ],
              onChanged: (id) {
                if (id != null) ev.selectPeriod(id);
              },
            ),
          ),
          if (periodId != null)
            Expanded(
              child: ReportCardRosterPage(
                key: ValueKey((active!.classGroupId, periodId)),
                classId: active.classGroupId,
                periodId: periodId,
              ),
            ),
        ],
      );
    });
  }
}

class IncidentsPage extends StatelessWidget {
  const IncidentsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final action = FeatureAction(
      context.tr.reportAnIncident,
      Icons.add,
      () => context.push('/incidents/new'),
    );
    return FeatureActionPanel(
      actions: [action],
      child: ListView(
        children: [
          if (!phoneActions(context))
            TextButton.icon(
              onPressed: action.run,
              icon: Icon(action.icon),
              label: Text(action.label),
            ),
          ClassSections(
            builder: (c) => IncidentGroup(key: ValueKey(c.id), id: c.id),
          ),
        ],
      ),
    );
  }
}

class IncidentGroup extends LScopedView<TeacherDisciplineController> {
  const IncidentGroup({super.key, required this.id});
  final String id;
  @override
  TeacherDisciplineController onConfigScope(LevitScope scope) => scope.put(
    () => TeacherDisciplineController(
      classId: id,
      client: scope.find<SchoolClientFactory>(),
      teacherId: scope.find<TeacherContextController>().teacherId.value,
      outbox: scope.find<TeacherOutboxStore>(),
    ),
  );
  @override
  Widget buildView(
    BuildContext context,
    TeacherDisciplineController controller,
  ) {
    return Column(
      children: [
        if (controller.busy.value) const LinearProgressIndicator(),
        if (controller.message.value.isNotEmpty) Text(controller.message.value),
        if (controller.incidents.value.isEmpty && !controller.busy.value)
          ListTile(title: Text(context.tr.noIncidents)),
        if (controller.incidents.value.isNotEmpty)
          ComparisonHeading([context.tr.incident, 'Date', context.tr.status]),
        for (final row in controller.incidents.value)
          LayoutBuilder(
            builder: (context, box) {
              Future<void> open() async {
                await context.push('/incidents/$id/${row['id']}');
                if (context.mounted) await controller.load();
              }

              final date = DateTime.tryParse('${row['date']}');
              final status = switch (row['status']) {
                'resolved' => context.tr.messagingResolved,
                'cancelled' => context.tr.feeStatusCancelled,
                'open' when (row['eligibility'] as Map?)?['locked'] == true =>
                  context.tr.workflowIncidentTakenOver,
                'open' => context.tr.familyFeedbackSlotOpen,
                _ => '—',
              };
              return useComparisonRows(context, box.maxWidth)
                  ? ComparisonRow(
                      cells: [
                        row['title'] as String,
                        date == null ? '—' : formatDate(date),
                        status,
                      ],
                      onTap: open,
                    )
                  : ListTile(
                      title: Text(row['title'] as String),
                      subtitle: Text(row['description'] as String? ?? ''),
                      onTap: open,
                    );
            },
          ),
      ],
    );
  }
}
