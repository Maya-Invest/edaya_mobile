import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../evaluations/evaluations_controller.dart';
import 'models/report_card_summary.dart';

class ReportCardDetailsDialog extends LScopedView<ReportCardDetailsController> {
  const ReportCardDetailsDialog({super.key, required this.reportCard});

  final ReportCardSummary reportCard;

  @override
  ReportCardDetailsController onConfigScope(LevitScope scope) {
    return scope.put(
      () => ReportCardDetailsController(
        reportCardId: reportCard.id,
        periodName: reportCard.periodName,
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    ReportCardDetailsController controller,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: LWatch(() {
          if (controller.isBusy.value && controller.detail.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final error = controller.errorMessage.value;
          if (error.isNotEmpty) {
            return Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            );
          }

          final detail = controller.detail.value;
          if (detail == null) {
            return Text(context.tr.reportCardNotFound);
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        detail.periodName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close),
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    ),
                  ],
                ),
                if (detail.publishedAt != null)
                  Text(
                    context.tr.publishedOn(
                      context.formatLongDate(detail.publishedAt!),
                    ),
                  ),
                const SizedBox(height: 16),
                if (detail.overallAverage != null)
                  Text(
                    context.tr.overallAverage(
                      detail.overallAverage!.toStringAsFixed(1),
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                if (detail.rank != null && detail.classSize != null)
                  Text(context.tr.classRank(detail.rank!, detail.classSize!)),
                if (detail.teacherComment != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    context.tr.homeroomComment,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(detail.teacherComment!),
                ],
                if (detail.principalComment != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    context.tr.principalComment,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(detail.principalComment!),
                ],
                const SizedBox(height: 16),
                for (final section in detail.sections) ...[
                  Text(
                    section.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final subject in section.subjects)
                    Card(
                      child: ListTile(
                        title: Text(subject.name),
                        subtitle: subject.comment == null
                            ? null
                            : Text(subject.comment!),
                        trailing: Text(
                          subject.average.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}
