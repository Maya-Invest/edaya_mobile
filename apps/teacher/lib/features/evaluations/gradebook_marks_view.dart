import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../app/workspace_navigation.dart';
import '../../design/components/surface_card.dart';
import 'live_marks_controller.dart';
import 'pupil_mark_correction_sheet.dart';
import 'evaluations_page.dart';
import 'package:edaya_api_client/edaya_api_client.dart'
    show GeneratedSchoolClientEntities;

class GradebookMarksView extends StatefulWidget {
  const GradebookMarksView({
    super.key,
    required this.controller,
    this.header,
    this.action,
  });
  final Widget? header;
  final FeatureAction? action;
  final LiveMarksController controller;
  @override
  State<GradebookMarksView> createState() => _GradebookMarksState();
}

class _GradebookMarksState extends State<GradebookMarksView> {
  GoRouter? router;
  Future<bool>? pendingGuard;
  LiveMarksController get c => widget.controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    router = GoRouter.maybeOf(context);
    if (router != null) workspaceChangeGuards[router!] = leave;
  }

  @override
  void dispose() {
    if (router != null && workspaceChangeGuards[router!] == leave) {
      workspaceChangeGuards[router!] = null;
    }
    super.dispose();
  }

  Future<bool> leave() async {
    if (pendingGuard != null) return pendingGuard!;
    if (c.writing.value || c.submitting.value) return false;
    if (!c.hasUnsaved) return true;
    pendingGuard = _askLeave();
    try {
      return await pendingGuard!;
    } finally {
      pendingGuard = null;
    }
  }

  Future<bool> _askLeave() async {
    final tr = context.tr;
    final action = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(tr.gradebookUnsaved),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, 'continue'),
            child: Text(tr.gradebookContinue),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, 'discard'),
            child: Text(tr.gradebookDiscard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, 'save'),
            child: Text(tr.gradebookSave),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (action == 'discard') {
      c.discardEdits();
      return true;
    }
    return action == 'save' && await c.saveDraft();
  }

  Future<void> edit(LiveMarkRow row) => showWorkspaceEditor<void>(
    context: context,
    ownerUri: Uri(
      path: '/evaluations',
      queryParameters: {'assessment': c.evaluationId},
    ),
    title: context.tr.gradebookEdit,
    builder: (_, close) => PupilMarkCorrectionSheet(
      controller: c,
      studentId: row.studentId,
      close: () => close(null),
    ),
  );
  @override
  Widget build(BuildContext context) => LWatch(() {
    final tr = context.tr;
    final rows = c.students.value;
    final submitted = c.marksStatus.value == 'submitted';
    if (c.evaluation.value == null && c.isBusy.value) {
      return const Center(child: CircularProgressIndicator());
    }
    final body = Column(
      children: [
        if (c.errorMessage.value.isNotEmpty)
          TextButton(onPressed: c.load, child: Text(c.errorMessage.value)),
        Expanded(
          child: SingleChildScrollView(
            key: PageStorageKey(('marks', c.evaluationId)),
            padding: const EdgeInsets.all(16),
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                children: List.generate(rows.length + 1, (index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.header != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: widget.header!,
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                submitted
                                    ? tr.gradebookOfficial
                                    : tr.gradebookDraft,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: tr.duplicateEvaluation,
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'duplicate',
                                  child: Text(tr.duplicateEvaluation),
                                ),
                              ],
                              onSelected: (_) async {
                                if (!await leave() || !context.mounted) return;
                                try {
                                  final source = await context.levit
                                      .find<SchoolClientFactory>()()
                                      .assessments
                                      .get(c.evaluationId);
                                  if (!context.mounted) return;
                                  await showWorkspaceEditor<void>(
                                    context: context,
                                    ownerUri: Uri(
                                      path: '/evaluations',
                                      queryParameters: {
                                        'assessment': c.evaluationId,
                                      },
                                    ),
                                    title: tr.duplicateEvaluation,
                                    builder: (_, close) =>
                                        EvaluationCreatePage(source: source),
                                  );
                                } on Object catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                  final row = rows[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: submitted
                        ? _OfficialMarkRow(
                            key: ValueKey(row.studentId),
                            row: row,
                            controller: c,
                            open: () => edit(row),
                          )
                        : DraftMarkRow(
                            key: ValueKey(row.studentId),
                            row: row,
                            controller: c,
                          ),
                  );
                }),
              ),
            ),
          ),
        ),
        if (widget.action case final action?)
          FeatureActionBar(actions: [action]),
        if (!submitted) _DraftActions(controller: c),
      ],
    );
    return LWatch(
      () => PopScope(
        canPop: !c.hasUnsaved && !c.writing.value && !c.submitting.value,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop && await leave() && context.mounted) {
            await WidgetsBinding.instance.endOfFrame;
            if (context.mounted) await backFromWorkspace(context);
          }
        },
        child: body,
      ),
    );
  });
}

