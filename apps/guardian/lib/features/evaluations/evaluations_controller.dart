import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../../common/utils/entity_filters.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import '../academic/models/grade_entry.dart';
import '../academic/models/report_card_summary.dart';
import '../../common/utils/academic_period.dart';

enum EvaluationsView { grades, reportCards }

class EvaluationsController extends LevitController
    with LevitReactiveTasksMixin {
  EvaluationsController({
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final view = LxVar(EvaluationsView.grades);
  final selectedPeriodId = LxVar<String?>(null);
  final periods = LxVar<List<Map<String, dynamic>>>(const []);
  final gradeGroups = LxVar<List<SubjectGradeGroup>>(const []);
  final reportCards = LxVar<List<ReportCardSummary>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(view);
    autoDispose(selectedPeriodId);
    autoDispose(periods);
    autoDispose(gradeGroups);
    autoDispose(reportCards);
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
    if (!_studentContext.isEnrolled.value) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage {
    final l10n = systemL10n();
    if (_studentContext.activeStudent.value == null) {
      return l10n.selectStudentToViewAcademic;
    }
    if (!_studentContext.isEnrolled.value) {
      return l10n.studentNotEnrolledForYear;
    }
    if (periods.value.isNotEmpty && selectedPeriodId.value == null) {
      return l10n.selectPeriodToViewEvaluations;
    }
    switch (view.value) {
      case EvaluationsView.grades:
        return l10n.noGradesForPeriod;
      case EvaluationsView.reportCards:
        return l10n.noReportCardsYet;
    }
  }

  List<SubjectGradeGroup> get filteredGradeGroups {
    final periodId = selectedPeriodId.value;
    if (periodId == null) {
      return const [];
    }

    return gradeGroups.value
        .map((group) {
          final entries = group.entries
              .where((entry) => entry.periodId == periodId)
              .toList();
          if (entries.isEmpty) {
            return null;
          }
          return SubjectGradeGroup(
            subjectName: group.subjectName,
            entries: entries,
            average: _weightedAverage(entries),
          );
        })
        .whereType<SubjectGradeGroup>()
        .toList();
  }

  List<ReportCardSummary> get filteredReportCards {
    final yearPeriodIds = periods.value
        .map((period) => period['id'] as String)
        .toSet();
    final cards = reportCards.value.where((card) {
      if (yearPeriodIds.isEmpty) {
        return true;
      }
      return yearPeriodIds.contains(card.periodId);
    });
    return cards.toList();
  }

  double? get overallAverage {
    final scored = filteredGradeGroups
        .expand((group) => group.entries)
        .where((entry) => entry.hasScore)
        .toList();
    return _weightedAverage(scored);
  }

  int get gradedCount {
    return filteredGradeGroups
        .expand((group) => group.entries)
        .where((entry) => entry.hasScore)
        .length;
  }

  void selectView(EvaluationsView nextView) {
    view(nextView);
  }

  void selectPeriod(String periodId) {
    selectedPeriodId(periodId);
  }

  Future<void> reloadData() async {
    await loadPeriods();
    await loadEvaluationsData();
  }

  Future<void> loadPeriods() async {
    final yearId = _academicYear.selectedYearId.value;
    if (yearId == null) {
      periods(const []);
      selectedPeriodId(null);
      return;
    }

    try {
      final client = _schoolClient();
      final rows = sortAcademicPeriods(
        await client.academicPeriods.list(academicYearScope(yearId)),
      );
      periods(rows);

      final currentId = selectedPeriodId.value;
      if (currentId == null || !rows.any((row) => row['id'] == currentId)) {
        selectedPeriodId(currentAcademicPeriodId(rows));
      }
    } on Object catch (error) {
      errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
      periods(const []);
      selectedPeriodId(null);
    }
  }

  Future<void> loadEvaluationsData() async {
    final studentId = _studentContext.activeStudentId;
    final classGroupId = _studentContext.classGroupId.value;
    final yearId = _academicYear.selectedYearId.value;

    if (studentId == null || yearId == null) {
      gradeGroups(const []);
      reportCards(const []);
      errorMessage('');
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final periodNameById = {
          for (final period in periods.value)
            period['id'] as String: academicPeriodLabel(period),
        };

        if (classGroupId == null) {
          gradeGroups(const []);
        } else {
          final classSubjectRows = await client.classSubjects.list(
            classGroupScope(classGroupId),
          );
          final subjectIds = classSubjectRows
              .map((row) => row['subjectId'] as String?)
              .whereType<String>()
              .toSet()
              .toList();
          final subjectRows = subjectIds.isEmpty
              ? <Map<String, dynamic>>[]
              : await client.subjects.list(entitiesByIds(subjectIds));
          final subjectNameById = {
            for (final subject in subjectRows)
              subject['id'] as String:
                  subject['name'] as String? ?? subject['id'] as String,
          };
          final subjectNameByClassSubjectId = {
            for (final classSubject in classSubjectRows)
              classSubject['id'] as String:
                  subjectNameById[classSubject['subjectId'] as String] ??
                  classSubject['subjectId'] as String,
          };

          final assessmentRows = await client.assessments.list(
            classGroupScope(classGroupId),
          );
          final assessmentById = {
            for (final assessment in assessmentRows)
              assessment['id'] as String: assessment,
          };
          final assessmentIds = assessmentById.keys.toList();
          final resultRows = assessmentIds.isEmpty
              ? <Map<String, dynamic>>[]
              : await client.assessmentResults.list({
                  'studentId': studentId,
                  ...recordsForField('assessmentId', assessmentIds),
                });

          final entries = <GradeEntry>[];
          for (final result in resultRows) {
            final assessmentId = result['assessmentId'] as String?;
            final assessment = assessmentId == null
                ? null
                : assessmentById[assessmentId];
            if (assessment == null) {
              continue;
            }
            final classSubjectId = assessment['classSubjectId'] as String?;
            entries.add(
              GradeEntry.fromMaps(
                result: result,
                assessment: assessment,
                subjectName:
                    subjectNameByClassSubjectId[classSubjectId] ??
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
            if (aDate == null) {
              return 1;
            }
            if (bDate == null) {
              return -1;
            }
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

  double? _weightedAverage(Iterable<GradeEntry> entries) {
    var totalWeight = 0.0;
    var weightedSum = 0.0;
    for (final entry in entries) {
      final score = entry.score;
      if (score == null) {
        continue;
      }
      final weight = entry.coefficient;
      totalWeight += weight;
      weightedSum += score * weight;
    }
    if (totalWeight == 0) {
      return null;
    }
    return weightedSum / totalWeight;
  }

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
      if (aDate == null) {
        return 1;
      }
      if (bDate == null) {
        return -1;
      }
      return bDate.compareTo(aDate);
    });
  }
}

class GradeDetailsController extends LevitController {
  GradeDetailsController({required this.entry});

  final GradeEntry entry;
}

class ReportCardDetailsController extends LevitController
    with LevitReactiveTasksMixin {
  ReportCardDetailsController({
    required this.reportCardId,
    required this.periodName,
    required SchoolClientFactory schoolClient,
  }) : _schoolClient = schoolClient;

  final String reportCardId;
  final String periodName;
  final SchoolClientFactory _schoolClient;

  final detail = LxVar<ReportCardDetail?>(null);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(detail);
    autoDispose(errorMessage);
    unawaited(loadDetail());
  }

  Future<DocumentJobResult> downloadPdf() {
    return downloadReadyIssuance(
      _schoolClient(),
      sourceId: reportCardId,
      templateKey: 'report-card.v1',
    );
  }

  Future<void> loadDetail() async {
    await runTask(() async {
      try {
        final client = _schoolClient();
        final row = await client.results.get(reportCardId);
        final classGroupId = row['classGroupId'] as String?;
        final subjectNameByClassSubjectId = classGroupId == null
            ? const <String, String>{}
            : await _loadSubjectNames(client, classGroupId);
        detail(
          ReportCardDetail.fromJson(
            row,
            periodName: periodName,
            subjectNameByClassSubjectId: subjectNameByClassSubjectId,
          ),
        );
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadReportCard(error.toString()));
        detail(null);
      }
    });
  }

  Future<Map<String, String>> _loadSubjectNames(
    api.SchoolClient client,
    String classGroupId,
  ) async {
    final classSubjectRows = await client.classSubjects.list(
      classGroupScope(classGroupId),
    );
    final subjectIds = classSubjectRows
        .map((row) => row['subjectId'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final subjectRows = subjectIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await client.subjects.list(entitiesByIds(subjectIds));
    final subjectNameById = {
      for (final subject in subjectRows)
        subject['id'] as String:
            subject['name'] as String? ?? subject['id'] as String,
    };

    return {
      for (final classSubject in classSubjectRows)
        classSubject['id'] as String:
            subjectNameById[classSubject['subjectId'] as String] ??
            classSubject['subjectId'] as String,
    };
  }
}
