import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

class TeacherFamilyFeedbackController extends LevitController
    with LevitReactiveTasksMixin {
  TeacherFamilyFeedbackController({required SchoolClientFactory schoolClient})
      : _schoolClient = schoolClient;

  final SchoolClientFactory _schoolClient;

  final results = LxVar<List<TeacherFamilyFeedbackResult>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(results);
    autoDispose(errorMessage);
    unawaited(load());
  }

  DataStatus get dataStatus {
    if (isBusy.value && results.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && results.value.isEmpty) {
      return DataStatus.error;
    }
    if (results.value.isEmpty) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  Future<void> load() async {
    errorMessage('');
    await runTask(() async {
      try {
        results(await listTeacherFamilyFeedbackResults(_schoolClient()));
      } catch (error) {
        errorMessage(error.toString());
        results(const []);
      }
    });
  }
}

class TeacherFamilyFeedbackPage extends LScopedView<TeacherFamilyFeedbackController> {
  const TeacherFamilyFeedbackPage({super.key});

  @override
  TeacherFamilyFeedbackController onConfigScope(LevitScope scope) {
    return scope.put(
      () => TeacherFamilyFeedbackController(
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, TeacherFamilyFeedbackController controller) {
    return LWatch(
      () => DataState(
        status: controller.dataStatus,
        errorMessage: controller.errorMessage.value,
        emptyMessage: context.tr.familyFeedbackEmpty,
        onRetry: controller.load,
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: controller.results.value.length,
            itemBuilder: (context, index) {
              final item = controller.results.value[index];
              return Card(
                child: ListTile(
                  title: Text(context.tr.familyFeedbackTitle),
                  subtitle: Text(
                    item.overallSuppressed
                        ? context.tr.familyFeedbackInsufficient
                        : '${(item.responseRate * 100).round()}%',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/teaching/family-feedback/${item.campaignId}',
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

class TeacherFamilyFeedbackResultPage extends StatelessWidget {
  const TeacherFamilyFeedbackResultPage({super.key, required this.result});

  final TeacherFamilyFeedbackResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr.familyFeedbackTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.tr.familyFeedbackConfidential),
          const SizedBox(height: 12),
          if (result.overallSuppressed)
            Text(context.tr.familyFeedbackInsufficient)
          else ...[
            for (final question in result.questions)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question.questionId, style: Theme.of(context).textTheme.titleSmall),
                    if (question.suppressed)
                      Text(context.tr.familyFeedbackInsufficient)
                    else
                      Text('1–5: ${question.distribution[1]}/${question.distribution[2]}/${question.distribution[3]}/${question.distribution[4]}/${question.distribution[5]}'),
                    Text('${context.tr.familyFeedbackCannotAssess}: ${question.nCannotAssess}'),
                  ],
                ),
              ),
            if (result.themes != null && result.themes!.isNotEmpty) ...[
              Text(context.tr.familyFeedbackThemes, style: Theme.of(context).textTheme.titleSmall),
              Text(result.themes!),
            ],
          ],
        ],
      ),
    );
  }
}

class TeacherFamilyFeedbackResultRouteArgs {
  const TeacherFamilyFeedbackResultRouteArgs({
    required this.campaignId,
    this.result,
  });

  final String campaignId;
  final TeacherFamilyFeedbackResult? result;
}

class TeacherFamilyFeedbackResultRouteController extends LevitController
    with LevitReactiveTasksMixin {
  TeacherFamilyFeedbackResultRouteController({
    required this.routeArgs,
    required SchoolClientFactory schoolClient,
  }) : _schoolClient = schoolClient;

  final TeacherFamilyFeedbackResultRouteArgs routeArgs;
  final SchoolClientFactory _schoolClient;

  final result = LxVar<TeacherFamilyFeedbackResult?>(null);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(result);
    autoDispose(errorMessage);
    final initial = routeArgs.result;
    if (initial != null) {
      result(initial);
    } else {
      unawaited(load());
    }
  }

  DataStatus get dataStatus {
    if (isBusy.value && result.value == null) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && result.value == null) {
      return DataStatus.error;
    }
    return DataStatus.ready;
  }

  Future<void> load() async {
    errorMessage('');
    await runTask(() async {
      try {
        result(await getTeacherFamilyFeedbackResult(_schoolClient(), routeArgs.campaignId));
      } catch (error) {
        errorMessage(error.toString());
      }
    });
  }
}

class TeacherFamilyFeedbackResultRoutePage
    extends LScopedView<TeacherFamilyFeedbackResultRouteController> {
  const TeacherFamilyFeedbackResultRoutePage({
    super.key,
    required this.routeArgs,
  });

  final TeacherFamilyFeedbackResultRouteArgs routeArgs;

  @override
  TeacherFamilyFeedbackResultRouteController onConfigScope(LevitScope scope) {
    return scope.put(
      () => TeacherFamilyFeedbackResultRouteController(
        routeArgs: routeArgs,
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    TeacherFamilyFeedbackResultRouteController controller,
  ) {
    return LWatch(() {
      final data = controller.result.value;
      if (data == null) {
        return Scaffold(
          appBar: AppBar(title: Text(context.tr.familyFeedbackTitle)),
          body: DataState(
            status: controller.dataStatus,
            errorMessage: controller.errorMessage.value,
            onRetry: controller.load,
            child: const SizedBox.shrink(),
          ),
        );
      }
      return TeacherFamilyFeedbackResultPage(result: data);
    });
  }
}