class _DraftActions extends StatelessWidget {
  const _DraftActions({required this.controller});
  final LiveMarksController controller;
  @override
  Widget build(BuildContext context) => LWatch(() {
    final c = controller, tr = context.tr;
    final busy = c.writing.value || c.submitting.value;
    final unsaved = c.hasUnsaved;
    final complete =
        c.students.value.isNotEmpty &&
        c.completedCount == c.students.value.length;
    final queued = c.students.value.any(
      (r) => r.syncState != MarkSyncState.synced,
    );
    final save = !busy && (unsaved || queued) ? c.saveDraft : null;
    final submit = !busy && complete ? c.saveAndSubmit : null;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${c.completedCount}/${c.students.value.length} · ${unsaved
                    ? tr.gradebookUnsaved
                    : queued
                    ? tr.gradebookQueued
                    : tr.gradebookSaved}',
              ),
              if (c.saveMessage.value.isNotEmpty) ...[
                Text(c.saveMessage.value),
                if (c.hasUnsaved ||
                    c.students.value.any(
                      (r) => r.syncState == MarkSyncState.failed,
                    ))
                  TextButton(
                    onPressed: busy ? null : c.reviewSaveFailure,
                    child: Text(tr.retry),
                  ),
              ],
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (unsaved)
                    FilledButton(onPressed: save, child: Text(tr.gradebookSave))
                  else
                    OutlinedButton(
                      onPressed: save,
                      child: Text(tr.gradebookSave),
                    ),
                  if (unsaved)
                    OutlinedButton(
                      onPressed: submit,
                      child: Text(tr.gradebookSubmit),
                    )
                  else
                    FilledButton(
                      onPressed: submit,
                      child: Text(tr.gradebookSubmit),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  });
}

class DraftMarkRow extends StatefulWidget {
  const DraftMarkRow({super.key, required this.row, required this.controller});
  final LiveMarkRow row;
  final LiveMarksController controller;
  @override
  State<DraftMarkRow> createState() => _DraftMarkRowState();
}

