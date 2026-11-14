import '../../design/workspace_layout.dart';
import '../../live/entity_queries.dart' show academicPeriodLabel;
import '../../app/workspace_navigation.dart';
import 'teacher_gradebook_page.dart';
import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/academic_year_controller.dart';
import '../context/store_bound_controller.dart';
import '../context/teacher_context_controller.dart';
import '../report_cards/live_report_cards_controller.dart';
import '../report_cards/report_card_comment_logic.dart';
import 'live_evaluations_controller.dart';
import 'live_marks_controller.dart';
import 'marks_corrections_panel.dart';

class EvaluationsPage extends StatelessWidget {
  const EvaluationsPage({super.key, this.assessmentId});
  final String? assessmentId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      final id = assessmentId;
      return TeacherGradebookPage(key: ValueKey(id), initialAssessmentId: id);
    }
    return const _MockEvaluationsPage();
  }
}

class _MockEvaluationsPage extends LScopedView<StoreBoundController> {
  const _MockEvaluationsPage();

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;

    return AdaptiveContent(
      child: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          const SectionHeader(title: 'Évaluations'),
          const SizedBox(height: PrototypeSpacing.sm),
          for (final e in store.evaluations) ...[
            ListRow(
              title: e.title,
              subtitle:
                  '${e.classLabel} · ${e.period} · ${e.gradedCount}/${e.totalCount} notés',
              badge: e.needsMarks ? 'À saisir' : 'Complet',
              badgeTone: e.needsMarks
                  ? SemanticTone.warning
                  : SemanticTone.info,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/evaluations/${e.id}/marks'),
            ),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
          const SizedBox(height: PrototypeSpacing.xl),
          const SectionHeader(title: 'Avis des familles'),
          const SizedBox(height: PrototypeSpacing.sm),
          ListRow(
            title: 'Campagnes et archives',
            subtitle: 'Nouveaux retours depuis Accueil, historique ici',
            leading: Icon(
              Icons.campaign_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/evaluations/avis'),
          ),
          const SizedBox(height: PrototypeSpacing.xl),
          const SectionHeader(title: 'Bulletins'),
          const SizedBox(height: PrototypeSpacing.sm),
          for (final rc in store.reportCardClasses) ...[
            ListRow(
              title: '${rc.classLabel} · ${rc.period}',
              subtitle: '${rc.pendingComments} commentaires en attente',
              leading: Icon(
                Icons.description_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(
                '/evaluations/report-cards/${rc.classId}/${rc.periodId}',
              ),
            ),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class MarksEntryPage extends StatelessWidget {
  const MarksEntryPage({super.key, required this.evaluationId});

  final String evaluationId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveMarksEntryPage(evaluationId: evaluationId);
    }
    return _MockMarksEntryPage(evaluationId: evaluationId);
  }
}

class _MockMarksEntryPage extends LScopedView<StoreBoundController> {
  const _MockMarksEntryPage({required this.evaluationId});

  final String evaluationId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final evaluation = store.evaluationById(evaluationId);
    if (evaluation == null) {
      return const PrototypeDetailScaffold(
        title: 'Notes',
        body: EmptyState(title: 'Évaluation introuvable'),
      );
    }

    final marks = store.marksFor(evaluationId);

    return PrototypeDetailScaffold(
      title: evaluation.title,
      fallbackRoute: '/evaluations',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          Text(
            '${evaluation.classLabel} · max ${evaluation.maxScore.toInt()} · coeff ${evaluation.coefficient}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text('Échéance · ${formatDate(evaluation.dueDate)}'),
          const SizedBox(height: PrototypeSpacing.md),
          for (final mark in marks) ...[
            Builder(
              builder: (context) {
                final student = store.studentById(mark.studentId);
                if (student == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: PrototypeSpacing.xs),
                  child: SurfaceCard(
                    child: Row(
                      children: [
                        PersonAvatar(initials: student.initials, radius: 18),
                        const SizedBox(width: PrototypeSpacing.sm),
                        Expanded(child: Text(student.fullName)),
                        SizedBox(
                          width: 72,
                          child: TextFormField(
                            initialValue: mark.score?.toString() ?? '',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              hintText: '—',
                            ),
                            onChanged: (value) {
                              final parsed = double.tryParse(value);
                              store.setMark(evaluationId, student.id, parsed);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class ReportCardRosterPage extends StatelessWidget {
  const ReportCardRosterPage({
    super.key,
    required this.classId,
    required this.periodId,
  });

  final String classId;
  final String periodId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveReportCardRosterPage(classId: classId, periodId: periodId);
    }
    return _MockReportCardRosterPage(classId: classId, periodId: periodId);
  }
}

class _MockReportCardRosterPage extends LScopedView<StoreBoundController> {
  const _MockReportCardRosterPage({
    required this.classId,
    required this.periodId,
  });

  final String classId;
  final String periodId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final roster = store.rosterFor(classId, periodId);
    final label =
        store.reportCardClasses
            .where((c) => c.classId == classId && c.periodId == periodId)
            .firstOrNull
            ?.classLabel ??
        classId;

    return PrototypeDetailScaffold(
      title: 'Bulletin · $label',
      fallbackRoute: '/evaluations',
      body: ListView.separated(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        itemCount: roster.length,
        separatorBuilder: (_, _) => const SizedBox(height: PrototypeSpacing.xs),
        itemBuilder: (context, i) {
          final row = roster[i];
          final pending = !row.hasHomeroomComment && !row.hasSubjectComment;
          return ListRow(
            title: row.studentName,
            subtitle:
                'Moy. ${row.average.toStringAsFixed(2)} · Rang ${row.rank}',
            badge: pending ? 'Commentaire' : 'OK',
            badgeTone: pending ? SemanticTone.warning : SemanticTone.info,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(
              '/evaluations/report-cards/$classId/$periodId/${row.id}',
            ),
          );
        },
      ),
    );
  }
}

class ReportCardCommentPage extends StatelessWidget {
  const ReportCardCommentPage({
    super.key,
    required this.classId,
    required this.periodId,
    required this.rosterId,
    this.subjectId,
  });

  final String classId;
  final String periodId;
  final String rosterId;
  final String? subjectId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveReportCardCommentPage(
        classId: classId,
        periodId: periodId,
        studentId: rosterId,
        subjectId: subjectId,
      );
    }
    return _MockReportCardCommentPage(
      classId: classId,
      periodId: periodId,
      rosterId: rosterId,
    );
  }
}

class _MockReportCardCommentPage extends LScopedView<StoreBoundController> {
  const _MockReportCardCommentPage({
    required this.classId,
    required this.periodId,
    required this.rosterId,
  });

  final String classId;
  final String periodId;
  final String rosterId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final row = controller.store.reportCardStudentById(rosterId);
    if (row == null) {
      return const PrototypeDetailScaffold(
        title: 'Commentaire',
        body: EmptyState(title: 'Élève introuvable'),
      );
    }

    return _CommentForm(
      classId: classId,
      periodId: periodId,
      row: row,
      onSave: (homeroom, subject) {
        controller.store.saveComment(
          rosterId: rosterId,
          homeroomComment: homeroom,
          subjectComment: subject,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Commentaire enregistré')));
      },
    );
  }
}

class _CommentForm extends StatefulWidget {
  const _CommentForm({
    required this.classId,
    required this.periodId,
    required this.row,
    required this.onSave,
  });

  final String classId;
  final String periodId;
  final MockReportCardStudent row;
  final void Function(String homeroom, String subject) onSave;

  @override
  State<_CommentForm> createState() => _CommentFormState();
}

class _CommentFormState extends State<_CommentForm> {
  late final TextEditingController _homeroom;
  late final TextEditingController _subject;

  @override
  void initState() {
    super.initState();
    _homeroom = TextEditingController(text: widget.row.homeroomComment);
    _subject = TextEditingController(text: widget.row.subjectComment);
  }

  @override
  void dispose() {
    _homeroom.dispose();
    _subject.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrototypeDetailScaffold(
      title: widget.row.studentName,
      fallbackRoute:
          '/evaluations/report-cards/${widget.classId}/${widget.periodId}',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          Text(
            'Moyenne ${widget.row.average.toStringAsFixed(2)} · Rang ${widget.row.rank}',
          ),
          const SizedBox(height: PrototypeSpacing.md),
          TextField(
            controller: _homeroom,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Commentaire titulaire',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          TextField(
            controller: _subject,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Commentaire matière',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PrototypeSpacing.lg),
          FilledButton(
            onPressed: () => widget.onSave(_homeroom.text, _subject.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class _LiveMarksEntryPage extends LScopedView<LiveMarksController> {
  const _LiveMarksEntryPage({required this.evaluationId});

  final String evaluationId;

  @override
  LiveMarksController onConfigScope(LevitScope scope) {
    return scope.put(
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
  }

  @override
  Widget buildView(BuildContext context, LiveMarksController controller) {
    return LWatch(() {
      controller.evaluation.value;
      controller.students.value;
      controller.ungradedOnly.value;
      controller.errorMessage.value;
      controller.saveMessage.value;
      final evaluation = controller.evaluation.value;
      if (evaluation == null) {
        return PrototypeDetailScaffold(
          title: 'Notes',
          body: EmptyState(
            title: 'Évaluation introuvable',
            message: controller.errorMessage.value,
          ),
        );
      }
      final rows = controller.visibleStudents;
      return PopScope(
        canPop:
            !controller.writing.value &&
            !controller.submitting.value &&
            controller.pendingScoreInputs.value.isEmpty,
        onPopInvokedWithResult: (popped, _) async {
          if (popped ||
              controller.writing.value ||
              controller.submitting.value) {
            return;
          }
          if (!await confirmWorkspaceDiscard(context) || !context.mounted) {
            return;
          }
          controller.pendingScoreInputs({});
          await WidgetsBinding.instance.endOfFrame;
          if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
            await closeWorkspaceSheet(context);
          }
        },
        child: PrototypeDetailScaffold(
          title: evaluation.title,
          fallbackRoute: '/evaluations',
          body: ListView(
            padding: const EdgeInsets.all(PrototypeSpacing.md),
            children: [
              Text(
                '${evaluation.classLabel} · ${evaluation.subjectLabel} · ${controller.mentionFirst ? context.tr.gradingMention : 'max ${evaluation.maxScore}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                controller.marksStatus.value == 'submitted'
                    ? context.tr.marksOfficial
                    : 'Brouillon',
              ),
              if (controller.marksStatus.value == 'submitted')
                MarksCorrectionsPanel(controller: controller),
              if (controller.marksStatus.value == 'draft') ...[
                if (!controller.mentionFirst)
                  const Text('Validez chaque note avec Entrée ou Suivant.'),
                FilledButton(
                  onPressed:
                      !controller.writing.value &&
                          controller.pendingScoreInputs.value.isEmpty &&
                          controller.students.value.isNotEmpty &&
                          controller.students.value.every(
                            (r) =>
                                r.score != null ||
                                r.mentionId != null ||
                                ['absent', 'exempt'].contains(r.designation),
                          )
                      ? controller.submitMarks
                      : null,
                  child: const Text('Soumettre les notes'),
                ),
              ],
              if (controller.saveMessage.value.isNotEmpty)
                Text(controller.saveMessage.value),
              if (controller.marksStatus.value == 'draft') ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Non notés uniquement'),
                  value: controller.ungradedOnly.value,
                  onChanged: (value) => controller.ungradedOnly(value),
                ),
                Wrap(
                  spacing: PrototypeSpacing.sm,
                  children: [
                    if (!controller.mentionFirst)
                      OutlinedButton(
                        onPressed: () =>
                            controller.fillUngraded(evaluation.maxScore),
                        child: const Text('Remplir max'),
                      ),
                    OutlinedButton(
                      onPressed: controller.clearUnlocked,
                      child: const Text('Effacer'),
                    ),
                  ],
                ),
                const SizedBox(height: PrototypeSpacing.md),
                for (final mark in rows) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: PrototypeSpacing.xs),
                    child: SurfaceCard(
                      child: Row(
                        children: [
                          PersonAvatar(
                            initials: mark.initials,
                            photoUrl: mark.photoUrl,
                            radius: 18,
                          ),
                          const SizedBox(width: PrototypeSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mark.published
                                      ? '${mark.fullName} · ${context.tr.marksPublishedLock}'
                                      : mark.fullName,
                                ),
                                if (mark.score == null &&
                                    mark.mentionId == null &&
                                    ![
                                      'absent',
                                      'exempt',
                                    ].contains(mark.designation))
                                  Text(
                                    'À compléter',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            enabled:
                                !mark.marksLocked &&
                                !controller.submitting.value,
                            tooltip: context.tr.marksDesignation,
                            onSelected: (value) => controller.saveScore(
                              mark.studentId,
                              null,
                              designation: value,
                            ),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'absent',
                                child: Text(context.tr.marksAbsent),
                              ),
                              PopupMenuItem(
                                value: 'exempt',
                                child: Text(context.tr.marksExempt),
                              ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                mark.designation == 'absent'
                                    ? context.tr.marksAbsent
                                    : mark.designation == 'exempt'
                                    ? context.tr.marksExempt
                                    : '⋮',
                              ),
                            ),
                          ),
                          if (controller.mentionFirst)
                            Flexible(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(
                                  '${mark.studentId}-${mark.mentionId}',
                                ),
                                isExpanded: true,
                                initialValue:
                                    controller.mentions.any(
                                      (range) => range['id'] == mark.mentionId,
                                    )
                                    ? mark.mentionId
                                    : null,
                                decoration: InputDecoration(
                                  labelText: context.tr.gradingMention,
                                  helperText: mark.score != null
                                      ? '${mark.score} / ${evaluation.maxScore}'
                                      : !controller.mentions.any(
                                          (range) =>
                                              range['id'] == mark.mentionId,
                                        )
                                      ? mark.mentionCode
                                      : null,
                                  isDense: true,
                                ),
                                items: [
                                  for (final range in controller.mentions)
                                    DropdownMenuItem(
                                      value: range['id'] as String,
                                      child: Text(
                                        '${range['letter']} — ${range['interpretation']}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged:
                                    mark.marksLocked ||
                                        controller.submitting.value
                                    ? null
                                    : (id) => controller.saveScore(
                                        mark.studentId,
                                        null,
                                        mentionId: id,
                                      ),
                              ),
                            )
                          else
                            SizedBox(
                              width: 72,
                              child: TextFormField(
                                key: ValueKey(
                                  '${mark.studentId}-${mark.score}',
                                ),
                                initialValue:
                                    controller.pendingScoreInputs.value[mark
                                        .studentId] ??
                                    mark.score?.toString() ??
                                    '',
                                enabled:
                                    !mark.marksLocked &&
                                    !controller.submitting.value,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  hintText: '—',
                                  helperText: mark.mentionCode,
                                ),
                                onChanged: (value) => controller
                                    .trackScoreInput(mark.studentId, value),
                                onFieldSubmitted: (value) {
                                  controller.saveScoreText(
                                    mark.studentId,
                                    value,
                                  );
                                },
                                onEditingComplete: () {},
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      );
    });
  }
}

class EvaluationCreatePage extends LView<LiveEvaluationsController> {
  const EvaluationCreatePage({super.key, this.source});
  final Map<String, dynamic>? source;

  @override
  Widget buildView(BuildContext context, LiveEvaluationsController controller) {
    return _EvaluationCreateForm(source: source);
  }
}

class _EvaluationCreateForm extends StatefulWidget {
  const _EvaluationCreateForm({this.source});
  final Map<String, dynamic>? source;

  @override
  State<_EvaluationCreateForm> createState() => _EvaluationCreateFormState();
}

class _EvaluationCreateFormState extends State<_EvaluationCreateForm> {
  final _title = TextEditingController();
  final _maxScore = TextEditingController(text: '20');
  String _kind = 'quiz';
  String? _classSubjectId;
  DateTime _date = DateTime.now();
  DateTime? _dueDate;
  String? _error;
  bool _saving = false;
  bool _dirty = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    if (widget.source case final source?) {
      _title.text = '${source['title']} (copie)';
      _maxScore.text = '${source['maxScore'] ?? 20}';
      _kind = source['kind'] as String? ?? 'quiz';
      _classSubjectId = source['classSubjectId'] as String?;
      final due = DateTime.tryParse('${source['dueAt']}');
      if (_kind == 'homework') {
        _dueDate = due != null && due.isAfter(_date) ? due : _date;
      }
    }
    _title.addListener(_changed);
    _maxScore.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() => _dirty = true);
  }

  Future<void> _close(bool popped) async {
    if (popped || _saving || _confirming) return;
    _confirming = true;
    final discard = await confirmWorkspaceDiscard(context);
    if (!mounted) return;
    _confirming = false;
    if (!discard) return;
    setState(() => _dirty = false);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      closeWorkspaceSheet(context);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _maxScore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.levit.find<LiveEvaluationsController>();
    return LWatch(() {
      controller.classSubjects.value;
      controller.periods.value;
      controller.selectedPeriodId.value;
      final subjects = controller.classSubjects.value;
      _classSubjectId ??= subjects.isEmpty ? null : subjects.first.id;
      return PopScope(
        canPop: !_dirty && !_saving,
        onPopInvokedWithResult: (popped, _) => _close(popped),
        child: PrototypeDetailScaffold(
          title: 'Nouvelle évaluation',
          fallbackRoute: '/evaluations',
          body: ListView(
            padding: const EdgeInsets.all(PrototypeSpacing.md),
            children: [
              Text(
                'Période · ${controller.periods.value.where((p) => p['id'] == controller.selectedPeriodId.value).map(academicPeriodLabel).firstOrNull ?? '—'}',
              ),
              const SizedBox(height: PrototypeSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _classSubjectId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Classe · matière',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final subject in subjects)
                    DropdownMenuItem(
                      value: subject.id,
                      child: Text(
                        subject.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _classSubjectId = value;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: PrototypeSpacing.md),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: PrototypeSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'quiz',
                    child: Text('Interrogation'),
                  ),
                  const DropdownMenuItem(
                    value: 'homework',
                    child: Text('Devoir'),
                  ),
                  const DropdownMenuItem(
                    value: 'project',
                    child: Text('Projet'),
                  ),
                  const DropdownMenuItem(value: 'other', child: Text('Autre')),
                  if (!['quiz', 'homework', 'project', 'other'].contains(_kind))
                    DropdownMenuItem(value: _kind, child: Text(_kind)),
                ],
                onChanged: (value) => setState(() {
                  _kind = value ?? 'quiz';
                  _dirty = true;
                }),
              ),
              const SizedBox(height: PrototypeSpacing.md),
              TextField(
                controller: _maxScore,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Note maximale',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: PrototypeSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date · ${_date.year}-${_date.month}-${_date.day}'),
                trailing: const Icon(Icons.event),
                onTap: () async {
                  final picked = await showWorkspaceDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2018),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _date = picked;
                      _dirty = true;
                    });
                  }
                },
              ),
              if (_kind == 'homework')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _dueDate == null
                        ? 'Échéance requise'
                        : 'Échéance · ${_dueDate!.year}-${_dueDate!.month}-${_dueDate!.day}',
                  ),
                  trailing: const Icon(Icons.event),
                  onTap: () async {
                    final picked = await showWorkspaceDatePicker(
                      context: context,
                      initialDate: _dueDate ?? _date,
                      firstDate: DateTime(2018),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _dueDate = picked;
                        _dirty = true;
                      });
                    }
                  },
                ),
              if (_error != null) Text(_error!),
              const SizedBox(height: PrototypeSpacing.md),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final subject = subjects
                            .where((item) => item.id == _classSubjectId)
                            .firstOrNull;
                        final periodId = controller.selectedPeriodId.value;
                        if (subject == null || periodId == null) {
                          setState(() => _error = 'Classe et période requises');
                          return;
                        }
                        if (_kind == 'homework' && _dueDate == null) {
                          setState(() => _error = 'Échéance requise');
                          return;
                        }
                        setState(() {
                          _saving = true;
                          _error = null;
                        });
                        final error = await controller.createEvaluation(
                          classGroupId: subject.classGroupId,
                          classSubjectId: subject.id,
                          periodId: periodId,
                          title: _title.text,
                          maxScore: double.tryParse(_maxScore.text) ?? 0,
                          assessmentDate: _date,
                          homeworkDueDate: _dueDate,
                          kind: _kind,
                          coefficient:
                              (widget.source?['coefficient'] as num?)
                                  ?.toDouble() ??
                              1,
                        );
                        if (!context.mounted) return;
                        setState(() {
                          _saving = false;
                          _error = error;
                          if (error == null) _dirty = false;
                        });
                        if (error == null) {
                          await WidgetsBinding.instance.endOfFrame;
                          if (context.mounted) {
                            final router = GoRouter.of(context);
                            final id = controller.selectedEvaluationId.value;
                            await closeWorkspaceSheet(context);
                            if (id != null) {
                              router.replace('/evaluations?assessment=$id');
                            }
                          }
                        }
                      },
                child: const Text('Créer'),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _LiveReportCardRosterPage
    extends LScopedView<LiveReportCardRosterController> {
  const _LiveReportCardRosterPage({
    required this.classId,
    required this.periodId,
  });

  final String classId;
  final String periodId;

  @override
  LiveReportCardRosterController onConfigScope(LevitScope scope) {
    return scope.put(
      () => LiveReportCardRosterController(
        classGroupId: classId,
        periodId: periodId,
        teacherContext: scope.find<TeacherContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    LiveReportCardRosterController controller,
  ) {
    return LWatch(() {
      controller.students.value;
      controller.errorMessage.value;
      return controller.students.value.isEmpty
          ? EmptyState(
              title: 'Aucun élève',
              message: controller.errorMessage.value,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(PrototypeSpacing.md),
              itemCount: controller.students.value.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: PrototypeSpacing.xs),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const ComparisonHeading([
                    'Élève',
                    'Bulletin',
                    'Résultat',
                    'Commentaire général',
                  ]);
                }
                final row = controller.students.value[i - 1];
                void open() => context.push(
                  '/report-cards/$classId/$periodId/${row.studentId}',
                );
                return LayoutBuilder(
                  builder: (context, box) {
                    if (useComparisonRows(context, box.maxWidth)) {
                      return ComparisonRow(
                        cells: [
                          row.studentName,
                          row.hasReportCard
                              ? 'Bulletin préparé'
                              : 'Bulletin non généré',
                          row.hasReportCard ? row.averageLabel : '—',
                          row.hasReportCard
                              ? (row.hasComment
                                    ? 'Appréciation renseignée'
                                    : 'À compléter')
                              : '—',
                        ],
                        onTap: row.hasReportCard ? open : null,
                      );
                    }
                    return ListRow(
                      title: row.studentName,
                      subtitle: row.hasReportCard
                          ? '${row.aggregateLabel ?? 'Moy.'} ${row.averageLabel} · Rang ${row.rank ?? '—'}'
                          : 'Bulletin non généré',
                      badge: row.hasReportCard
                          ? (row.hasComment ? 'OK' : 'Commentaire')
                          : null,
                      badgeTone: row.hasComment
                          ? SemanticTone.info
                          : SemanticTone.warning,
                      onTap: row.hasReportCard ? open : null,
                    );
                  },
                );
              },
            );
    });
  }
}

class _LiveReportCardCommentPage
    extends LScopedView<LiveReportCardCommentController> {
  const _LiveReportCardCommentPage({
    required this.classId,
    required this.periodId,
    required this.studentId,
    this.subjectId,
  });

  final String classId;
  final String periodId;
  final String studentId;
  final String? subjectId;

  @override
  LiveReportCardCommentController onConfigScope(LevitScope scope) {
    return scope.put(
      () => LiveReportCardCommentController(
        classGroupId: classId,
        periodId: periodId,
        studentId: studentId,
        subjectId: subjectId,
        homeroomOnly: subjectId == null,
        teacherContext: scope.find<TeacherContextController>(),
        session: scope.find<AppSessionController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
        outboxStore: scope.find<TeacherOutboxStore>(),
      ),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    LiveReportCardCommentController controller,
  ) {
    return LWatch(() {
      controller.fields.value;
      controller.studentName.value;
      controller.errorMessage.value;
      controller.saveMessage.value;
      controller.isReadOnly.value;
      final fields = controller.fields.value;
      if (fields.isEmpty) {
        return PrototypeDetailScaffold(
          title: 'Commentaire',
          fallbackRoute: '/evaluations/report-cards/$classId/$periodId',
          body: EmptyState(
            title: 'Commentaire',
            message: controller.errorMessage.value.isEmpty
                ? 'Aucun champ modifiable'
                : controller.errorMessage.value,
          ),
        );
      }
      return _LiveCommentForm(
        classId: classId,
        periodId: periodId,
        report: subjectId == null ? controller.report : null,
        studentName: controller.studentName.value,
        fields: fields,
        readOnly: controller.isReadOnly.value,
        correctionRequired: controller.correctionRequired.value,
        official: controller.publishedFields,
        proposals: controller.activeProposals,
        onDraft: controller.persistDraft,
        message: controller.saveMessage.value,
        onSave: (comments, reason) =>
            controller.save(comments, correctionReason: reason),
      );
    });
  }
}

class _LiveCommentForm extends StatefulWidget {
  const _LiveCommentForm({
    required this.classId,
    required this.periodId,
    required this.studentName,
    required this.fields,
    required this.readOnly,
    required this.official,
    required this.proposals,
    required this.onDraft,
    this.correctionRequired = false,
    required this.message,
    required this.onSave,
    this.report,
  });

  final String classId;
  final String periodId;
  final Map<String, dynamic>? report;
  final String studentName;
  final List<ReportCardCommentField> fields;
  final bool readOnly;
  final Map<String, String> official;
  final Map<String, ({String text, String status})> proposals;
  final Future<void> Function(Map<String, String>) onDraft;
  final bool correctionRequired;
  final String message;
  final Future<bool> Function(Map<String, String>, String?) onSave;

  @override
  State<_LiveCommentForm> createState() => _LiveCommentFormState();
}

class _LiveCommentFormState extends State<_LiveCommentForm> {
  final _reason = TextEditingController();
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.fields)
        field.sectionId: TextEditingController(text: field.initialComment),
    };
  }

  @override
  void dispose() {
    _reason.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrototypeDetailScaffold(
      title: widget.studentName,
      fallbackRoute:
          '/evaluations/report-cards/${widget.classId}/${widget.periodId}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  context.levit
                          .find<LiveEvaluationsController>()
                          .periods
                          .value
                          .where((p) => p['id'] == widget.periodId)
                          .map(academicPeriodLabel)
                          .firstOrNull ??
                      widget.periodId,
                ),
                if (widget.report case final report?)
                  Text(
                    report['status'] == 'published' ? 'Publié' : 'Brouillon',
                  ),
                if (widget.report?['calculationStale'] == true)
                  const Text('Bulletin à actualiser'),
                for (final status
                    in widget.proposals.values.map((p) => p.status).toSet())
                  Text(status),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(PrototypeSpacing.md),
              children: [
                WorkspaceColumns(
                  firstFraction: 2 / 3,
                  first: [
                    if (widget.report case final report?) ...[
                      if (report['calculationStale'] == true)
                        const Text(
                          'Les résultats ci-dessous sont ceux du dernier calcul.',
                        ),
                      for (final section in _bulletinSubjectSections(
                        report['sectionResults'],
                      ))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(section['name'] as String? ?? 'Matière'),
                          subtitle: Text(
                            section['comment'] as String? ??
                                'Appréciation à compléter',
                          ),
                          trailing: Text(
                            formatCalculatedGrade(
                              (section['average'] as num?)?.toDouble(),
                              (section['grading'] as Map?)
                                  ?.cast<String, dynamic>(),
                            ),
                          ),
                        ),
                      const SizedBox(height: PrototypeSpacing.md),
                    ],
                  ],
                  second: [
                    for (final field in widget.fields) ...[
                      if (widget.correctionRequired)
                        Text(
                          'Appréciation publiée · ${widget.official[field.sectionId] ?? ""}',
                        ),
                      if (widget.proposals[field.sectionId]
                          case final proposal?)
                        Text('${proposal.status} · ${proposal.text}'),
                      TextField(
                        controller: _controllers[field.sectionId],
                        enabled:
                            !widget.readOnly &&
                            !widget.proposals.values.any(
                              (p) => p.status.startsWith('Approuvée'),
                            ),
                        onChanged: (_) => widget.onDraft({
                          for (final e in _controllers.entries)
                            e.key: e.value.text,
                        }),
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: field.isHomeroom
                              ? 'Commentaire titulaire'
                              : field.label,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: PrototypeSpacing.md),
                    ],
                    if (widget.correctionRequired)
                      TextField(
                        controller: _reason,
                        decoration: InputDecoration(
                          labelText: context.tr.marksCorrectionReason,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    if (widget.message.isNotEmpty) Text(widget.message),
                    if (!widget.readOnly)
                      FilledButton(
                        onPressed:
                            widget.correctionRequired &&
                                _reason.text.trim().isEmpty
                            ? null
                            : () async {
                                final comments = {
                                  for (final entry in _controllers.entries)
                                    entry.key: entry.value.text,
                                };
                                final saved = await widget.onSave(
                                  comments,
                                  widget.correctionRequired
                                      ? _reason.text.trim()
                                      : null,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      saved
                                          ? (widget.correctionRequired
                                                ? context
                                                      .tr
                                                      .workflowCorrectionPending
                                                : 'Commentaire enregistré')
                                          : 'Enregistrement impossible',
                                    ),
                                  ),
                                );
                              },
                        child: Text(
                          widget.correctionRequired
                              ? context.tr.workflowRequestCorrection
                              : context.tr.save,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Iterable<Map> _bulletinSubjectSections(dynamic rows) sync* {
  for (final row in (rows as List? ?? []).whereType<Map>()) {
    if (row['classSubjectId'] != null) yield row;
    yield* _bulletinSubjectSections(row['subResults']);
  }
}
