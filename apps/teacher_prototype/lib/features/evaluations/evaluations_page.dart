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
import 'live_evaluations_controller.dart';
import 'live_marks_controller.dart';

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
              color: PrototypeColors.primary,
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
                color: PrototypeColors.primary,
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
                            initialValue: mark.score?.toStringAsFixed(0) ?? '',
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

class ReportCardRosterPage extends LScopedView<StoreBoundController> {
  const ReportCardRosterPage({
    super.key,
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
                'Moy. ${row.average.toStringAsFixed(1)} · Rang ${row.rank}',
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

class ReportCardCommentPage extends LScopedView<StoreBoundController> {
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
            'Moyenne ${widget.row.average.toStringAsFixed(1)} · Rang ${widget.row.rank}',
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
      controller.errorMessage.value;
      final evaluations = controller.evaluations.value;
      return AdaptiveContent(
        child: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            const SectionHeader(title: 'Évaluations'),
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
                      '${e.classLabel} · ${e.subjectLabel} · ${e.gradedCount}/${e.totalStudents} notés',
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
                color: PrototypeColors.primary,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/evaluations/avis'),
            ),
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
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, LiveMarksController controller) {
    return LWatch(() {
      controller.evaluation.value;
      controller.students.value;
      controller.errorMessage.value;
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
      return PrototypeDetailScaffold(
        title: evaluation.title,
        fallbackRoute: '/evaluations',
        body: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            Text(
              '${evaluation.classLabel} · ${evaluation.subjectLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: PrototypeSpacing.md),
            for (final mark in controller.students.value) ...[
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
                      Expanded(child: Text(mark.fullName)),
                      SizedBox(
                        width: 72,
                        child: TextFormField(
                          initialValue: mark.score?.toStringAsFixed(0) ?? '',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: '—',
                          ),
                          onChanged: (value) {
                            final parsed = double.tryParse(value);
                            controller.saveScore(mark.studentId, parsed);
                          },
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
