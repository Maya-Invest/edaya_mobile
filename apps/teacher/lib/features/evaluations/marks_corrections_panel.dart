import '../../app/workspace_navigation.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:levit_flutter/levit_flutter.dart';

import 'live_marks_controller.dart';

/// Official marks and pending proposals are presented separately.
class MarksCorrectionsPanel extends StatefulWidget {
  const MarksCorrectionsPanel({super.key, required this.controller});
  final LiveMarksController controller;
  @override
  State<MarksCorrectionsPanel> createState() => _MarksCorrectionsState();
}

class _MarksCorrectionsState extends State<MarksCorrectionsPanel> {
  String? selected;
  @override
  Widget build(BuildContext context) => LWatch(() {
    final c = widget.controller;
    final pending = c.corrections.value
        .where((r) => r['status'] == 'pending')
        .toList();
    final id = selected ?? pending.firstOrNull?['id'];
    final active = pending.where((r) => r['id'] == id).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pending.isNotEmpty &&
            (pending.length > 1 || c.canRequestCorrection.value))
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: active?['id'] as String? ?? 'new',
            decoration: InputDecoration(labelText: context.tr.change),
            items: [
              if (c.canRequestCorrection.value || active == null)
                DropdownMenuItem(
                  value: 'new',
                  child: Text(context.tr.otherMarks),
                ),
              for (final r in pending)
                DropdownMenuItem(
                  value: r['id'] as String,
                  child: Text(
                    context.tr.pendingPupilCount((r["changes"] as List).length),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => selected = v),
          ),
        _CorrectionForm(
          key: ValueKey((active?['id'], active?['version'])),
          controller: c,
          correction: active,
        ),
        if (active != null &&
            (active['allowedActions'] as Map?)?['withdraw'] == true)
          TextButton(
            onPressed: () => c.withdrawCorrection(active),
            child: Text(context.tr.marksWithdrawCorrection),
          ),
      ],
    );
  });
}

class _CorrectionDraft {
  _CorrectionDraft(this.row)
    : score = TextEditingController(
        text: row.score == null ? '' : formatGradeNumber(row.score),
      ),
      notes = TextEditingController(text: row.notes ?? ''),
      designation = row.designation ?? 'scored',
      mentionId = row.mentionId,
      deadlineStatus = row.deadlineStatus;
  final LiveMarkRow row;
  final TextEditingController score;
  final TextEditingController notes;
  String designation;
  String? mentionId;
  String? deadlineStatus;
  bool selected = false;
  void dispose() {
    score.dispose();
    notes.dispose();
  }

  Map<String, dynamic> get official => {
    'score': row.score,
    'mentionId': row.mentionId,
    'notes': row.notes,
    'designation': row.designation ?? 'scored',
    'status': row.deadlineStatus,
  };
  Map<String, dynamic> get proposed => {
    'mentionId': designation == 'scored' ? mentionId : null,
    'score': designation == 'scored' && mentionId == null
        ? double.tryParse(score.text.trim().replaceAll(',', '.'))
        : null,
    'designation': designation,
    'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
    'status': deadlineStatus,
  };
}

class _CorrectionForm extends StatefulWidget {
  const _CorrectionForm({super.key, required this.controller, this.correction});
  final Map<String, dynamic>? correction;
  final LiveMarksController controller;
  @override
  State<_CorrectionForm> createState() => _CorrectionFormState();
}

