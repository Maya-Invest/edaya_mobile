import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../common/utils/academic_period.dart';
import '../../common/utils/entity_filters.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'grades_data.dart';
import 'models/grade_entry.dart';
import 'models/report_card_summary.dart';

class ResultsPeriod {
  const ResultsPeriod({
    required this.id,
    required this.label,
    required this.isCurrent,
  });

  final String id;
  final String label;
  final bool isCurrent;
}

class SubjectPeriodResult {
  const SubjectPeriodResult({
    required this.subject,
    required this.periodId,
    required this.periodLabel,
    required this.gradeCount,
    this.average,
    this.maxScore = 20,
    this.policy,
  });

  final String subject;
  final String periodId;
  final String periodLabel;
  final int gradeCount;
  final double? average;
  final double maxScore;
  final GradingPolicyView? policy;

  bool get hasAverage => average != null;

  String get averageLabel {
    if (policy != null) return policy!.display(average);
    if (average == null) return '—';
    final formatted = average! % 1 == 0
        ? average!.toInt().toString()
        : average!.toStringAsFixed(2).replaceAll('.', ',');
    return '$formatted / ${maxScore.toInt()}';
  }

  String get stateLabel => gradeCount == 0 ? 'Aucune note' : 'Publié';
}

/// Notes + bulletins for the Scolarité list tab (from EvaluationsController).
class ResultsController extends LevitController with LevitReactiveTasksMixin {
  ResultsController({
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;
  int _progressGeneration = 0;

  @override
  void onClose() {
    _progressGeneration++;
    super.onClose();
  }

  GradingPolicyView? _gradingPolicy;
  final periods = LxVar<List<ResultsPeriod>>(const []);
  final gradeGroups = LxVar<List<SubjectGradeGroup>>(const []);
  final reportCards = LxVar<List<ReportCardSummary>>(const []);
  final expandedPeriodIds = LxVar<Set<String>>({});
  final overallProgramProgress = LxVar(0.0);
  final subjectsWithProgrammeCount = LxVar(0);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(periods);
    autoDispose(gradeGroups);
    autoDispose(reportCards);
    autoDispose(expandedPeriodIds);
    autoDispose(overallProgramProgress);
    autoDispose(subjectsWithProgrammeCount);
    autoDispose(errorMessage);

    for (final subscription in [
      _studentContext.classGroupId.stream,
      _studentContext.activeStudent.stream,
      _studentContext.isEnrolled.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(subscription.listen((_) => unawaited(reloadData())));
    }

    unawaited(reloadData());
  }

  DataStatus get dataStatus {
    if (isBusy.value &&
        gradeGroups.value.isEmpty &&
        reportCards.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty &&
        gradeGroups.value.isEmpty &&
        reportCards.value.isEmpty) {
      return DataStatus.error;
    }
    if (_studentContext.activeStudent.value == null) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  void togglePeriod(String periodId) {
    final next = {...expandedPeriodIds.value};
    if (!next.add(periodId)) {
      next.remove(periodId);
    }
    expandedPeriodIds(next);
  }

  ReportCardSummary? reportCardForPeriod(String periodId) {
    for (final card in reportCards.value) {
      if (card.periodId == periodId) return card;
    }
    return null;
  }

  List<SubjectPeriodResult> subjectResultsForPeriod(String periodId) {
    final period = periods.value.where((p) => p.id == periodId).firstOrNull;
    if (period == null) return const [];

    return gradeGroups.value
        .map((group) {
          final entries = group.entries
              .where((e) => e.periodId == periodId)
              .toList();
          return SubjectPeriodResult(
            subject: group.subjectName,
            periodId: periodId,
            periodLabel: period.label,
            gradeCount: entries.length,
            policy: _gradingPolicy,
            maxScore: _gradingPolicy?.maximum ?? 20,
            average: _weightedAverage(entries.where((e) => e.hasScore)),
          );
        })
        .where((r) => r.gradeCount > 0 || true)
        .toList()
      ..sort((a, b) => a.subject.compareTo(b.subject));
  }

  static String subjectRouteParam(String subject) =>
      Uri.encodeComponent(subject);

  Future<void> reloadData() async {
    await loadPeriods();
    await Future.wait([loadEvaluationsData(), loadProgressSummary()]);
  }

  Future<void> loadPeriods() async {
    final yearId = _academicYear.selectedYearId.value;
    if (yearId == null) {
      periods(const []);
      return;
    }

    try {
      final client = _schoolClient();
      final rows = sortAcademicPeriods(
        await client.academicPeriods.list(academicYearScope(yearId)),
      );
      final currentId = currentAcademicPeriodId(rows);
      final parsed = rows
          .map(
            (row) => ResultsPeriod(
              id: row['id'] as String,
              label: academicPeriodLabel(row),
              isCurrent: row['id'] == currentId,
            ),
          )
          .toList();
      periods(parsed);

      if (expandedPeriodIds.value.isEmpty && parsed.isNotEmpty) {
        final openId = currentId ?? parsed.first.id;
        expandedPeriodIds({openId});
      }
    } on Object catch (error) {
      errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
      periods(const []);
    }
  }

  Future<void> loadEvaluationsData() async {
    final studentId = _studentContext.activeStudentId;
    final classGroupId = _studentContext.classGroupId.value;
    final yearId = _academicYear.selectedYearId.value;

    if (studentId == null || yearId == null) {
      gradeGroups(const []);
      reportCards(const []);
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final periodNameById = {
          for (final period in periods.value) period.id: period.label,
        };

        if (classGroupId == null) {
          gradeGroups(const []);
        } else {
          final sources = await fetchStudentGradeSources(
            client: client,
            studentId: studentId,
            classGroupId: classGroupId,
            subjectFallback: systemL10n().subjectFallback,
          );

          _gradingPolicy = sources.gradingPolicy;
          final entries = <GradeEntry>[];
          for (final result in sources.results) {
            final assessmentId = result['assessmentId'] as String?;
            final assessment = assessmentId == null
                ? null
                : sources.assessmentById[assessmentId];
            if (assessment == null) continue;
            final classSubjectId = assessment['classSubjectId'] as String?;
            entries.add(
              GradeEntry.fromMaps(
                result: result,
                assessment: assessment,
                subjectName:
                    sources.subjectNameByClassSubjectId[classSubjectId] ??
                    systemL10n().subjectFallback,
                periodName:
                    periodNameById[assessment['periodId'] as String?] ??
                    assessment['periodId'] as String? ??
                    systemL10n().periodFallback,
              ),
            );
          }
          entries.sort((a, b) {
            final aDate = a.date;
            final bDate = b.date;
            if (aDate == null && bDate == null) {
              return a.title.compareTo(b.title);
            }
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

          final grouped = <String, List<GradeEntry>>{};
          for (final entry in entries) {
            grouped.putIfAbsent(entry.subjectName, () => []).add(entry);
          }
          final groups =
              grouped.entries
                  .map(
                    (entry) => SubjectGradeGroup(
                      subjectName: entry.key,
                      entries: entry.value,
                      average: _weightedAverage(
                        entry.value.where((grade) => grade.hasScore),
                      ),
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.subjectName.compareTo(b.subjectName));
          gradeGroups(groups);
        }

        final reportCardRows = await client.results.list(
          publishedReportCardsForStudent(studentId),
        );
        final cards = _dedupeReportCardsByPeriod(
          reportCardRows
              .map(
                (row) => ReportCardSummary.fromJson(
                  row,
                  periodName:
                      periodNameById[row['periodId'] as String?] ??
                      row['periodId'] as String? ??
                      systemL10n().periodFallback,
                ),
              )
              .toList(),
        );
        reportCards(cards);
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
        gradeGroups(const []);
        reportCards(const []);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
        gradeGroups(const []);
        reportCards(const []);
      }
    });
  }

  Future<void> loadProgressSummary() async {
    final generation = ++_progressGeneration;
    final studentId = _studentContext.activeStudentId;
    final classGroupId = _studentContext.classGroupId.value;
    overallProgramProgress(0);
    subjectsWithProgrammeCount(0);
    if (studentId == null || classGroupId == null) {
      overallProgramProgress(0);
      subjectsWithProgrammeCount(0);
      return;
    }

    try {
      final client = _schoolClient();
      final participation = await StudentSubjectParticipation.load(
        client,
        studentId,
      );
      if (generation != _progressGeneration ||
          studentId != _studentContext.activeStudentId ||
          classGroupId != _studentContext.classGroupId.value) {
        return;
      }
      final classSubjects = participation
          .currentSubjects()
          .where((row) => row['classGroupId'] == classGroupId)
          .toList();
      if (classSubjects.isEmpty) {
        overallProgramProgress(0);
        subjectsWithProgrammeCount(0);
        return;
      }
      var total = 0.0;
      var withProgramme = 0;
      for (final cs in classSubjects) {
        final pct = (cs['completedPercentage'] as num?)?.toDouble() ?? 0;
        total += pct;
        if (pct > 0 || true) withProgramme++;
      }
      overallProgramProgress((total / classSubjects.length / 100).clamp(0, 1));
      subjectsWithProgrammeCount(withProgramme);
    } on Object {
      // Non-fatal for results tab.
    }
  }

  double? _weightedAverage(Iterable<GradeEntry> entries) =>
      averageGrades(entries, _gradingPolicy);

  List<ReportCardSummary> _dedupeReportCardsByPeriod(
    List<ReportCardSummary> cards,
  ) {
    final bestByPeriod = <String, ReportCardSummary>{};
    for (final card in cards) {
      final existing = bestByPeriod[card.periodId];
      if (existing == null) {
        bestByPeriod[card.periodId] = card;
        continue;
      }
      final cardDate =
          card.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final existingDate =
          existing.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (cardDate.isAfter(existingDate)) {
        bestByPeriod[card.periodId] = card;
      }
    }
    return bestByPeriod.values.toList()..sort((a, b) {
      final aDate = a.publishedAt;
      final bDate = b.publishedAt;
      if (aDate == null && bDate == null) {
        return b.periodName.compareTo(a.periodName);
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
  }
}
