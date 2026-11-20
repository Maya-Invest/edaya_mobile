import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../context/student_context_controller.dart';

class GuardianFamilyFeedbackController extends LevitController
    with LevitReactiveTasksMixin {
  GuardianFamilyFeedbackController({
    required StudentContextController studentContext,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _schoolClient = schoolClient;

  final StudentContextController _studentContext;
  final SchoolClientFactory _schoolClient;

  final campaigns = LxVar<List<GuardianFamilyFeedbackCampaign>>(const []);
  final errorMessage = LxVar('');

  GuardianPupilSelection? _selection;
  Future<void>? _pending;
  int _generation = 0;

  @override
  void onInit() {
    super.onInit();
    autoDispose(campaigns);
    autoDispose(errorMessage);
    for (final changes in [
      _studentContext.activeStudent.stream,
      _studentContext.isLoading.stream,
      _studentContext.linkedStudentsResolved.stream,
    ]) {
      autoDispose(changes.listen((_) => unawaited(_loadSelection())));
    }
    unawaited(_loadSelection());
  }

  DataStatus get dataStatus {
    if (isBusy.value && campaigns.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && campaigns.value.isEmpty) {
      return DataStatus.error;
    }
    if (campaigns.value.isEmpty) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String emptyMessage(BuildContext context) => context.tr.familyFeedbackEmpty;

  Future<void> loadCampaigns() => _loadSelection(refresh: true);

  Future<void> _loadSelection({bool refresh = false}) {
    final selection = _studentContext.verifiedSelection;
    final changed = _selection != selection;
    if (!changed && (!refresh || _pending != null)) {
      return _pending ?? Future.value();
    }
    final generation = ++_generation;
    _selection = selection;
    _pending = null;
    errorMessage('');
    if (changed) campaigns(const []);
    if (selection == null) return Future.value();
    bool current() =>
        !isClosed &&
        generation == _generation &&
        selection == _studentContext.verifiedSelection;
    return _pending =
        runTask(() async {
          try {
            final items = await listGuardianFamilyFeedbackCampaigns(
              _schoolClient(),
              studentId: selection.studentId,
            );
            if (current()) campaigns(items);
          } on Object catch (error) {
            if (current()) errorMessage(error.toString());
          }
        }).whenComplete(() {
          if (generation == _generation) _pending = null;
        });
  }
}

class GuardianFamilyFeedbackPage
    extends LScopedView<GuardianFamilyFeedbackController> {
  const GuardianFamilyFeedbackPage({super.key});

  @override
  GuardianFamilyFeedbackController onConfigScope(LevitScope scope) {
    return scope.put(
      () => GuardianFamilyFeedbackController(
        studentContext: scope.find<StudentContextController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    GuardianFamilyFeedbackController controller,
  ) {
    return LWatch(
      () => DataState(
        status: controller.dataStatus,
        errorMessage: controller.errorMessage.value,
        emptyMessage: controller.emptyMessage(context),
        onRetry: controller.loadCampaigns,
        child: RefreshIndicator(
          onRefresh: controller.loadCampaigns,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: controller.campaigns.value.length,
            itemBuilder: (context, index) {
              final item = controller.campaigns.value[index];
              return Card(
                child: ListTile(
                  title: Text(
                    item.context?.subjectName.isNotEmpty == true
                        ? '${item.context!.subjectName} · ${item.context!.teacherName}'
                        : context.tr.familyFeedbackTitle,
                  ),
                  subtitle: Text(
                    item.slotState == 'completed' ||
                            item.slotState == 'already_completed'
                        ? context.tr.familyFeedbackSlotCompleted
                        : item.slotState == 'open'
                        ? context.tr.familyFeedbackSlotOpen
                        : context.tr.familyFeedbackClosed,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/inbox/avis/${item.campaignId}',
                    extra: item,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class GuardianFamilyFeedbackQuestionnaireArgs {
  const GuardianFamilyFeedbackQuestionnaireArgs({
    required this.campaignId,
    required this.studentId,
  });

  final String campaignId;
  final String studentId;
}

class GuardianFamilyFeedbackQuestionnaireController extends LevitController
    with LevitReactiveTasksMixin {
  GuardianFamilyFeedbackQuestionnaireController({
    required this.questionnaireArgs,
    required SchoolClientFactory schoolClient,
  }) : _schoolClient = schoolClient;

  final GuardianFamilyFeedbackQuestionnaireArgs questionnaireArgs;
  final SchoolClientFactory _schoolClient;

  final questionnaire = LxVar<GuardianFamilyFeedbackQuestionnaire?>(null);
  final answers = LxVar<Map<String, Object>>({});
  final comment = LxVar('');
  final errorMessage = LxVar('');
  final submitted = LxVar(false);

  @override
  void onInit() {
    super.onInit();
    autoDispose(questionnaire);
    autoDispose(answers);
    autoDispose(comment);
    autoDispose(errorMessage);
    autoDispose(submitted);
    unawaited(load());
  }

  DataStatus get dataStatus {
    if (isBusy.value && questionnaire.value == null) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && questionnaire.value == null) {
      return DataStatus.error;
    }
    return DataStatus.ready;
  }

  String? _language;

  void showInLanguage(String language) {
    if (_language == language) return;
    _language = language;
    scheduleMicrotask(() {
      if (!isClosed && _language == language) unawaited(load());
    });
  }

  Future<void> load() async {
    final language = _language ?? systemL10n().localeName;
    _language = language;
    errorMessage('');
    await runTask(() async {
      try {
        final result = await getGuardianFamilyFeedbackQuestionnaire(
          _schoolClient(),
          campaignId: questionnaireArgs.campaignId,
          studentId: questionnaireArgs.studentId,
          locale: language,
        );
        if (!isClosed && _language == language) questionnaire(result);
      } catch (error) {
        if (!isClosed && _language == language) errorMessage(error.toString());
      }
    });
  }

  Future<void> submit() async {
    final current = questionnaire.value;
    if (current == null || !current.isOpen) {
      return;
    }
    errorMessage('');
    await runTask(() async {
      try {
        await submitFamilyFeedbackResponse(
          _schoolClient(),
          campaignId: questionnaireArgs.campaignId,
          studentId: questionnaireArgs.studentId,
          answers: answers.value,
          comment: comment.value,
        );
        submitted(true);
        await load();
      } catch (error) {
        errorMessage(error.toString());
      }
    });
  }
}

class GuardianFamilyFeedbackQuestionnairePage
    extends LScopedView<GuardianFamilyFeedbackQuestionnaireController> {
  const GuardianFamilyFeedbackQuestionnairePage({
    super.key,
    required this.questionnaireArgs,
  });

  final GuardianFamilyFeedbackQuestionnaireArgs questionnaireArgs;

  @override
  GuardianFamilyFeedbackQuestionnaireController onConfigScope(
    LevitScope scope,
  ) {
    return scope.put(
      () => GuardianFamilyFeedbackQuestionnaireController(
        questionnaireArgs: questionnaireArgs,
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    GuardianFamilyFeedbackQuestionnaireController controller,
  ) {
    controller.showInLanguage(context.tr.localeName);
    return PrototypeDetailScaffold(
      fallbackRoute: '/inbox/avis',
      title: context.tr.familyFeedbackTitle,
      body: LWatch(
        () => DataState(
          status: controller.dataStatus,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          child: _QuestionnaireBody(controller: controller),
        ),
      ),
    );
  }
}

class _QuestionnaireBody extends StatelessWidget {
  const _QuestionnaireBody({required this.controller});

  final GuardianFamilyFeedbackQuestionnaireController controller;

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final data = controller.questionnaire.value;
      if (data == null) {
        return const SizedBox.shrink();
      }
      if (data.isCompleted ||
          data.isAlreadyCompleted ||
          controller.submitted.value) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (data.context != null) ...[
              Text(data.context!.summary),
              const SizedBox(height: 12),
            ],
            Text(
              data.isAlreadyCompleted
                  ? context.tr.familyFeedbackAlreadyCompleted
                  : context.tr.familyFeedbackSubmitted,
            ),
            const SizedBox(height: 8),
            Text(context.tr.familyFeedbackConfidential),
          ],
        );
      }
      if (!data.isOpen) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (data.context != null) ...[
              Text(data.context!.summary),
              const SizedBox(height: 12),
            ],
            Text(context.tr.familyFeedbackClosed),
          ],
        );
      }
      final instrument = data.instrument;
      if (instrument == null) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [Text(context.tr.familyFeedbackClosed)],
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (data.context != null) ...[
            Text(
              data.context!.summary,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
          ],
          Text(instrument.intro),
          const SizedBox(height: 8),
          Text(instrument.confidentialityNotice),
          const SizedBox(height: 8),
          Text(instrument.scaleHelper),
          const SizedBox(height: 12),
          for (final item in instrument.items) ...[
            Text(item.stem, style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                for (final score in [1, 2, 3, 4, 5])
                  ChoiceChip(
                    key: ValueKey('feedback-${item.id}-$score'),
                    label: Text(instrument.scaleLabels['$score'] ?? '$score'),
                    selected: controller.answers.value[item.id] == score,
                    onSelected: (_) {
                      controller.answers({
                        ...controller.answers.value,
                        item.id: score,
                      });
                    },
                  ),
                ChoiceChip(
                  label: Text(
                    instrument.scaleLabels['cannot_assess'] ??
                        context.tr.familyFeedbackCannotAssess,
                  ),
                  selected:
                      controller.answers.value[item.id] == 'cannot_assess',
                  onSelected: (_) {
                    controller.answers({
                      ...controller.answers.value,
                      item.id: 'cannot_assess',
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            decoration: InputDecoration(
              labelText: context.tr.familyFeedbackComment,
              helperText: instrument.commentPrompt,
              helperMaxLines: 4,
            ),
            maxLines: 4,
            onChanged: controller.comment.call,
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('feedback-submit'),
            onPressed:
                controller.answers.value.length == instrument.items.length
                ? controller.submit
                : null,
            child: Text(context.tr.familyFeedbackSubmit),
          ),
        ],
      );
    });
  }
}
