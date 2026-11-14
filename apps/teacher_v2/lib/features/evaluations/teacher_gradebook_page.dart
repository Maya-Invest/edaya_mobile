import '../../design/workspace_layout.dart';
import 'package:edaya_api_client/edaya_api_client.dart'
    show GeneratedSchoolClientEntities;
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
import 'marks_corrections_panel.dart';
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
    final period = DropdownButtonFormField<String>(
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
      onChanged: (id) {
        if (id != null) {
          ev.selectPeriod(id);
          context.replace('/evaluations');
        }
      },
    );
    final choice = DropdownButtonFormField<String>(
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
      onChanged: (id) {
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
    final c = controller;
    if (c.evaluation.value == null && c.isBusy.value) {
      return const Center(child: CircularProgressIndicator());
    }
    final rows = c.students.value;
    final submitted = c.marksStatus.value == 'submitted';
    final missing = rows
        .where(
          (r) =>
              r.score == null &&
              r.mentionId == null &&
              !['absent', 'exempt'].contains(r.designation),
        )
        .length;
    List<String> pending(LiveMarkRow row) => [
      for (final request in c.corrections.value.where(
        (p) => p['status'] == 'pending',
      ))
        for (final change in (request['changes'] as List).cast<Map>().where(
          (p) => p['resultId'] == row.resultId,
        ))
          'En attente d’approbation · ${proposalValue(c, change['proposed'] as Map)}',
    ];
    Future<void> corrections() async {
      await showWorkspaceEditor<Object?>(
        context: context,
        ownerUri: Uri(
          path: '/evaluations',
          queryParameters: {'assessment': evaluationId},
        ),
        title: 'Modifier les notes',
        builder: (_, close) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: MarksCorrectionsPanel(controller: c),
        ),
      );
      await c.load();
    }

    return Column(
      children: [
        if (c.errorMessage.value.isNotEmpty)
          TextButton(onPressed: c.load, child: Text(c.errorMessage.value)),
        Expanded(
          child: ListView(
            key: PageStorageKey(('marks', evaluationId)),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      submitted ? 'Notes officielles' : 'Brouillon',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dupliquer l’évaluation',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: c.evaluation.value == null
                        ? null
                        : () async {
                            try {
                              final source = await context.levit
                                  .find<SchoolClientFactory>()()
                                  .assessments
                                  .get(evaluationId);
                              if (!context.mounted) return;
                              await showWorkspaceEditor<Object?>(
                                context: context,
                                title: 'Dupliquer l’évaluation',
                                ownerUri: Uri(
                                  path: '/evaluations',
                                  queryParameters: {'assessment': evaluationId},
                                ),
                                builder: (_, close) =>
                                    EvaluationCreatePage(source: source),
                              );
                            } on Object {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Impossible de charger cette évaluation. Réessayez.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ],
              ),
              if (rows.isNotEmpty)
                const ComparisonHeading(['Élève', 'Résultat', 'Proposition']),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: ResponsiveRosterTile(
                      key: ValueKey('mark-${row.studentId}'),
                      cells: [
                        row.fullName,
                        submitted
                            ? 'Note officielle · ${markValue(row)}'
                            : row.syncState == MarkSyncState.pending
                            ? 'À envoyer'
                            : markValue(row),
                        pending(row).join('\n'),
                      ],
                      compact: ListTile(
                        title: Text(row.fullName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (submitted)
                              Text('Note officielle · ${markValue(row)}')
                            else
                              Text(
                                row.syncState == MarkSyncState.pending
                                    ? 'À envoyer'
                                    : markValue(row),
                              ),
                            for (final p in pending(row)) Text(p),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: c.writing.value || c.submitting.value
                            ? null
                            : () async {
                                if (submitted) {
                                  await corrections();
                                  return;
                                }
                                await showWorkspaceEditor<Object?>(
                                  context: context,
                                  title: row.fullName,
                                  ownerUri: Uri(
                                    path: '/evaluations',
                                    queryParameters: {
                                      'assessment': evaluationId,
                                    },
                                  ),
                                  builder: (_, close) => _MarkEditor(
                                    controller: c,
                                    row: row,
                                    close: close,
                                  ),
                                );
                              },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    submitted
                        ? 'Les modifications sont soumises à approbation.'
                        : '${rows.length - missing}/${rows.length} élèves renseignés${missing > 0 ? ' · $missing à compléter' : ''}',
                  ),
                  if (c.saveMessage.value.isNotEmpty) Text(c.saveMessage.value),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed:
                        c.writing.value || c.submitting.value || rows.isEmpty
                        ? null
                        : submitted
                        ? (c.canRequestCorrection.value ||
                                  c.corrections.value.isNotEmpty
                              ? corrections
                              : null)
                        : missing == 0
                        ? c.submitMarks
                        : null,
                    child: const Text('Soumettre les notes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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

class _MarkEditor extends StatefulWidget {
  const _MarkEditor({
    required this.controller,
    required this.row,
    required this.close,
  });
  final LiveMarksController controller;
  final LiveMarkRow row;
  final ValueChanged<Object?> close;
  @override
  State<_MarkEditor> createState() => _MarkEditorState();
}

class _MarkEditorState extends State<_MarkEditor> {
  late final score = TextEditingController(
    text: widget.row.score?.toString() ?? '',
  );
  late String designation = widget.row.designation ?? 'scored';
  late String? mention = widget.row.mentionId;
  bool dirty = false, busy = false;
  @override
  void dispose() {
    score.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !busy,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop ||
          busy ||
          !dirty ||
          !await confirmWorkspaceDiscard(context) ||
          !mounted) {
        return;
      }
      setState(() => dirty = false);
      await WidgetsBinding.instance.endOfFrame;
      widget.close(null);
    },
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: designation,
          decoration: const InputDecoration(labelText: 'Résultat'),
          items: const [
            DropdownMenuItem(value: 'scored', child: Text('Note')),
            DropdownMenuItem(value: 'absent', child: Text('Absent')),
            DropdownMenuItem(value: 'exempt', child: Text('Dispensé')),
          ],
          onChanged: busy
              ? null
              : (v) => setState(() {
                  designation = v!;
                  dirty = true;
                }),
        ),
        const SizedBox(height: 16),
        if (designation == 'scored')
          widget.controller.mentionFirst
              ? DropdownButtonFormField<String>(
                  initialValue: mention,
                  decoration: const InputDecoration(labelText: 'Mention'),
                  items: [
                    for (final m in widget.controller.mentions)
                      DropdownMenuItem(
                        value: m['id'] as String,
                        child: Text('${m['letter']} · ${m['interpretation']}'),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          mention = v;
                          dirty = true;
                        }),
                )
              : TextField(
                  controller: score,
                  enabled: !busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        'Note / ${widget.controller.evaluation.value?.maxScore ?? 20}',
                  ),
                  onChanged: (_) => setState(() => dirty = true),
                ),
        LWatch(() => Text(widget.controller.saveMessage.value)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy || !dirty
              ? null
              : () async {
                  setState(() => busy = true);
                  final c = widget.controller;
                  if (designation == 'scored' && !c.mentionFirst) {
                    await c.saveScoreText(widget.row.studentId, score.text);
                  } else {
                    await c.saveScore(
                      widget.row.studentId,
                      null,
                      designation: designation,
                      mentionId: mention,
                    );
                  }
                  if (!mounted) return;
                  final saved = c.students.value
                      .where((r) => r.studentId == widget.row.studentId)
                      .firstOrNull;
                  final ok =
                      saved != null &&
                      saved.syncState != MarkSyncState.failed &&
                      (designation == 'scored'
                          ? c.mentionFirst
                                ? saved.mentionId == mention && mention != null
                                : saved.score ==
                                          double.tryParse(
                                            score.text.replaceAll(',', '.'),
                                          ) &&
                                      saved.score != null
                          : saved.designation == designation);
                  setState(() {
                    busy = false;
                    if (ok) dirty = false;
                  });
                  if (ok) {
                    await WidgetsBinding.instance.endOfFrame;
                    widget.close(null);
                  }
                },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}
