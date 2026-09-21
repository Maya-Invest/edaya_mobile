import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';
import 'report_card_controller.dart';

class ReportCardDetailPage extends StatelessWidget {
  const ReportCardDetailPage({super.key, required this.reportCardId});

  final String reportCardId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveReportCardDetailPage(reportCardId: reportCardId);
    }
    return _MockReportCardDetailPage(reportCardId: reportCardId);
  }
}

class _MockReportCardDetailPage extends LScopedView<StoreBoundController> {
  const _MockReportCardDetailPage({required this.reportCardId});

  final String reportCardId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final card = controller.store.reportCardById(reportCardId);
    if (card == null) {
      return const PrototypeDetailScaffold(
        fallbackRoute: '/scolarite/notes',
        title: 'Bulletin',
        body: EmptyState(title: 'Bulletin introuvable'),
      );
    }
    final periodResults = controller.store.subjectResultsForPeriod(card.period);
    return PrototypeDetailScaffold(
      fallbackRoute: '/scolarite/notes',
      title: card.period,
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
                  card.average,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: PrototypeColors.primary,
                  ),
                ),
                const SizedBox(height: PrototypeSpacing.md),
                Text(
                  'Appréciation',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  card.summary,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          const SectionHeader(title: 'Matières'),
          for (final result in periodResults) ...[
            ListRow(
              title: result.subject,
              trailing: Text(
                result.averageLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: PrototypeColors.primary,
                ),
              ),
              subtitle: result.teacherComment,
            ),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _LiveReportCardDetailPage extends LScopedView<ReportCardController> {
  const _LiveReportCardDetailPage({required this.reportCardId});

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
    if (controller.isBusy.value && controller.detail.value == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/scolarite/notes',
        title: 'Bulletin',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final card = controller.detail.value;
    if (card == null) {
      return PrototypeDetailScaffold(
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

    final downloading =
        controller.downloadStatus.value == ReportCardPdfStatus.downloading;
    final downloadHint = controller.downloadMessage.value;

    return PrototypeDetailScaffold(
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
          const SizedBox(height: PrototypeSpacing.md),
          FilledButton.icon(
            onPressed: downloading ? null : controller.downloadPdf,
            icon: downloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            label: Text(downloading ? 'Téléchargement…' : 'Télécharger le PDF'),
          ),
          if (downloadHint.isNotEmpty) ...[
            const SizedBox(height: PrototypeSpacing.sm),
            Text(
              downloadHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    controller.downloadStatus.value ==
                        ReportCardPdfStatus.failed
                    ? PrototypeColors.error
                    : null,
              ),
            ),
          ],
          for (final section in card.sections) ...[
            const SizedBox(height: PrototypeSpacing.md),
            SectionHeader(title: section.name),
            for (final subject in section.subjects) ...[
              ListRow(
                title: subject.name,
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      subject.average.toStringAsFixed(1).replaceAll('.', ','),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: PrototypeColors.primary,
                      ),
                    ),
                    if (subject.rank != null && card.classSize != null)
                      Text(
                        '${subject.rank}/${card.classSize}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: PrototypeColors.onSurfaceVariant,
                        ),
                      ),
                  ],
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
