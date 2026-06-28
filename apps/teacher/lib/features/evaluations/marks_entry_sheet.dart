import 'package:edaya_ui/edaya_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'evaluations_controller.dart';
import 'models/evaluation_models.dart';

class MarksEntrySheet extends LScopedView<MarksEntryController> {
  const MarksEntrySheet({super.key, required this.evaluation});

  final EvaluationSummary evaluation;

  @override
  MarksEntryController onConfigScope(LevitScope scope) {
    return scope.put(() => MarksEntryController(evaluation: evaluation));
  }

  @override
  Widget buildView(BuildContext context, MarksEntryController controller) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: LWatch(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            evaluation.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${evaluation.classLabel} · ${evaluation.subjectLabel}',
                          ),
                          Text('Out of ${evaluation.maxScore}'),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (controller.errorMessage.value.isNotEmpty)
                  Text(
                    controller.errorMessage.value,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                if (controller.saveMessage.value.isNotEmpty)
                  Text(controller.saveMessage.value),
                const SizedBox(height: 8),
                Expanded(
                  child: controller.isBusy.value &&
                          controller.students.value.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          itemCount: controller.students.value.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final row = controller.students.value[index];
                            return _MarkRow(
                              key: ValueKey(row.studentId),
                              row: row,
                              maxScore: evaluation.maxScore,
                              onSave: (score) =>
                                  controller.saveScore(row, score),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkRow extends StatefulWidget {
  const _MarkRow({
    super.key,
    required this.row,
    required this.maxScore,
    required this.onSave,
  });

  final StudentMarkRow row;
  final double maxScore;
  final Future<bool> Function(double score) onSave;

  @override
  State<_MarkRow> createState() => _MarkRowState();
}

class _MarkRowState extends State<_MarkRow> {
  late final TextEditingController _scoreController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _scoreController = TextEditingController(
      text: widget.row.score?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            PersonAvatar(
              name: widget.row.studentName,
              initials: widget.row.studentInitials ?? '?',
              photoUrl: widget.row.photoUrl,
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.row.studentName),
                  if (widget.row.score != null)
                    Text(
                      'Current: ${widget.row.score}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 72,
              child: TextField(
                controller: _scoreController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '/ ${widget.maxScore}',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final score = double.tryParse(_scoreController.text.trim());
    if (score == null) {
      return;
    }
    setState(() => _saving = true);
    await widget.onSave(score);
    if (mounted) {
      setState(() => _saving = false);
    }
  }
}
