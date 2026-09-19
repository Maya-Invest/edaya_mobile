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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadMarks(evaluation);
      });
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: _MarksEntryContent(
            evaluation: evaluation,
            scrollController: scrollController,
          ),
        );
      },
    );
  }
}

class _MarksEntryContent extends StatefulWidget {
  const _MarksEntryContent({
    required this.evaluation,
    required this.scrollController,
  });

  final EvaluationSummary evaluation;
  final ScrollController scrollController;

  @override
  State<_MarksEntryContent> createState() => _MarksEntryContentState();
}

class _MarksEntryContentState extends State<_MarksEntryContent> {
  final _scoreControllers = <String, TextEditingController>{};
  final _focusNodes = <String, FocusNode>{};
  String? _loadedEvaluationId;
  var _ungradedOnly = false;

  @override
  void dispose() {
    for (final controller in _scoreControllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncControllers(List<StudentMarkRow> students) {
    if (_loadedEvaluationId == widget.evaluation.id) {
      return;
    }

    for (final controller in _scoreControllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _scoreControllers.clear();
    _focusNodes.clear();

    for (final row in students) {
      _scoreControllers[row.studentId] = TextEditingController(
        text: row.score?.toString() ?? '',
      );
      _focusNodes[row.studentId] = FocusNode();
    }
    _loadedEvaluationId = widget.evaluation.id;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.levit.find<EvaluationsController>();

    return LWatch(() {
      final isCurrentEvaluation =
          controller.marksEvaluationId.value == widget.evaluation.id;
      final students = isCurrentEvaluation
          ? controller.marksStudents.value
          : const <StudentMarkRow>[];
      final errorMessage = isCurrentEvaluation
          ? controller.marksErrorMessage.value
          : '';
      final saveMessage = isCurrentEvaluation
          ? controller.marksSaveMessage.value
          : '';
      final loading =
          controller.isBusy.value &&
          isCurrentEvaluation &&
          students.isEmpty &&
          errorMessage.isEmpty;

      if (students.isNotEmpty) {
        _syncControllers(students);
      }

      final visibleStudents = _ungradedOnly
          ? students.where((row) => row.score == null).toList()
          : students;

      return ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.evaluation.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${widget.evaluation.classLabel} · ${widget.evaluation.subjectLabel}',
                    ),
                    Text(
                      context.tr.outOfMaxScore(
                        widget.evaluation.maxScore.toString(),
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
          if (!loading && students.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(context.tr.ungradedOnlyFilter),
                  selected: _ungradedOnly,
                  onSelected: (value) => setState(() => _ungradedOnly = value),
                ),
                ActionChip(
                  label: Text(context.tr.fillAllMarks),
                  onPressed: () => _fillAll(controller, students),
                ),
                ActionChip(
                  label: Text(context.tr.clearAllMarks),
                  onPressed: () => _clearAll(students),
                ),
              ],
            ),
          ],
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
              onPressed: () => controller.loadMarks(widget.evaluation),
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
            if (visibleStudents.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(child: Text(context.tr.noStudentsToRecord)),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final useGrid = constraints.maxWidth >= 600;
                  if (!useGrid) {
                    return Column(
                      children: [
                        for (var index = 0; index < visibleStudents.length; index++) ...[
                          if (index > 0) const SizedBox(height: 8),
                          _markTile(visibleStudents[index], controller),
                        ],
                      ],
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 84,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: visibleStudents.length,
                    itemBuilder: (context, index) =>
                        _markTile(visibleStudents[index], controller),
                  );
                },
              ),
          ],
        ],
      );
    });
  }

  Widget _markTile(StudentMarkRow row, EvaluationsController controller) {
    return MarkRowTile(
      key: ValueKey(row.studentId),
      row: row,
      maxScore: widget.evaluation.maxScore,
      controller: _scoreControllers[row.studentId]!,
      focusNode: _focusNodes[row.studentId],
      onSubmitted: (score) => _saveScore(
        context,
        controller,
        row,
        score,
      ),
    );
  }

  void _fillAll(EvaluationsController controller, List<StudentMarkRow> students) {
    for (final row in students) {
      if (row.marksLocked) {
        continue;
      }
      _scoreControllers[row.studentId]?.text =
          widget.evaluation.maxScore.toString();
    }
  }

  void _clearAll(List<StudentMarkRow> students) {
    for (final row in students) {
      if (row.marksLocked) {
        continue;
      }
      _scoreControllers[row.studentId]?.clear();
    }
  }

  Future<void> _saveScore(
    BuildContext context,
    EvaluationsController controller,
    StudentMarkRow row,
    double score, {
    String? nextStudentId,
  }) async {
    if (score < 0 || score > widget.evaluation.maxScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr.invalidScoreValue(
              widget.evaluation.maxScore.toString(),
            ),
          ),
        ),
      );
      return;
    }

    final saved = await controller.saveMark(widget.evaluation, row, score);
    if (!context.mounted) {
      return;
    }

    if (saved) {
      if (nextStudentId != null) {
        _focusNodes[nextStudentId]?.requestFocus();
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(controller.marksSaveMessage.value),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
