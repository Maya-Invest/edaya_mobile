import '../../design/workspace_layout.dart';
import 'package:edaya_shared/edaya_shared.dart';
import '../context/teacher_context_controller.dart';
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
    final embedded = ModalRoute.of(context) is ModalBottomSheetRoute;

    return PrototypeDetailScaffold(
      fallbackRoute: '/evaluations',
      title: context.tr.teacherTaskFamilyFeedback,
      embedded: embedded,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          for (final item in items) ...[
            ListRow(
              title: item.title,
              subtitle: item.subtitle,
              badge: item.open ? context.tr.inboxStatusNew : context.tr.archive,
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
    final embedded = ModalRoute.of(context) is ModalBottomSheetRoute;

    return PrototypeDetailScaffold(
      fallbackRoute: fromHome ? '/home' : '/evaluations/avis',
      title: item?.title ?? context.tr.feedback,
      embedded: embedded && !fromHome,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          Text(item?.subtitle ?? context.tr.resultNotFound),
          const SizedBox(height: PrototypeSpacing.md),
          Text(
            item?.open == true
                ? context.tr.newFeedbackIsAvailablePastFeedbackStaysUnder
                : context.tr.archivedResultsForThisCampaign,
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
      final tc = context.levit.find<TeacherContextController>();
      final selected = controller.results.value
          .where(
            (item) =>
                item.classGroupId == tc.activeAssignment?.classGroupId &&
                (item.classSubjectId == null ||
                    item.classSubjectId == tc.activeAssignment?.classSubjectId),
          )
          .toList();
      final unattributed = controller.results.value
          .where((item) => item.classGroupId == null)
          .toList();
      Widget tile(TeacherFamilyFeedbackResult item) => ListTile(
        title: Text(
          item.themes?.trim().isNotEmpty == true && !item.overallSuppressed
              ? item.themes!
              : context.tr.teacherTaskFamilyFeedback,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          context.tr.surveyResponseRatio(
            item.completedSlotCount,
            item.eligibleSlotCount,
          ),
        ),
        onTap: () => context.push('/evaluations/avis/${item.campaignId}'),
      );
      return ListView(
        children: [
          if (controller.errorMessage.value.isNotEmpty)
            TextButton(
              onPressed: controller.load,
              child: Text(controller.errorMessage.value),
            ),
          if (selected.isEmpty)
            ListTile(
              title: Text(context.tr.noFeedbackPublishedForThisClassAndSubject),
            ),
          for (final item in selected) tile(item),
          if (unattributed.isNotEmpty) ...[
            ListTile(title: Text(context.tr.noClassSpecified)),
            for (final item in unattributed) tile(item),
          ],
        ],
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
      final embedded = ModalRoute.of(context) is ModalBottomSheetRoute;
      return PrototypeDetailScaffold(
        fallbackRoute: fromHome ? '/home' : '/evaluations/avis',
        title: context.tr.teacherTaskFamilyFeedback,
        embedded: embedded && !fromHome,
        body: item == null
            ? EmptyState(
                title: context.tr.feedback,
                message: loader.controller.errorMessage.value.isEmpty
                    ? context.tr.loading
                    : loader.controller.errorMessage.value,
              )
            : ListView(
                padding: const EdgeInsets.all(PrototypeSpacing.md),
                children: [
                  WorkspaceColumns(
                    firstFraction: 0.4,
                    first: [
                      Text(
                        context.tr.surveyResponseRatio(
                          item.completedSlotCount,
                          item.eligibleSlotCount,
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: PrototypeSpacing.sm),
                      Text(
                        context.tr.responseRate(
                          (item.responseRate * 100).toStringAsFixed(0),
                        ),
                      ),
                      if (!item.overallSuppressed &&
                          item.themes != null &&
                          item.themes!.trim().isNotEmpty) ...[
                        const SizedBox(height: PrototypeSpacing.md),
                        Text(item.themes!),
                      ],
                      const SizedBox(height: PrototypeSpacing.lg),
                    ],
                    second: [
                      if (item.overallSuppressed)
                        Text(
                          context
                              .tr
                              .detailsAreHiddenUntilTheConfidentialityThresholdIs,
                        )
                      else
                        for (final question in item.questions) ...[
                          ListRow(
                            title: switch (question.questionId) {
                              'communication' =>
                                context.tr.feedbackCommunication,
                              'clarity' => context.tr.feedbackClarity,
                              'support' => context.tr.feedbackSupport,
                              'student_experience' =>
                                context.tr.feedbackExperience,
                              _ => context.tr.feedbackQuestion,
                            },
                            subtitle: question.suppressed
                                ? context.tr.confidentialityThreshold
                                : context.tr.responseCount(question.nScored),
                          ),
                          if (!question.suppressed)
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                for (final score
                                    in question.distribution.entries)
                                  Text('${score.key}/5 · ${score.value}'),
                                if (question.nCannotAssess > 0)
                                  Text(
                                    context.tr.cannotAssess(
                                      question.nCannotAssess,
                                    ),
                                  ),
                              ],
                            ),
                          const SizedBox(height: PrototypeSpacing.xs),
                        ],
                    ],
                  ),
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