class _CorrectionFormState extends State<_CorrectionForm> {
  late final rows = widget.controller.students.value
      .where(
        (row) =>
            !row.published &&
            row.resultId != null &&
            !widget.controller.corrections.value.any(
              (c) =>
                  c['status'] == 'pending' &&
                  c['id'] != widget.correction?['id'] &&
                  (c['changes'] as List).any(
                    (change) => (change as Map)['resultId'] == row.resultId,
                  ),
            ),
      )
      .map(_CorrectionDraft.new)
      .toList();
  final reason = TextEditingController();
  bool busy = false, dirty = false, confirm = false;
  @override
  void dispose() {
    for (final row in rows) {
      row.dispose();
    }
    reason.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final correction = widget.correction;
    if (correction == null) return;
    reason.text = correction['reason'] as String;
    for (final draft in rows) {
      final change = (correction['changes'] as List)
          .cast<Map>()
          .where((c) => c['resultId'] == draft.row.resultId)
          .firstOrNull;
      if (change == null) continue;
      final proposed = change['proposed'] as Map;
      draft.selected = true;
      draft.designation = proposed['designation'] as String;
      draft.mentionId = proposed['mentionId'] as String?;
      draft.score.text = proposed['score'] == null
          ? ''
          : formatGradeNumber(proposed['score'] as num);
      draft.notes.text = proposed['notes'] as String? ?? '';
      draft.deadlineStatus =
          proposed['status'] as String? ?? draft.row.deadlineStatus;
    }
  }

  String pendingValue(Map value) {
    if (value['designation'] == 'absent') return 'Absent';
    if (value['designation'] == 'exempt') return context.tr.marksExempt;
    if (value['mentionId'] != null) {
      return widget.controller.mentionLabel(value['mentionId'] as String);
    }
    return formatGradeNumber(value['score'] as num?);
  }

  void changed() => setState(() {
    dirty = true;
  });

