import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/entity_queries.dart';
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
  const EvaluationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveEvaluationsPage();
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
                            initialValue: mark.score?.toStringAsFixed(2) ?? '',
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
  });

  final String classId;
  final String periodId;
  final String rosterId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveReportCardCommentPage(
        classId: classId,
        periodId: periodId,
        studentId: rosterId,
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

class _LiveEvaluationsPage extends LView<LiveEvaluationsController> {
  const _LiveEvaluationsPage();

  @override
  Widget buildView(BuildContext context, LiveEvaluationsController controller) {
    return LWatch(() {
      controller.evaluations.value;
      controller.periods.value;
      controller.selectedPeriodId.value;
      controller.errorMessage.value;
      final reportCards = context.levit.find<LiveReportCardsController>();
      reportCards.classSummaries.value;
      final evaluations = controller.evaluations.value;
      return AdaptiveContent(
        child: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            Row(
              children: [
                const Expanded(child: SectionHeader(title: 'Évaluations')),
                IconButton(
                  tooltip: 'Créer',
                  onPressed: () => context.go('/evaluations/create'),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (controller.periods.value.isNotEmpty) ...[
              const SizedBox(height: PrototypeSpacing.sm),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: controller.selectedPeriodId.value,
                decoration: const InputDecoration(
                  labelText: 'Période',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final period in controller.periods.value)
                    DropdownMenuItem(
                      value: period['id'] as String,
                      child: Text(
                        academicPeriodLabel(period),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) controller.selectPeriod(value);
                },
              ),
            ],
            const SizedBox(height: PrototypeSpacing.sm),
            if (evaluations.isEmpty)
              EmptyState(
                title: 'Aucune évaluation',
                message: controller.errorMessage.value,
              )
            else
              for (final e in evaluations) ...[
                ListRow(
                  title: e.title,
                  subtitle:
                      '${e.classLabel} · ${e.subjectLabel} · ${e.gradedCount}/${e.totalStudents} notés · max ${e.maxScore.toStringAsFixed(0)}',
                  badge: e.needsMarks ? 'À saisir' : 'Complet',
                  badgeTone: e.needsMarks
                      ? SemanticTone.warning
                      : SemanticTone.info,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'marks') {
                        context.go('/evaluations/${e.id}/marks');
                      } else if (value == 'duplicate') {
                        await controller.duplicateEvaluation(e);
                      } else if (value == 'complete') {
                        final error = await controller.completeEvaluation(e);
                        if (error != null && context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'marks',
                        child: Text('Saisir notes'),
                      ),
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Dupliquer'),
                      ),
                      PopupMenuItem(value: 'complete', child: Text('Terminer')),
                    ],
                  ),
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
            if (reportCards.classSummaries.value.isEmpty)
              const EmptyState(title: 'Aucun bulletin')
            else
              for (final rc in reportCards.classSummaries.value) ...[
                ListRow(
                  title: '${rc.classLabel} · ${rc.periodLabel}',
                  subtitle: rc.generatedCount == 0
                      ? 'Aucun bulletin généré'
                      : '${rc.pendingComments} commentaires en attente',
                  leading: Icon(
                    Icons.description_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: rc.generatedCount == 0
                      ? null
                      : () => context.go(
                          '/evaluations/report-cards/${rc.classGroupId}/${rc.periodId}',
                        ),
                ),
                const SizedBox(height: PrototypeSpacing.xs),
              ],
          ],
        ),
      );
    });
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
      return PrototypeDetailScaffold(
        title: evaluation.title,
        fallbackRoute: '/evaluations',
        body: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            Text(
              '${evaluation.classLabel} · ${evaluation.subjectLabel} · max ${evaluation.maxScore.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              controller.marksStatus.value == 'submitted'
                  ? context.tr.marksOfficial
                  : 'Brouillon',
            ),
            MarksCorrectionsPanel(controller: controller),
            if (controller.marksStatus.value == 'draft')
              FilledButton(
                onPressed: controller.submitMarks,
                child: const Text('Soumettre les notes'),
              ),
            if (controller.saveMessage.value.isNotEmpty)
              Text(controller.saveMessage.value),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Non notés uniquement'),
              value: controller.ungradedOnly.value,
              onChanged: (value) => controller.ungradedOnly(value),
            ),
            Wrap(
              spacing: PrototypeSpacing.sm,
              children: [
                OutlinedButton(
                  onPressed: () => controller.fillUngraded(evaluation.maxScore),
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
                        child: Text(
                          mark.published
                              ? '${mark.fullName} · ${context.tr.marksPublishedLock}'
                              : mark.fullName,
                        ),
                      ),
                      PopupMenuButton<String>(
                        enabled: !mark.marksLocked,
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
                      SizedBox(
                        width: 72,
                        child: TextFormField(
                          key: ValueKey('${mark.studentId}-${mark.score}'),
                          initialValue: mark.score?.toStringAsFixed(2) ?? '',
                          enabled: !mark.marksLocked,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: '—',
                          ),
                          onFieldSubmitted: (value) {
                            controller.saveScoreText(mark.studentId, value);
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
        ),
      );
    });
  }
}

class EvaluationCreatePage extends LView<LiveEvaluationsController> {
  const EvaluationCreatePage({super.key});

  @override
  Widget buildView(BuildContext context, LiveEvaluationsController controller) {
    return const _EvaluationCreateForm();
  }
}

class _EvaluationCreateForm extends StatefulWidget {
  const _EvaluationCreateForm();

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
      return PrototypeDetailScaffold(
        title: 'Nouvelle évaluation',
        fallbackRoute: '/evaluations',
        body: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
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
                    child: Text(subject.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _classSubjectId = value),
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
              items: const [
                DropdownMenuItem(value: 'quiz', child: Text('Interrogation')),
                DropdownMenuItem(value: 'homework', child: Text('Devoir')),
                DropdownMenuItem(value: 'project', child: Text('Projet')),
                DropdownMenuItem(value: 'other', child: Text('Autre')),
              ],
              onChanged: (value) => setState(() => _kind = value ?? 'quiz'),
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
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2018),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _date = picked);
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
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? _date,
                    firstDate: DateTime(2018),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
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
                      );
                      if (!context.mounted) return;
                      setState(() {
                        _saving = false;
                        _error = error;
                      });
                      if (error == null) {
                        context.go('/evaluations');
                      }
                    },
              child: const Text('Créer'),
            ),
          ],
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
      return PrototypeDetailScaffold(
        title: 'Bulletin',
        fallbackRoute: '/evaluations',
        body: controller.students.value.isEmpty
            ? EmptyState(
                title: 'Aucun élève',
                message: controller.errorMessage.value,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(PrototypeSpacing.md),
                itemCount: controller.students.value.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: PrototypeSpacing.xs),
                itemBuilder: (context, i) {
                  final row = controller.students.value[i];
                  return ListRow(
                    title: row.studentName,
                    subtitle: row.hasReportCard
                        ? 'Moy. ${row.overallAverage?.toStringAsFixed(2) ?? '—'} · Rang ${row.rank ?? '—'}'
                        : 'Bulletin non généré',
                    badge: row.hasComment ? 'OK' : 'Commentaire',
                    badgeTone: row.hasComment
                        ? SemanticTone.info
                        : SemanticTone.warning,
                    onTap: row.hasReportCard
                        ? () => context.go(
                            '/evaluations/report-cards/$classId/$periodId/${row.studentId}',
                          )
                        : null,
                  );
                },
              ),
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
  });

  final String classId;
  final String periodId;
  final String studentId;

  @override
  LiveReportCardCommentController onConfigScope(LevitScope scope) {
    return scope.put(
      () => LiveReportCardCommentController(
        classGroupId: classId,
        periodId: periodId,
        studentId: studentId,
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
        studentName: controller.studentName.value,
        fields: fields,
        readOnly: controller.isReadOnly.value,
        correctionRequired: controller.correctionRequired.value,
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
    this.correctionRequired = false,
    required this.message,
    required this.onSave,
  });

  final String classId;
  final String periodId;
  final String studentName;
  final List<ReportCardCommentField> fields;
  final bool readOnly;
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
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          for (final field in widget.fields) ...[
            TextField(
              controller: _controllers[field.sectionId],
              enabled: !widget.readOnly,
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
                  widget.correctionRequired && _reason.text.trim().isEmpty
                  ? null
                  : () async {
                      final comments = {
                        for (final entry in _controllers.entries)
                          entry.key: entry.value.text,
                      };
                      final saved = await widget.onSave(
                        comments,
                        widget.correctionRequired ? _reason.text.trim() : null,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            saved
                                ? (widget.correctionRequired
                                      ? context.tr.workflowCorrectionPending
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
    );
  }
}
