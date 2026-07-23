import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'academic_data.dart';
import 'models/curriculum_scope_models.dart';

class SubjectProgressSummary {
  const SubjectProgressSummary({
    required this.subject,
    required this.classSubjectId,
    required this.progress,
    required this.status,
    required this.topicCount,
  });

  final String subject;
  final String classSubjectId;
  final double progress;
  final String status;
  final int topicCount;

  bool get hasProgramme => topicCount > 0;
}

class ProgressTopic {
  const ProgressTopic({
    required this.id,
    required this.title,
    required this.progress,
    required this.status,
  });

  final String id;
  final String title;
  final double progress;
  final String status;
}

class ProgressController extends LevitController with LevitReactiveTasksMixin {
  ProgressController({
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final summaries = LxVar<List<SubjectProgressSummary>>(const []);
  final topicsBySubject = LxVar<Map<String, List<ProgressTopic>>>(const {});
  final expandedSubjectIds = LxVar<Set<String>>({});
  final overallProgress = LxVar(0.0);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(summaries);
    autoDispose(topicsBySubject);
    autoDispose(expandedSubjectIds);
    autoDispose(overallProgress);
    autoDispose(errorMessage);

    for (final subscription in [
      _studentContext.classGroupId.stream,
      _studentContext.activeStudent.stream,
      _studentContext.isEnrolled.stream,
      _studentContext.classLabel.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(subscription.listen((_) => unawaited(load())));
    }

    unawaited(load());
  }

  void toggleSubject(String subject) {
    final next = {...expandedSubjectIds.value};
    if (!next.add(subject)) {
      next.remove(subject);
    }
    expandedSubjectIds(next);
  }

  List<ProgressTopic> topicsForSubject(String subject) =>
      topicsBySubject.value[subject] ?? const [];

  Future<void> load() async {
    final classGroupId = _studentContext.classGroupId.value;
    final classLabel = _studentContext.classLabel.value;
    if (classGroupId == null || classLabel == null) {
      summaries(const []);
      topicsBySubject(const {});
      overallProgress(0);
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final options = await fetchClassSubjectOptions(
          client: client,
          classGroupId: classGroupId,
          classLabel: classLabel,
          subjectFallback: systemL10n().subjectFallback,
        );

        final nextSummaries = <SubjectProgressSummary>[];
        final nextTopics = <String, List<ProgressTopic>>{};
        var progressSum = 0.0;

        for (final option in options) {
          final overview = await fetchCurriculumProgressOverview(
            client: client,
            classSubjectId: option.id,
            matterFallback: systemL10n().unitFallback,
          );
          final pct = overview.classSubjectCompletedPercentage / 100.0;
          progressSum += pct;
          final topics = overview.matters
              .map(
                (m) => ProgressTopic(
                  id: m.id,
                  title: m.name,
                  progress: m.completedPercentage / 100.0,
                  status: switch (m.status) {
                    CurriculumMatterStatus.completed => 'Terminé',
                    CurriculumMatterStatus.inProgress => 'En cours',
                    CurriculumMatterStatus.notStarted => 'Non commencé',
                  },
                ),
              )
              .toList();
          nextTopics[option.subjectName] = topics;
          nextSummaries.add(
            SubjectProgressSummary(
              subject: option.subjectName,
              classSubjectId: option.id,
              progress: pct,
              status: topics.isEmpty
                  ? 'Aucun programme'
                  : '${(pct * 100).round()} %',
              topicCount: topics.length,
            ),
          );
        }

        summaries(nextSummaries);
        topicsBySubject(nextTopics);
        overallProgress(
          options.isEmpty ? 0 : (progressSum / options.length).clamp(0, 1),
        );
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
        summaries(const []);
        topicsBySubject(const {});
        overallProgress(0);
      }
    });
  }
}
