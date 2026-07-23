import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import 'report_card_controller.dart';

class ReportCardDetailPage extends LScopedView<ReportCardController> {
  const ReportCardDetailPage({super.key, required this.reportCardId});

  final String reportCardId;

  @override
  ReportCardController onConfigScope(LevitScope scope) {
    return scope.put(
      () => ReportCardController(
        reportCardId: reportCardId,
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, ReportCardController controller) {
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);

    if (controller.isBusy.value && controller.detail.value == null) {
      return PrototypeDetailScaffold(
        embedded: embedded,
        fallbackRoute: '/scolarite/notes',
        title: 'Bulletin',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final card = controller.detail.value;
    if (card == null) {
      return PrototypeDetailScaffold(
        embedded: embedded,
        fallbackRoute: '/scolarite/notes',
        title: 'Bulletin',
        body: EmptyState(
          title: controller.errorMessage.value.isEmpty
              ? 'Bulletin introuvable'
              : controller.errorMessage.value,
        ),
      );
    }

    final averageLabel = card.overallAverage == null
        ? '—'
        : card.overallAverage!.toStringAsFixed(1).replaceAll('.', ',');

    return PrototypeDetailScaffold(
      embedded: embedded,
      fallbackRoute: '/scolarite/notes',
      title: card.periodName,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Moyenne générale',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  averageLabel,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: PrototypeColors.primary,
                  ),
                ),
                if ((card.teacherComment ?? '').isNotEmpty) ...[
                  const SizedBox(height: PrototypeSpacing.md),
                  Text(
                    'Appréciation',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.teacherComment!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if ((card.principalComment ?? '').isNotEmpty) ...[
                  const SizedBox(height: PrototypeSpacing.md),
                  Text(
                    'Direction',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.principalComment!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          for (final section in card.sections) ...[
            const SizedBox(height: PrototypeSpacing.md),
            SectionHeader(title: section.name),
            for (final subject in section.subjects) ...[
              ListRow(
                title: subject.name,
                trailing: Text(
                  subject.average.toStringAsFixed(1).replaceAll('.', ','),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: PrototypeColors.primary,
                  ),
                ),
                subtitle: subject.comment,
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
          ],
        ],
      ),
    );
  }
}
