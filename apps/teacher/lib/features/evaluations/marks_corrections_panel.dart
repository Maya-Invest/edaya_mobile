import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import 'live_marks_controller.dart';

/// Official marks and pending proposals are presented separately.
class MarksCorrectionsPanel extends StatelessWidget {
  const MarksCorrectionsPanel({super.key, required this.controller});
  final LiveMarksController controller;

  @override
  Widget build(BuildContext context) => LWatch(() {
    final rows = controller.students.value;
    String name(String id) =>
        rows.where((row) => row.studentId == id).firstOrNull?.fullName ?? id;
    String display(Map value) => value['designation'] == 'absent'
        ? context.tr.marksAbsent
        : value['designation'] == 'exempt'
        ? context.tr.marksExempt
        : value['mentionId'] is String
        ? controller.mentionLabel(value['mentionId'] as String)
        : (value['score'] as num?)?.toString() ?? '—';
    String status(String value) => switch (value) {
      'approved' => context.tr.marksCorrectionApproved,
      'rejected' => context.tr.marksCorrectionRejected,
      'withdrawn' => context.tr.marksCorrectionWithdrawn,
      _ => context.tr.marksCorrectionPending,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.canRequestCorrection.value)
          FilledButton(
            onPressed: () => showLevitDialog<void>(
              context: context,
              builder: (_) => _CorrectionForm(controller: controller),
            ),
            child: Text(context.tr.marksRequestCorrection),
          ),
        for (final correction in controller.corrections.value)
          Padding(
            padding: const EdgeInsets.only(bottom: PrototypeSpacing.sm),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status(correction['status'] as String),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(correction['reason'] as String),
                  for (final change
                      in (correction['changes'] as List).cast<Map>()) ...[
                    Text(
                      '${name(change['studentId'] as String)}: ${display(change['before'] as Map)} → ${display(change['proposed'] as Map)}',
                    ),
                    if ((change['before'] as Map)['notes'] !=
                        (change['proposed'] as Map)['notes'])
                      Text(
                        '${context.tr.marksComment}: ${(change['before'] as Map)['notes'] ?? '—'} → ${(change['proposed'] as Map)['notes'] ?? '—'}',
                      ),
                  ],
                  if (correction['rejectionReason'] is String)
                    Text(correction['rejectionReason'] as String),
                  if ((correction['allowedActions'] as Map?)?['withdraw'] ==
                      true)
                    TextButton(
                      onPressed: () => showLevitDialog<void>(
                        context: context,
                        builder: (_) => _CorrectionForm(
                          controller: controller,
                          correction: correction,
                        ),
                      ),
                      child: Text(context.tr.workflowReviseCorrection),
                    ),
                  if ((correction['allowedActions'] as Map?)?['withdraw'] ==
                      true)
                    TextButton(
                      onPressed: () =>
                          controller.withdrawCorrection(correction),
                      child: Text(context.tr.marksWithdrawCorrection),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  });
}

class _CorrectionDraft {
  _CorrectionDraft(this.row)
    : score = TextEditingController(text: row.score?.toString() ?? ''),
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
  const _CorrectionForm({required this.controller, this.correction});
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
  bool busy = false;
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
      draft.score.text = (proposed['score'] as num?)?.toString() ?? '';
      draft.notes.text = proposed['notes'] as String? ?? '';
      draft.deadlineStatus =
          proposed['status'] as String? ?? draft.row.deadlineStatus;
    }
  }

  void changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final selected = rows.where((row) => row.selected).toList();
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.correction == null
            ? context.tr.marksRequestCorrection
            : context.tr.workflowReviseCorrection,
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr.marksCorrectionHint),
            for (final draft in rows) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: draft.selected,
                title: Text(draft.row.fullName),
                subtitle: Text(
                  '${context.tr.marksOriginal}: ${draft.row.designation == 'absent'
                      ? context.tr.marksAbsent
                      : draft.row.designation == 'exempt'
                      ? context.tr.marksExempt
                      : draft.row.mentionCode ?? draft.row.score?.toString() ?? '—'}',
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
                  decoration: InputDecoration(
                    labelText: context.tr.marksComment,
                  ),
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
                '${draft.row.fullName}: ${draft.row.mentionCode ?? draft.row.score?.toString() ?? draft.row.designation ?? '—'} → ${draft.designation == 'scored' ? (draft.mentionId == null ? draft.score.text : widget.controller.mentionLabel(draft.mentionId!)) : draft.designation} · ${draft.notes.text}',
              ),
            LWatch(() => Text(widget.controller.saveMessage.value)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: busy || selected.isEmpty || reason.text.trim().isEmpty
              ? null
              : () async {
                  setState(() => busy = true);
                  final success = await widget.controller.requestCorrection(
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
                  if (success) {
                    Navigator.pop(context);
                  } else {
                    setState(() => busy = false);
                  }
                },
          child: Text(context.tr.marksRequestCorrection),
        ),
      ],
    );
  }
}