class _DraftMarkRowState extends State<DraftMarkRow>
    with AutomaticKeepAliveClientMixin {
  late final text = TextEditingController(
    text: widget.controller.draftFor(widget.row).text,
  );
  final focus = FocusNode();
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LWatch(() {
      final c = widget.controller, row = widget.row, tr = context.tr;
      final draft = c.draftFor(row);
      if (text.text != draft.text && !focus.hasFocus) {
        text.value = TextEditingValue(
          text: draft.text,
          selection: TextSelection.collapsed(offset: draft.text.length),
        );
      }
      final enabled =
          !row.marksLocked &&
          !row.published &&
          !c.writing.value &&
          !c.submitting.value;
      final error = c.entryErrors.value[row.studentId];
      final entry = draft.exceptional
          ? Text(
              draft.designation == 'absent' ? tr.marksAbsent : tr.marksExempt,
            )
          : c.mentionFirst
          ? DropdownButtonFormField<String>(
              initialValue: c.mentions.any((m) => m['id'] == draft.mentionId)
                  ? draft.mentionId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tr.gradingMention,
                errorText: error,
              ),
              items: [
                for (final m in c.mentions)
                  DropdownMenuItem(
                    value: m['id'] as String,
                    child: Text(
                      '${m['letter']} · ${m['interpretation']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: enabled
                  ? (id) => c.editMark(
                      row.studentId,
                      MarkDraft(mentionId: id, designation: 'scored'),
                    )
                  : null,
            )
          : TextField(
              key: ValueKey('score-${row.studentId}'),
              controller: text,
              focusNode: focus,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: tr.gradebookResult,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                suffixText:
                    '/ ${formatGradeNumber(c.evaluation.value?.maxScore ?? 20)}',
                errorText: error,
                hintText: '—',
              ),
              onChanged: (value) =>
                  c.editMark(row.studentId, MarkDraft(text: value)),
              onEditingComplete: () {},
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            );
      return SurfaceCard(
        child: LayoutBuilder(
          builder: (context, box) {
            final actions = Row(
              children: [
                Expanded(
                  child: FocusTraversalOrder(
                    order: NumericFocusOrder(
                      c.students.value
                          .indexWhere((r) => r.studentId == row.studentId)
                          .toDouble(),
                    ),
                    child: entry,
                  ),
                ),
                FocusTraversalOrder(
                  order: NumericFocusOrder(
                    c.students.value.length +
                        c.students.value
                            .indexWhere((r) => r.studentId == row.studentId)
                            .toDouble(),
                  ),
                  child: PopupMenuButton<String>(
                    tooltip: tr.gradebookOptions,
                    enabled: enabled,
                    onSelected: (value) {
                      text.clear();
                      c.editMark(
                        row.studentId,
                        MarkDraft(designation: value == 'clear' ? null : value),
                      );
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'absent',
                        child: Text(tr.marksAbsent),
                      ),
                      PopupMenuItem(
                        value: 'exempt',
                        child: Text(tr.marksExempt),
                      ),
                      PopupMenuItem(
                        value: 'clear',
                        child: Text(tr.gradebookClear),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final name = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.fullName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (row.published) Text(tr.gradebookLocked),
                if (row.syncState != MarkSyncState.synced)
                  Text(tr.gradebookQueued),
              ],
            );
            return _markRowLayout(context, box, name, actions);
          },
        ),
      );
    });
  }
}

class _OfficialMarkRow extends StatelessWidget {
  const _OfficialMarkRow({
    super.key,
    required this.row,
    required this.controller,
    required this.open,
  });
  final LiveMarkRow row;
  final LiveMarksController controller;
  final VoidCallback open;
  @override
  Widget build(BuildContext context) => LWatch(() {
    final tr = context.tr, c = controller;
    final pending = c.pendingFor(row);
    final proposed = pending == null
        ? null
        : (pending['changes'] as List).cast<Map>().firstWhere(
                (v) => v['resultId'] == row.resultId,
              )['proposed']
              as Map;
    final official = MarkDraft.fromRow(row);
    final evaluation = c.evaluation.value;
    final date = DateTime.tryParse(evaluation?.date ?? '');
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: GradeRecordRow(
        title: row.fullName,
        result: row.official,
        editLabel: c.canEditCorrection(row) ? tr.gradebookEdit : null,
        onEdit: c.canEditCorrection(row) ? open : null,
        details: Column(
          spacing: 12,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradeValue(
              '${tr.gradebookOfficial} · ${row.official.isEmpty ? pupilResultLabel(context, c, official.values) : officialMarkLabel(context, row.official)}',
              row.official,
              key: ValueKey('official-${row.studentId}'),
            ),
            if (date != null)
              Text(
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(date.toLocal()),
              ),
            if (evaluation?.coefficient case final num coefficient)
              Text(
                tr.coefficient(
                  formatGradeNumber(
                    coefficient,
                    locale: Localizations.localeOf(context).languageCode,
                  ),
                ),
              ),
            if (row.notes?.isNotEmpty ?? false)
              Text('${tr.marksComment} · ${row.notes}'),
            if (proposed != null)
              Text(
                '${tr.gradebookPending} · ${pupilResultLabel(context, c, proposed)}',
              ),
            if (pending?['reason'] case final String reason)
              Text('${tr.gradebookReason} · $reason'),
            if (!c.canEditCorrection(row)) Text(tr.gradebookLocked),
          ],
        ),
      ),
    );
  });
}

/// Draft inputs retain their responsive editor columns.
Widget _markRowLayout(
  BuildContext context,
  BoxConstraints box,
  Widget name,
  Widget actions,
) {
  final stacked =
      box.maxWidth < 290 || MediaQuery.textScalerOf(context).scale(14) > 22;
  return stacked
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [name, const SizedBox(height: 8), actions],
        )
      : Row(
          children: [
            Expanded(child: name),
            const SizedBox(width: 12),
            SizedBox(width: box.maxWidth < 500 ? 155 : 240, child: actions),
          ],
        );
}
