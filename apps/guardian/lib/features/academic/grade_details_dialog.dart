import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'academic_controller.dart';
import 'models/grade_entry.dart';

class GradeDetailsDialog extends LScopedView<GradeDetailsController> {
  const GradeDetailsDialog({super.key, required this.entry});

  final GradeEntry entry;

  @override
  GradeDetailsController onConfigScope(LevitScope scope) {
    return scope.put(() => GradeDetailsController(entry: entry));
  }

  @override
  Widget buildView(BuildContext context, GradeDetailsController controller) {
    final entry = controller.entry;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(entry.subjectName),
            Text('${entry.periodName} · Coefficient ${entry.coefficient.toStringAsFixed(0)}'),
            if (entry.date != null)
              Text(formatLongDate(entry.date!)),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Score'),
              trailing: Text(
                entry.hasScore
                    ? '${entry.score!.toStringAsFixed(1)} / ${entry.maxScore.toStringAsFixed(0)}'
                    : 'Not graded yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (entry.notes != null && entry.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(entry.notes!),
            ],
          ],
        ),
      ),
    );
  }
}
