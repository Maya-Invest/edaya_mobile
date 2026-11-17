import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../app/workspace_navigation.dart';
import 'live_marks_controller.dart';

String pupilResultLabel(
  BuildContext context,
  LiveMarksController c,
  Map value,
) {
  if (value['designation'] == 'absent') return context.tr.marksAbsent;
  if (value['designation'] == 'exempt') return context.tr.marksExempt;
  if (value['mentionId'] != null) {
    return c.mentionLabel(value['mentionId'] as String);
  }
  return value['score'] == null
      ? '—'
      : '${formatGradeNumber(value['score'] as num?)} / ${formatGradeNumber(c.evaluation.value?.maxScore ?? 20)}';
}

class PupilMarkCorrectionSheet extends StatefulWidget {
  const PupilMarkCorrectionSheet({
    super.key,
    required this.controller,
    required this.studentId,
    required this.close,
  });
  final LiveMarksController controller;
  final String studentId;
  final VoidCallback close;
  @override
  State<PupilMarkCorrectionSheet> createState() => _PupilMarkCorrectionState();
}

class _PupilMarkCorrectionState extends State<PupilMarkCorrectionSheet> {
  LiveMarksController get c => widget.controller;
  LiveMarkRow get row =>
      c.students.value.firstWhere((r) => r.studentId == widget.studentId);
  late final TextEditingController score, reason;
  late String designation;
  String? mention;
  late Map<String, dynamic> initialValues;
  bool dirty = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final pending = c.pendingFor(row);
    final proposed = pending == null
        ? null
        : (pending['changes'] as List).cast<Map>().firstWhere(
                (p) => p['resultId'] == row.resultId,
              )['proposed']
              as Map;
    initialValues = proposed == null
        ? {
            ...MarkDraft.fromRow(row).values,
            'notes': row.notes,
            'status': row.deadlineStatus,
          }
        : Map<String, dynamic>.from(proposed);
    score = TextEditingController(
      text: initialValues['score'] == null
          ? ''
          : formatGradeNumber(initialValues['score'] as num),
    );
    reason = TextEditingController(text: pending?['reason'] as String? ?? '');
    designation = initialValues['designation'] as String? ?? 'scored';
    mention = initialValues['mentionId'] as String?;
  }

  @override
  void dispose() {
    score.dispose();
    reason.dispose();
    super.dispose();
  }

  void changed() => setState(() {
    dirty = true;
    error = null;
  });
  Future<void> finish() async {
    setState(() {
      dirty = false;
      busy = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) widget.close();
  }

  @override
  Widget build(BuildContext context) => LWatch(() {
    final tr = context.tr;
    final pending = c.pendingFor(row);
    final grouped = pending != null && (pending['changes'] as List).length > 1;
    final allowed = c.canEditCorrection(row);
    return PopScope(
      canPop: !dirty && !busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop &&
            !busy &&
            await confirmWorkspaceDiscard(context) &&
            mounted) {
          await finish();
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(row.fullName, style: Theme.of(context).textTheme.titleLarge),
          Text(c.evaluation.value?.title ?? ''),
          const SizedBox(height: 16),
          Text(
            '${tr.gradebookOfficial} · ${pupilResultLabel(context, c, MarkDraft.fromRow(row).values)}',
          ),
          Text(tr.gradebookApproval),
          if (pending != null) Text(tr.gradebookPending),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: designation,
            decoration: InputDecoration(labelText: tr.gradebookProposed),
            items: [
              DropdownMenuItem(
                value: 'scored',
                child: Text(tr.gradebookResult),
              ),
              DropdownMenuItem(value: 'absent', child: Text(tr.marksAbsent)),
              DropdownMenuItem(value: 'exempt', child: Text(tr.marksExempt)),
            ],
            onChanged: allowed && !busy
                ? (value) {
                    designation = value!;
                    changed();
                  }
                : null,
          ),
          const SizedBox(height: 16),
          if (designation == 'scored') ...[
            if (c.mentionFirst)
              DropdownButtonFormField<String>(
                initialValue: c.mentions.any((m) => m['id'] == mention)
                    ? mention
                    : null,
                decoration: InputDecoration(labelText: tr.gradingMention),
                isExpanded: true,
                items: [
                  for (final m in c.mentions)
                    DropdownMenuItem(
                      value: m['id'] as String,
                      child: Text('${m['letter']} · ${m['interpretation']}'),
                    ),
                ],
                onChanged: allowed && !busy
                    ? (value) {
                        mention = value;
                        changed();
                      }
                    : null,
              )
            else
              TextField(
                key: const ValueKey('correction-score'),
                controller: score,
                enabled: allowed && !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: tr.gradebookProposed,
                  suffixText:
                      '/ ${formatGradeNumber(c.evaluation.value?.maxScore ?? 20)}',
                ),
                onChanged: (_) => changed(),
              ),
            const SizedBox(height: 16),
          ],
          if (grouped) Text(tr.gradebookGrouped),
          TextField(
            controller: reason,
            readOnly: grouped,
            enabled: allowed && !busy,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: tr.gradebookReason),
            onChanged: (_) => changed(),
          ),
          if (!allowed) Text(tr.gradebookLocked),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (c.saveMessage.value.isNotEmpty) Text(c.saveMessage.value),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: !allowed || busy || !dirty
                ? null
                : () async {
                    final draft = MarkDraft(
                      text: c.mentionFirst ? '' : score.text,
                      mentionId: c.mentionFirst ? mention : null,
                      designation: designation,
                    );
                    if (!c.completeDraft(draft) || reason.text.trim().isEmpty) {
                      setState(() => error = tr.gradebookInvalid);
                      return;
                    }
                    setState(() => busy = true);
                    final saved = await c.correctPupil(row, {
                      ...initialValues,
                      ...draft.values,
                    }, reason.text.trim());
                    if (!mounted) return;
                    if (saved) {
                      await finish();
                    } else {
                      setState(() => busy = false);
                    }
                  },
            child: Text(
              pending == null ? tr.gradebookSend : tr.gradebookUpdate,
            ),
          ),
          if ((pending?['allowedActions'] as Map?)?['withdraw'] == true)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialog) => AlertDialog(
                          title: Text(tr.gradebookWithdrawConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialog, false),
                              child: Text(tr.gradebookContinue),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dialog, true),
                              child: Text(tr.gradebookWithdraw),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !mounted) return;
                      setState(() => busy = true);
                      final saved = await c.withdrawPupil(row);
                      if (!mounted) return;
                      if (saved) {
                        await finish();
                      } else {
                        setState(() => busy = false);
                      }
                    },
              child: Text(tr.gradebookWithdraw),
            ),
        ],
      ),
    );
  });
}
