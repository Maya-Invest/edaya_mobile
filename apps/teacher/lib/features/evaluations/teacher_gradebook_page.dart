import '../../design/workspace_layout.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../app/workspace_navigation.dart';
import '../../design/components/surface_card.dart';
import '../../design/spacing.dart';
import '../../live/entity_queries.dart';
import '../context/teacher_context_controller.dart';
import '../context/academic_year_controller.dart';
import 'live_evaluations_controller.dart';
import 'live_marks_controller.dart';
import 'gradebook_marks_view.dart';
import 'teacher_gradebook_controller.dart';
import 'evaluations_page.dart';

class TeacherGradebookPage extends LScopedView<TeacherGradebookController> {
  const TeacherGradebookPage({super.key, this.initialAssessmentId});
  final String? initialAssessmentId;
  @override
  TeacherGradebookController onConfigScope(LevitScope scope) => scope.put(
    () => TeacherGradebookController(
      scope.find<TeacherContextController>(),
      scope.find<LiveEvaluationsController>(),
      scope.find<SchoolClientFactory>(),
      scope,
      initialAssessmentId: initialAssessmentId,
    ),
  );
  @override
  Widget buildView(
    BuildContext context,
    TeacherGradebookController controller,
  ) {
    final c = controller;
    final ev = c.evaluations;
    final selected = initialAssessmentId;
    final active = c.teacher.activeAssignment;
    final evaluations = [...ev.evaluations.value]
      ..sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));
    if (selected != null && c.assessmentError.value.isNotEmpty) {
      return Center(
        child: TextButton(
          onPressed: () => context.replace('/evaluations'),
          child: Text('${c.assessmentError.value} Retour aux résultats.'),
        ),
      );
    }
    if (selected != null && !evaluations.any((e) => e.id == selected)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (active?.classSubjectId == null) {
      return const Center(child: Text('Aucun enseignement sélectionné.'));
    }
    final period = _GradebookPicker(
      key: ValueKey(('period', ev.selectedPeriodId.value)),
      initialValue:
          ev.periods.value.any((p) => p['id'] == ev.selectedPeriodId.value)
          ? ev.selectedPeriodId.value
          : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Période'),
      items: [
        for (final p in ev.periods.value)
          DropdownMenuItem(
            value: p['id'] as String,
            child: Text(
              academicPeriodLabel(p),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) async {
        if (!await prepareWorkspaceChange(context) || !context.mounted) return;
        if (id != null) {
          ev.selectPeriod(id);
          context.replace('/evaluations');
        }
      },
    );
    final choice = _GradebookPicker(
      key: ValueKey(('evaluation', selected)),
      initialValue: evaluations.any((e) => e.id == selected)
          ? selected
          : 'average',
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Résultats'),
      items: [
        const DropdownMenuItem(
          value: 'average',
          child: Text('Moyenne de la période', overflow: TextOverflow.ellipsis),
        ),
        for (final e in evaluations)
          DropdownMenuItem(
            value: e.id,
            child: Text(e.title, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) async {
        if (!await prepareWorkspaceChange(context) || !context.mounted) return;
        ev.selectedEvaluationId(id == 'average' ? null : id);
        context.replace(
          id == 'average' ? '/evaluations' : '/evaluations?assessment=$id',
        );
        if (id == 'average') c.load();
      },
    );
    final add = IconButton.filled(
      tooltip: 'Nouvelle évaluation',
      icon: const Icon(Icons.add),
      onPressed: ev.selectedPeriodId.value == null
          ? null
          : () async {
              if (!await prepareWorkspaceChange(context) || !context.mounted) {
                return;
              }
              await context.push('/evaluations/create');
              await c.load();
            },
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          child: LayoutBuilder(
            builder: (context, box) {
              if (MediaQuery.textScalerOf(context).scale(14) > 22) {
                return Column(
                  children: [
                    period,
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: choice),
                        add,
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: period),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: choice),
                  const SizedBox(width: 4),
                  add,
                ],
              );
            },
          ),
        ),
        if (ev.errorMessage.value.isNotEmpty)
          TextButton(onPressed: ev.reload, child: Text(ev.errorMessage.value)),
        Expanded(
          child: selected != null && evaluations.any((e) => e.id == selected)
              ? EvaluationMarksPane(
                  key: ValueKey((active!.id, selected)),
                  evaluationId: selected,
                )
              : _AverageRows(controller: c),
        ),
      ],
    );
  }
}

