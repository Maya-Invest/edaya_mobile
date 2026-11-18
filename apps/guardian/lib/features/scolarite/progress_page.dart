import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../design/components/components.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart' hide SubjectProgressSummary;
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'progress_controller.dart';

class ProgressOverviewPage extends StatelessWidget {
  const ProgressOverviewPage({super.key, this.subjectId});
  final String? subjectId;
  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) return _LiveProgress(subjectId: subjectId);
    final store = context.levit.find<MockStore>();
    return ListenableBuilder(
      listenable: store,
      builder: (_, _) => _ProgressContent(
        subjectId: subjectId,
        summaries: [
          for (final s in store.subjectProgressSummaries)
            SubjectProgressSummary(
              subject: s.subject,
              classSubjectId: s.subject,
              progress: s.progress,
              status: s.status,
              topicCount: s.topicCount,
            ),
        ],
        topics: {
          for (final s in store.subjectProgressSummaries)
            s.subject: [
              for (final t in store.topicsForSubject(s.subject))
                ProgressTopic(
                  id: t.title,
                  title: t.title,
                  progress: t.progress,
                  status: t.status,
                ),
            ],
        },
      ),
    );
  }
}

class _LiveProgress extends LScopedView<ProgressController> {
  const _LiveProgress({this.subjectId});
  final String? subjectId;
  @override
  ProgressController onConfigScope(LevitScope scope) => scope.put(
    () => ProgressController(
      studentContext: scope.find<StudentContextController>(),
      academicYear: scope.find<AcademicYearController>(),
      schoolClient: scope.find<SchoolClientFactory>(),
    ),
  );
  @override
  Widget buildView(BuildContext context, ProgressController controller) =>
      _ProgressContent(
        subjectId: subjectId,
        summaries: controller.summaries.value,
        topics: controller.topicsBySubject.value,
        busy: controller.isBusy.value,
        error: controller.errorMessage.value,
        refresh: controller.load,
      );
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({
    required this.summaries,
    required this.topics,
    this.subjectId,
    this.busy = false,
    this.error = '',
    this.refresh,
  });
  final List<SubjectProgressSummary> summaries;
  final Map<String, List<ProgressTopic>> topics;
  final String? subjectId;
  final bool busy;
  final String error;
  final Future<void> Function()? refresh;
  @override
  Widget build(BuildContext context) {
    final subject = summaries
        .where((s) => s.classSubjectId == subjectId)
        .firstOrNull;
    final content = ListView(
      key: PageStorageKey(('progress', subjectId)),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error.isNotEmpty)
          TextButton(onPressed: refresh, child: Text(error)),
        if (subjectId == null)
          for (final s in summaries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SurfaceCard(
                onTap: () => context.push(
                  '/scolarite/progress/${Uri.encodeComponent(s.classSubjectId)}',
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.subject,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(s.progress * 100).round()} %',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PrototypeProgressBar(value: s.progress),
                  ],
                ),
              ),
            ),
        if (!busy && summaries.isEmpty) Text(context.tr.logbookEmptyCurriculum),
        if (subjectId != null && subject != null) ...[
          Text(subject.subject, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subject.status),
          TextButton.icon(
            onPressed: () => context.push(
              '/scolarite/progress/${Uri.encodeComponent(subject.classSubjectId)}/cahier',
            ),
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(context.tr.logbook),
          ),
          for (final topic
              in topics[subject.classSubjectId] ?? <ProgressTopic>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SurfaceCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(topic.title),
                  subtitle: Text(topic.status),
                  leading: Icon(
                    topic.progress >= 1
                        ? Icons.check_circle_outline
                        : topic.inProgress || topic.progress > 0
                        ? Icons.timelapse
                        : Icons.radio_button_unchecked,
                  ),
                ),
              ),
            ),
          if (subject.topicCount == 0) Text(context.tr.logbookEmptyCurriculum),
        ],
        if (subjectId != null && subject == null && !busy && error.isEmpty)
          Text(context.tr.logbookEmptyCurriculum),
      ],
    );
    return refresh == null
        ? content
        : RefreshIndicator(onRefresh: refresh!, child: content);
  }
}
