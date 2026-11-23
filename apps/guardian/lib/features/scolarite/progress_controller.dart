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
    this.inProgress = false,
  });

  final bool inProgress;
  final String id;
  final String title;
  final double progress;
  final String status;
}

class ProgressController extends LevitController with LevitReactiveTasksMixin {
  ProgressController({
    this.subjectId,
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final String? subjectId;
  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;
  int _loadGeneration = 0;
  ({GuardianPupilSelection pupil, String group, String label})? _lastScope;
  Future<void>? _pending;

  ({GuardianPupilSelection pupil, String group, String label})? get _scope {
    final pupil = _studentContext.verifiedSelection;
    final group = _studentContext.classGroupId.value;
    final label = _studentContext.classLabel.value;
    if (pupil == null || group == null || label == null) return null;
    return (pupil: pupil, group: group, label: label);
  }

  @override
  void onClose() {
    _loadGeneration++;
    super.onClose();
  }

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
      _studentContext.isLoading.stream,
      _studentContext.classLabel.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(subscription.listen((_) => unawaited(_select())));
    }

    unawaited(_select());
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

  Future<void> load() => _select(refresh: true);

  Future<void> _select({bool refresh = false}) {
    if (isClosed) return Future.value();
    final scope = _scope;
    if (_lastScope == scope && (!refresh || _pending != null)) {
      return _pending ?? Future.value();
    }
    _lastScope = scope;
    final generation = ++_loadGeneration;
    _pending = null;
    summaries(const []);
    topicsBySubject(const {});
    overallProgress(0);
    errorMessage('');
    if (scope == null) return Future.value();
    bool current() =>
        !isClosed && generation == _loadGeneration && _scope == scope;

    return _pending =
        runTask(() async {
          try {
            final client = _schoolClient();
            final pupil = scope.pupil;
            final selection = await StudentSubjectParticipation.load(
              client,
              pupil.studentId,
              academicYearId: pupil.academicYearId,
            );
            if (!current()) return;
            final words = systemL10n();
            final options = await fetchClassSubjectOptions(
              client: client,
              participation: selection,
              classGroupId: scope.group,
              classLabel: scope.label,
              subjectFallback: words.subjectFallback,
              offeringId: subjectId,
              includeProgress: true,
            );
            if (!current()) return;
            final next = <SubjectProgressSummary>[];
            var sum = 0.0;
            for (final option in options) {
              final overview = subjectId == null
                  ? CurriculumProgressOverview.fromOffering(option.offering)
                  : await fetchCurriculumProgressOverview(
                      client: client,
                      classSubject: option.offering,
                      matterFallback: words.unitFallback,
                    );
              if (!current()) return;
              final progress = overview.classSubjectCompletedPercentage / 100.0;
              sum += progress;
              next.add(
                SubjectProgressSummary(
                  subject: option.subjectName,
                  classSubjectId: option.id,
                  progress: progress,
                  topicCount: overview.chapterCount,
                  status: overview.chapterCount == 0
                      ? words.logbookEmptyCurriculum
                      : '${overview.classSubjectCompletedPercentage}% · ${words.logbookChapterCounts(overview.completedChapterCount, overview.chapterCount, overview.ongoingChapterCount)}',
                ),
              );
              if (subjectId != null) {
                topicsBySubject({
                  option.id: [
                    for (final m in overview.matters)
                      ProgressTopic(
                        id: m.id,
                        title: m.name,
                        progress: m.completedPercentage / 100.0,
                        inProgress:
                            m.status == CurriculumMatterStatus.inProgress,
                        status: switch (m.status) {
                          CurriculumMatterStatus.completed =>
                            words.matterStatusCompleted,
                          CurriculumMatterStatus.inProgress =>
                            words.matterStatusInProgress,
                          CurriculumMatterStatus.notStarted =>
                            words.matterStatusNotStarted,
                        },
                      ),
                  ],
                });
              }
            }
            summaries(next);
            overallProgress(next.isEmpty ? 0 : (sum / next.length).clamp(0, 1));
          } catch (error) {
            if (current())
              errorMessage(
                systemL10n().couldNotLoadAcademicData(error.toString()),
              );
          }
        }).whenComplete(() {
          if (generation == _loadGeneration) _pending = null;
        });
  }
}
