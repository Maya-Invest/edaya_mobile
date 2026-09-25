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
        : (value['score'] as num?)?.toStringAsFixed(2) ?? '—';
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
    : score = TextEditingController(text: row.score?.toStringAsFixed(2) ?? ''),
      notes = TextEditingController(text: row.notes ?? ''),
      designation = row.designation ?? 'scored';
  final LiveMarkRow row;
  final TextEditingController score;
  final TextEditingController notes;
  String designation;
  bool selected = false;
  void dispose() {
    score.dispose();
    notes.dispose();
  }

  Map<String, dynamic> get proposed => {
    'score': designation == 'scored'
        ? double.tryParse(score.text.trim().replaceAll(',', '.'))
        : null,
    'designation': designation,
    'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
  };
}

class _CorrectionForm extends StatefulWidget {
  const _CorrectionForm({required this.controller});
  final LiveMarksController controller;
  @override
  State<_CorrectionForm> createState() => _CorrectionFormState();
}

class _CorrectionFormState extends State<_CorrectionForm> {
  late final rows = widget.controller.students.value
      .where((row) => !row.published && row.resultId != null)
      .map(_CorrectionDraft.new)
      .toList();
  final reason = TextEditingController();
  bool confirmed = false;
  bool busy = false;
  @override
  void dispose() {
    for (final row in rows) {
      row.dispose();
    }
    reason.dispose();
    super.dispose();
  }

  void changed() => setState(() => confirmed = false);

  @override
  Widget build(BuildContext context) {
    final selected = rows.where((row) => row.selected).toList();
    return AlertDialog(
      scrollable: true,
      title: Text(context.tr.marksRequestCorrection),
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
                      : draft.row.score?.toStringAsFixed(2) ?? '—'}',
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
                if (draft.designation == 'scored')
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
                '${draft.row.fullName}: ${draft.row.score?.toStringAsFixed(2) ?? draft.row.designation ?? '—'} → ${draft.designation == 'scored' ? draft.score.text : draft.designation} · ${draft.notes.text}',
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: confirmed,
              title: Text(context.tr.marksCorrectionConfirm),
              onChanged: busy
                  ? null
                  : (value) => setState(() => confirmed = value ?? false),
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
          onPressed:
              busy ||
                  !confirmed ||
                  selected.isEmpty ||
                  reason.text.trim().isEmpty
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