class _AverageRows extends StatelessWidget {
  const _AverageRows({required this.controller});
  final TeacherGradebookController controller;
  @override
  Widget build(BuildContext context) => LWatch(() {
    final c = controller;
    if (c.loading.value) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.error.value.isNotEmpty) {
      return Center(
        child: TextButton(onPressed: c.load, child: Text(c.error.value)),
      );
    }
    final stackResult = MediaQuery.textScalerOf(context).scale(14) > 22;
    String result(Map<String, dynamic> row) => formatCalculatedGrade(
      (row['average'] as num?)?.toDouble(),
      (row['grading'] as Map?)?.cast<String, dynamic>(),
    );
    String appreciation(Map row) => row['comment'] == null
        ? 'Bulletin non préparé'
        : (row['comment'] as Map)['proposal'] != null
        ? ((row['comment'] as Map)['proposal'] as Map)['status'] ==
                  'approved_pending_publication'
              ? 'Approuvée · En attente de publication'
              : 'En attente d’approbation'
        : ((row['comment'] as Map)['text'] as String).isEmpty
        ? 'Appréciation à compléter'
        : 'Appréciation renseignée';
    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        key: PageStorageKey((
          'averages',
          c.teacher.activeAssignmentId.value,
          c.evaluations.selectedPeriodId.value,
        )),
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          if (c.students.value.isNotEmpty)
            const ComparisonHeading(['Élève', 'Moyenne', 'Appréciation']),
          if (c.students.value.isEmpty)
            const Text('Aucun élève inscrit à cet enseignement.'),
          for (final row in c.students.value)
            Padding(
              padding: const EdgeInsets.only(bottom: PrototypeSpacing.xs),
              child: SurfaceCard(
                padding: EdgeInsets.zero,
                child: ResponsiveRosterTile(
                  cells: [
                    '${row['lastName']} ${row['firstName']}',
                    result(row),
                    appreciation(row),
                  ],
                  compact: ListTile(
                    title: Text('${row['lastName']} ${row['firstName']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (stackResult) Text(result(row)),
                        Text(appreciation(row)),
                      ],
                    ),
                    trailing: stackResult ? null : Text(result(row)),
                    onTap: () async {
                      await showWorkspaceEditor<Object?>(
                        context: context,
                        wide: true,
                        title: '${row['lastName']} ${row['firstName']}',
                        builder: (_, close) =>
                            _SubjectSummary(row: row, controller: c),
                      );
                      await c.load();
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  });
}

class _SubjectSummary extends StatelessWidget {
  const _SubjectSummary({required this.row, required this.controller});
  final Map<String, dynamic> row;
  final TeacherGradebookController controller;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Moyenne de la période',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(
        formatCalculatedGrade(
          (row['average'] as num?)?.toDouble(),
          (row['grading'] as Map?)?.cast<String, dynamic>(),
        ),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      WorkspaceColumns(
        first: [
          for (final result in (row['contributions'] as List).cast<Map>())
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(result['title'] as String),
              subtitle: Text('Coefficient ${result['coefficient']}'),
              trailing: Text(
                result['designation'] == 'absent'
                    ? 'Absent'
                    : result['designation'] == 'exempt'
                    ? 'Dispensé'
                    : '${result['score'] ?? '—'} / ${result['maxScore']}',
              ),
            ),
          const SizedBox(height: 16),
        ],
        second: [
          if (row['comment'] == null)
            const Text(
              'L’appréciation sera disponible lorsque l’établissement aura préparé le bulletin.',
            )
          else ...[
            Text(
              'Appréciation de la matière',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text((row['comment'] as Map)['text'] as String),
            if ((row['comment'] as Map)['proposal'] case final Map proposal)
              Text(
                '${proposal['status'] == 'approved_pending_publication' ? 'Approuvée · En attente de publication' : 'En attente d’approbation'} · ${proposal['text']}',
              ),
            FilledButton(
              onPressed: () => showWorkspaceEditor<Object?>(
                context: context,
                title: 'Appréciation',
                builder: (_, close) => ReportCardCommentPage(
                  classId: controller.teacher.activeAssignment!.classGroupId,
                  periodId: controller.evaluations.selectedPeriodId.value!,
                  rosterId: row['studentId'] as String,
                  subjectId:
                      controller.teacher.activeAssignment!.classSubjectId,
                ),
              ),
              child: Text(
                (row['comment'] as Map)['proposal']?['status'] ==
                        'approved_pending_publication'
                    ? 'Consulter l’appréciation'
                    : 'Modifier l’appréciation',
              ),
            ),
          ],
        ],
      ),
    ],
  );
}

class EvaluationMarksPane extends LScopedView<LiveMarksController> {
  const EvaluationMarksPane({super.key, required this.evaluationId});
  final String evaluationId;
  @override
  LiveMarksController onConfigScope(LevitScope scope) => scope.put(
    () => LiveMarksController(
      evaluationId: evaluationId,
      evaluations: scope.find<LiveEvaluationsController>(),
      academicYear: scope.find<AcademicYearController>(),
      teacherContext: scope.find<TeacherContextController>(),
      schoolClient: scope.find<SchoolClientFactory>(),
      outboxStore: scope.find<TeacherOutboxStore>(),
      outboxContext: () => teacherOutboxContextForSession(
        session: scope.find<AppSessionController>(),
        academicYearId: scope
            .find<AcademicYearController>()
            .selectedYearId
            .value,
      ),
    ),
  );
  @override
  Widget buildView(BuildContext context, LiveMarksController controller) {
    return GradebookMarksView(controller: controller);
  }
}

String markValue(LiveMarkRow row) => row.designation == 'absent'
    ? 'Absent'
    : row.designation == 'exempt'
    ? 'Dispensé'
    : row.mentionCode ?? row.score?.toString() ?? 'À compléter';
String proposalValue(LiveMarksController c, Map row) =>
    row['designation'] == 'absent'
    ? 'Absent'
    : row['designation'] == 'exempt'
    ? 'Dispensé'
    : row['mentionId'] != null
    ? c.mentionLabel(row['mentionId'] as String)
    : '${row['score'] ?? '—'}';

/// Restore the displayed selection while an unsaved-edit prompt is pending.
class _GradebookPicker extends StatefulWidget {
  const _GradebookPicker({
    super.key,
    required this.initialValue,
    required this.isExpanded,
    required this.decoration,
    required this.items,
    required this.onChanged,
  });
  final String? initialValue;
  final bool isExpanded;
  final InputDecoration decoration;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  @override
  State<_GradebookPicker> createState() => _GradebookPickerState();
}

class _GradebookPickerState extends State<_GradebookPicker> {
  final field = GlobalKey<FormFieldState<String>>();
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: field,
    initialValue: widget.initialValue,
    isExpanded: widget.isExpanded,
    decoration: widget.decoration,
    items: widget.items,
    onChanged: (value) {
      if (value == widget.initialValue) return;
      field.currentState?.didChange(widget.initialValue);
      widget.onChanged(value);
    },
  );
}
