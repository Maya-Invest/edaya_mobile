import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';
import 'family_feedback_controller.dart';

class FamilyFeedbackListPage extends StatelessWidget {
  const FamilyFeedbackListPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveFamilyFeedbackListPage();
    }
    return const _MockFamilyFeedbackListPage();
  }
}

class FamilyFeedbackDetailPage extends StatelessWidget {
  const FamilyFeedbackDetailPage({
    super.key,
    required this.feedbackId,
    this.fromHome = false,
  });

  final String feedbackId;
  final bool fromHome;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveFamilyFeedbackDetailPage(
        feedbackId: feedbackId,
        fromHome: fromHome,
      );
    }
    return _MockFamilyFeedbackDetailPage(
      feedbackId: feedbackId,
      fromHome: fromHome,
    );
  }
}

class _MockFamilyFeedbackListPage extends LScopedView<StoreBoundController> {
  const _MockFamilyFeedbackListPage();

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

class _MockFamilyFeedbackDetailPage extends LScopedView<StoreBoundController> {
  const _MockFamilyFeedbackDetailPage({
    required this.feedbackId,
    required this.fromHome,
  });

  final String feedbackId;
  final bool fromHome;

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
      fallbackRoute: fromHome ? '/home' : '/evaluations/avis',
      title: item?.title ?? 'Avis',
      embedded: embedded && !fromHome,
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

class _LiveFamilyFeedbackListPage extends LView<LiveFamilyFeedbackController> {
  const _LiveFamilyFeedbackListPage();

  @override
  Widget buildView(
    BuildContext context,
    LiveFamilyFeedbackController controller,
  ) {
    return LWatch(() {
      controller.results.value;
      controller.errorMessage.value;
      final embedded = PrototypeBreakpoints.detailDrawerActive(context);
      final items = controller.results.value;
      return PrototypeDetailScaffold(
        fallbackRoute: '/evaluations',
        title: 'Avis des familles',
        embedded: embedded,
        body: items.isEmpty
            ? EmptyState(
                title: 'Aucun avis',
                message: controller.errorMessage.value.isEmpty
                    ? 'Les retours familles de vos classes apparaîtront ici.'
                    : controller.errorMessage.value,
              )
            : ListView(
                padding: const EdgeInsets.all(PrototypeSpacing.md),
                children: [
                  for (final item in items) ...[
                    ListRow(
                      title: 'Avis des familles',
                      subtitle:
                          '${item.completedSlotCount}/${item.eligibleSlotCount} réponses',
                      badge:
                          controller.openResults.any(
                            (open) => open.campaignId == item.campaignId,
                          )
                          ? 'Nouveau'
                          : 'Archive',
                      badgeTone:
                          controller.openResults.any(
                            (open) => open.campaignId == item.campaignId,
                          )
                          ? SemanticTone.warning
                          : SemanticTone.info,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.go('/evaluations/avis/${item.campaignId}'),
                    ),
                    const SizedBox(height: PrototypeSpacing.xs),
                  ],
                ],
              ),
      );
    });
  }
}

class _LiveFamilyFeedbackDetailPage extends LScopedView<_FeedbackDetailLoader> {
  const _LiveFamilyFeedbackDetailPage({
    required this.feedbackId,
    required this.fromHome,
  });

  final String feedbackId;
  final bool fromHome;

  @override
  _FeedbackDetailLoader onConfigScope(LevitScope scope) {
    return scope.put(
      () => _FeedbackDetailLoader(
        feedbackId: feedbackId,
        controller: scope.find<LiveFamilyFeedbackController>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, _FeedbackDetailLoader loader) {
    return LWatch(() {
      loader.controller.results.value;
      loader.controller.errorMessage.value;
      loader.tick.value;
      final item = loader.controller.resultById(feedbackId);
      final embedded = PrototypeBreakpoints.detailDrawerActive(context);
      return PrototypeDetailScaffold(
        fallbackRoute: fromHome ? '/home' : '/evaluations/avis',
        title: 'Avis des familles',
        embedded: embedded && !fromHome,
        body: item == null
            ? EmptyState(
                title: 'Avis',
                message: loader.controller.errorMessage.value.isEmpty
                    ? 'Chargement…'
                    : loader.controller.errorMessage.value,
              )
            : ListView(
                padding: const EdgeInsets.all(PrototypeSpacing.md),
                children: [
                  Text(
                    '${item.completedSlotCount}/${item.eligibleSlotCount} réponses',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: PrototypeSpacing.sm),
                  Text(
                    'Taux de réponse · ${(item.responseRate * 100).toStringAsFixed(0)} %',
                  ),
                  if (item.themes != null &&
                      item.themes!.trim().isNotEmpty) ...[
                    const SizedBox(height: PrototypeSpacing.md),
                    Text(item.themes!),
                  ],
                  const SizedBox(height: PrototypeSpacing.lg),
                  if (item.overallSuppressed)
                    const Text(
                      'Les détails sont masqués tant que le seuil de confidentialité n\'est pas atteint.',
                    )
                  else
                    for (final question in item.questions) ...[
                      ListRow(
                        title: question.questionId,
                        subtitle: question.suppressed
                            ? 'Seuil de confidentialité'
                            : '${question.nScored} réponses',
                      ),
                      const SizedBox(height: PrototypeSpacing.xs),
                    ],
                ],
              ),
      );
    });
  }
}

class _FeedbackDetailLoader extends LevitController {
  _FeedbackDetailLoader({required this.feedbackId, required this.controller});

  final String feedbackId;
  final LiveFamilyFeedbackController controller;
  final tick = LxVar(0);

  @override
  void onInit() {
    super.onInit();
    autoDispose(tick);
    unawaited(_load());
  }

  Future<void> _load() async {
    await controller.loadDetail(feedbackId);
    tick.value++;
  }
}
