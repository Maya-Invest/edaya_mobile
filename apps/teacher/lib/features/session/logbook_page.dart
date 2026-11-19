import 'dart:async';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'session_logbook_draft_storage.dart';

/// A single sheet edits either the lesson note or one programme chapter.
class LogbookForm extends StatefulWidget {
  const LogbookForm({
    super.key,
    required this.initial,
    required this.onSave,
    required this.onDraft,
    required this.close,
    this.choices = const {},
    this.chapterValue,
    this.validated = false,
  });
  final LogbookEdit? initial;
  final Map<String, String> choices;
  final LogbookEdit Function(String)? chapterValue;
  final bool validated;
  final Future<String?> Function(LogbookEdit) onSave;
  final Future<void> Function(LogbookEdit) onDraft;
  final VoidCallback close;
  @override
  State<LogbookForm> createState() => _LogbookFormState();
}

class _LogbookFormState extends State<LogbookForm> {
  late final TextEditingController content,
      objectives,
      homework,
      family,
      reason,
      chapterNotes;
  String? chapterId;
  bool completed = false;
  bool removed = false;
  bool saving = false;
  String? error;
  bool get general => widget.initial?.note != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.initial;
    final note = edit?.note;
    content = TextEditingController(text: note?.content);
    objectives = TextEditingController(text: note?.objectives.join('\n'));
    homework = TextEditingController(text: note?.homework);
    family = TextEditingController(text: note?.familySummary);
    reason = TextEditingController(text: edit?.reason);
    chapterNotes = TextEditingController(text: edit?.chapterNotes);
    chapterId = edit?.chapterId;
    completed = edit?.completed ?? false;
    removed = edit?.removed ?? false;
  }

  @override
  void dispose() {
    for (final field in [
      content,
      objectives,
      homework,
      family,
      reason,
      chapterNotes,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  LogbookEdit get edit => general
      ? LogbookEdit.general(
          StructuredLogbookContent(
            content: content.text,
            objectives: objectives.text
                .split('\n')
                .where((s) => s.trim().isNotEmpty)
                .toList(),
            homework: homework.text,
            familySummary: family.text,
          ),
          reason: reason.text,
        )
      : LogbookEdit.chapter(
          chapterId!,
          completed,
          removed: removed,
          chapterNotes: chapterNotes.text,
          reason: reason.text,
        );

  void changed() {
    if (saving) return;
    setState(() => error = null);
    if (general || chapterId != null) unawaited(widget.onDraft(edit));
  }

  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final failure = await widget.onSave(edit);
      if (!mounted) return;
      if (failure == null) {
        widget.close();
      } else {
        setState(() => error = failure);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tr;
    Widget field(String label, TextEditingController controller, int lines) =>
        TextField(
          controller: controller,
          enabled: !saving,
          maxLines: lines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => changed(),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.initial?.needsReview == true) Text(t.logbookReviewDraft),
        if (general) ...[
          field(t.rollContent, content, 3),
          const SizedBox(height: 12),
          field(t.rollObjectives, objectives, 2),
          const SizedBox(height: 12),
          field(t.rollHomework, homework, 2),
          const SizedBox(height: 12),
          field(t.rollFamilySummary, family, 2),
        ] else ...[
          if (widget.initial == null)
            DropdownButtonFormField<String>(
              initialValue: chapterId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: t.chapterLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final item in widget.choices.entries)
                  DropdownMenuItem(value: item.key, child: Text(item.value)),
              ],
              onChanged: saving
                  ? null
                  : (id) {
                      if (id == null) return;
                      final value = widget.chapterValue!(id);
                      setState(() {
                        chapterId = id;
                        completed = value.completed!;
                        removed = value.removed;
                        chapterNotes.text = value.chapterNotes ?? '';
                        reason.text = value.reason;
                        error = null;
                      });
                    },
            )
          else
            Text(
              widget.choices[chapterId] ?? t.chapterFallback,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          if (chapterId != null) ...[
            const SizedBox(height: 12),
            CheckboxListTile(
              title: Text(t.logbookFinishedHere),
              value: completed,
              onChanged: saving || removed
                  ? null
                  : (v) {
                      completed = v ?? false;
                      changed();
                    },
            ),
            const SizedBox(height: 12),
            field(t.matterNotesLabel, chapterNotes, 2),
            if (widget.initial?.chapterId != null)
              CheckboxListTile(
                title: Text(t.logbookRemoveChapter),
                value: removed,
                onChanged: saving
                    ? null
                    : (v) {
                        removed = v ?? false;
                        changed();
                      },
              ),
          ],
        ],
        if (widget.validated) ...[
          const SizedBox(height: 12),
          field(t.marksCorrectionReason, reason, 2),
        ],
        if (error != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed:
                saving ||
                    (!general && chapterId == null) ||
                    (widget.validated && reason.text.trim().isEmpty)
                ? null
                : save,
            child: Text(
              widget.validated ? t.workflowRequestCorrection : t.save,
            ),
          ),
        ),
      ],
    );
  }
}
