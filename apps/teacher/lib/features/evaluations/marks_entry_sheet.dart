import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'evaluations_controller.dart';
import 'models/evaluation_models.dart';
import 'widgets/mark_row_tile.dart';

class MarksEntrySheet extends LView<EvaluationsController> {
  const MarksEntrySheet({super.key, required this.evaluation});

  final EvaluationSummary evaluation;

  @override
  Widget buildView(BuildContext context, EvaluationsController controller) {
    if (controller.marksEvaluationId.value != evaluation.id) {
      unawaited(controller.loadMarks(evaluation));
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: LWatch(
            () => _buildContent(
              context,
              scrollController,
              controller,
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    ScrollController scrollController,
    EvaluationsController controller,
  ) {
    final isCurrentEvaluation =
        controller.marksEvaluationId.value == evaluation.id;
    final students = isCurrentEvaluation
        ? controller.marksStudents.value
        : const <StudentMarkRow>[];
    final errorMessage = isCurrentEvaluation
        ? controller.marksErrorMessage.value
        : '';
    final saveMessage =
        isCurrentEvaluation ? controller.marksSaveMessage.value : '';
    final loading = controller.isBusy.value &&
        isCurrentEvaluation &&
        students.isEmpty &&
        errorMessage.isEmpty;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                  Text(
                    context.tr.outOfMaxScore(
                      evaluation.maxScore.toString(),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        if (loading) ...[
          const SizedBox(height: 32),
          const Center(child: CircularProgressIndicator()),
        ],
        if (errorMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            errorMessage,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: () => controller.loadMarks(evaluation),
            child: Text(context.tr.retry),
          ),
        ],
        if (saveMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            saveMessage,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (!loading &&
            students.isNotEmpty &&
            students.every((row) => row.marksLocked)) ...[
          const SizedBox(height: 12),
          Text(
            context.tr.marksEntryPeriodLockedHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        if (!loading) ...[
          const SizedBox(height: 16),
          if (students.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(child: Text(context.tr.noStudentsToRecord)),
            )
          else
            for (var index = 0; index < students.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              MarkRowTile(
                key: ValueKey(students[index].studentId),
                row: students[index],
                onEditScore: () =>
                    _editScore(context, controller, students[index]),
              ),
            ],
        ],
      ],
    );
  }

  Future<void> _editScore(
    BuildContext context,
    EvaluationsController controller,
    StudentMarkRow row,
  ) async {
    final score = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return _ScoreEntryDialog(
          studentName: row.studentName,
          initialScore: row.score?.toString() ?? '',
          maxScoreLabel: context.tr.outOfMaxScore(
            evaluation.maxScore.toString(),
          ),
          scoreHint: context.tr.scoreHintOutOf(
            evaluation.maxScore.toString(),
          ),
          saveLabel: context.tr.save,
        );
      },
    );

    if (!context.mounted || score == null) {
      return;
    }

    final saved = await controller.saveMark(evaluation, row, score);
    if (!context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    if (saved) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr.save)),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(controller.marksSaveMessage.value),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _ScoreEntryDialog extends StatefulWidget {
  const _ScoreEntryDialog({
    required this.studentName,
    required this.initialScore,
    required this.maxScoreLabel,
    required this.scoreHint,
    required this.saveLabel,
  });

  final String studentName;
  final String initialScore;
  final String maxScoreLabel;
  final String scoreHint;
  final String saveLabel;

  @override
  State<_ScoreEntryDialog> createState() => _ScoreEntryDialogState();
}

class _ScoreEntryDialogState extends State<_ScoreEntryDialog> {
  late final TextEditingController _scoreController;

  @override
  void initState() {
    super.initState();
    _scoreController = TextEditingController(text: widget.initialScore);
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.studentName),
      content: TextField(
        controller: _scoreController,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.maxScoreLabel,
          hintText: widget.scoreHint,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }

  void _submit() {
    final parsed = double.tryParse(_scoreController.text.trim());
    if (parsed == null) {
      return;
    }
    Navigator.of(context).pop(parsed);
  }
}