  @override
  Widget build(BuildContext context) {
    final selected = rows
        .where((d) => d.selected && !mapEquals(d.proposed, d.official))
        .toList();
    final changes = (widget.correction?['changes'] as List? ?? []).cast<Map>();
    final different =
        widget.correction == null ||
        reason.text.trim() != widget.correction?['reason'] ||
        changes.length != selected.length ||
        selected.any((d) {
          final old =
              changes
                      .where((c) => c['resultId'] == d.row.resultId)
                      .firstOrNull?['proposed']
                  as Map?;
          return old == null ||
              !d.proposed.entries.every((e) => old[e.key] == e.value);
        });
    if (confirm) {
      return Column(
        children: [
          Text(context.tr.guardianDiscardChanges),
          TextButton(
            onPressed: () => setState(() => confirm = false),
            child: Text(context.tr.gradebookContinue),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                dirty = false;
                confirm = false;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) closeWorkspaceSheet(context);
              });
            },
            child: Text(context.tr.teacherSignatureDiscard),
          ),
        ],
      );
    }
    return PopScope(
      canPop: !busy && !dirty,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && !busy) setState(() => confirm = true);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.tr.marksCorrectionHint),
          for (final locked in widget.controller.students.value.where(
            (r) => !rows.any((d) => d.row.studentId == r.studentId),
          ))
            ListTile(
              title: Text(locked.fullName),
              subtitle: Text(
                context.tr.officialMark(
                  pendingValue({
                    'designation': locked.designation,
                    'score': locked.score,
                    'mentionId': locked.mentionId,
                  }),
                ),
              ),
            ),
          for (final draft in rows) ...[
            if (widget.correction != null)
              for (final change
                  in (widget.correction!['changes'] as List).cast<Map>().where(
                    (c) => c['resultId'] == draft.row.resultId,
                  ))
                Text(
                  context.tr.pendingApproval(
                    draft.row.fullName,
                    pendingValue(change["proposed"] as Map),
                  ),
                ),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: draft.selected,
              title: Text(draft.row.fullName),
              subtitle: Text(
                context.tr.officialMark(
                  draft.row.designation == 'absent'
                      ? context.tr.marksAbsent
                      : draft.row.designation == 'exempt'
                      ? context.tr.marksExempt
                      : draft.row.mentionCode ??
                            formatGradeNumber(draft.row.score),
                ),
              ),
              onChanged: busy
                  ? null
                  : (value) {
                      draft.selected = value ?? false;
                      changed();
                    },
            ),
            if (draft.selected) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: draft.designation,
                decoration: InputDecoration(
                  labelText: context.tr.marksDesignation,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'scored',
                    child: Text(context.tr.marksProposed),
                  ),
                  DropdownMenuItem(
                    value: 'absent',
                    child: Text(context.tr.marksAbsent),
                  ),
                  DropdownMenuItem(
                    value: 'exempt',
                    child: Text(context.tr.marksExempt),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        draft.designation = value!;
                        changed();
                      },
              ),
              if (draft.designation == 'scored' &&
                  widget.controller.mentionFirst)
                DropdownButtonFormField<String>(
                  initialValue:
                      widget.controller.mentions.any(
                        (range) => range['id'] == draft.mentionId,
                      )
                      ? draft.mentionId
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr.gradingMention,
                  ),
                  items: [
                    for (final range in widget.controller.mentions)
                      DropdownMenuItem(
                        value: range['id'] as String,
                        child: Text(
                          '${range['letter']} — ${range['interpretation']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          draft.mentionId = value;
                          draft.score.clear();
                          changed();
                        },
                ),
              if (draft.designation == 'scored' &&
                  !widget.controller.mentionFirst)
                TextField(
                  controller: draft.score,
                  enabled: !busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr.marksProposed,
                  ),
                  onChanged: (_) => changed(),
                ),
              if (widget.controller.evaluation.value?.kind == 'homework')
                DropdownButtonFormField<String>(
                  initialValue: draft.deadlineStatus,
                  decoration: InputDecoration(
                    labelText: context.tr.deadlineCompliance,
                  ),
                  items: [
                    for (final status in ['met', 'late', 'missed', 'excused'])
                      DropdownMenuItem(
                        value: status,
                        child: Text(switch (status) {
                          'met' => context.tr.deadlineMet,
                          'late' => context.tr.deadlineLate,
                          'missed' => context.tr.deadlineMissed,
                          _ => context.tr.deadlineExcused,
                        }),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          draft.deadlineStatus = value;
                          changed();
                        },
                ),
              TextField(
                controller: draft.notes,
                enabled: !busy,
                decoration: InputDecoration(labelText: context.tr.marksComment),
                onChanged: (_) => changed(),
              ),
            ],
          ],
          TextField(
            controller: reason,
            enabled: !busy,
            decoration: InputDecoration(
              labelText: context.tr.marksCorrectionReason,
            ),
            onChanged: (_) => changed(),
          ),
          for (final draft in selected)
            Text(
              '${draft.row.fullName}: ${draft.row.mentionCode ?? (draft.row.designation == 'absent'
                      ? context.tr.marksAbsent
                      : draft.row.designation == 'exempt'
                      ? context.tr.marksExempt
                      : formatGradeNumber(draft.row.score))} → ${draft.designation == 'scored'
                  ? (draft.mentionId == null ? draft.score.text : widget.controller.mentionLabel(draft.mentionId!))
                  : draft.designation == 'absent'
                  ? context.tr.marksAbsent
                  : context.tr.marksExempt} · ${draft.notes.text}',
            ),
          LWatch(() => Text(widget.controller.saveMessage.value)),
          FilledButton(
            onPressed:
                busy ||
                    !different ||
                    selected.isEmpty ||
                    reason.text.trim().isEmpty
                ? null
                : () async {
                    setState(() => busy = true);
                    final saved = await widget.controller.requestCorrection(
                      selected
                          .map(
                            (draft) => {
                              'resultId': draft.row.resultId,
                              'proposed': draft.proposed,
                            },
                          )
                          .toList(),
                      reason.text,
                      correction: widget.correction,
                    );
                    if (!context.mounted) return;
                    setState(() {
                      busy = false;
                      if (saved) dirty = false;
                    });
                  },
            child: Text(context.tr.gradebookSubmit),
          ),
        ],
      ),
    );
  }
}
