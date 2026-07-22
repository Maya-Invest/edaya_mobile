import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import 'report_card_controller.dart';

class ReportCardDetailPage extends LScopedView<ReportCardController> {
  const ReportCardDetailPage({super.key, required this.reportCardId});

  final String reportCardId;

  @override
  ReportCardController onConfigScope(LevitScope scope) {
    return scope.put(
      () => ReportCardController(
        scope.find<MockStore>(),
        reportCardId: reportCardId,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, ReportCardController controller) {
    return LWatch(() {
      controller.storeTick.value;
      final embedded = PrototypeBreakpoints.detailDrawerActive(context);
      final store = controller.store;
      final card = store.reportCardById(controller.reportCardId);
      if (card == null) {
        return PrototypeDetailScaffold(
          embedded: embedded,
          fallbackRoute: '/scolarite/notes',
          title: 'Bulletin',
          body: const EmptyState(title: 'Bulletin introuvable'),
        );
      }
      return PrototypeDetailScaffold(
        embedded: embedded,
        fallbackRoute: '/scolarite/notes',
        title: card.period,
        body: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Moyenne générale', style: Theme.of(context).textTheme.labelSmall),
                  Text(card.average, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: PrototypeSpacing.md),
                  Text('Appréciation', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(card.summary, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: PrototypeSpacing.md),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_outlined),
              label: const Text('Télécharger le PDF'),
            ),
          ],
        ),
      );
    });
  }
}
