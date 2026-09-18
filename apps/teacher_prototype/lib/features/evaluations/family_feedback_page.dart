import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';

class FamilyFeedbackListPage extends LScopedView<StoreBoundController> {
  const FamilyFeedbackListPage({super.key});

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final items = controller.store.familyFeedback;
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);

    return PrototypeDetailScaffold(
      fallbackRoute: '/evaluations',
      title: 'Avis des familles',
      embedded: embedded,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          for (final item in items) ...[
            ListRow(
              title: item.title,
              subtitle: item.subtitle,
              badge: item.open ? 'Nouveau' : 'Archive',
              badgeTone: item.open ? SemanticTone.warning : SemanticTone.info,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/evaluations/avis/${item.id}'),
            ),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class FamilyFeedbackDetailPage extends LScopedView<StoreBoundController> {
  const FamilyFeedbackDetailPage({super.key, required this.feedbackId});

  final String feedbackId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final item = controller.store.familyFeedbackById(feedbackId);
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);

    return PrototypeDetailScaffold(
      fallbackRoute: '/evaluations/avis',
      title: item?.title ?? 'Avis',
      embedded: embedded,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          Text(item?.subtitle ?? 'Résultat introuvable'),
          const SizedBox(height: PrototypeSpacing.md),
          Text(
            item?.open == true
                ? 'Nouveaux retours à consulter. L\'archive reste dans Évaluations.'
                : 'Résultat archivé pour cette campagne.',
          ),
        ],
      ),
    );
  }
}
