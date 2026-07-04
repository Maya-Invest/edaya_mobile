import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/l10n/l10n_lookup.dart';
import '../../common/utils/entity_filters.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'models/academic_period.dart';
import 'models/curriculum_subject.dart';
import 'models/grade_entry.dart';
import 'models/report_card_summary.dart';

enum AcademicView { grades, curriculum, reportCards }

class AcademicController extends LevitController with LevitReactiveTasksMixin {
  AcademicController({
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final view = LxVar(AcademicView.grades);
  final selectedPeriodId = LxVar<String?>(null);
  final periods = LxVar<List<AcademicPeriod>>(const []);
  final gradeGroups = LxVar<List<SubjectGradeGroup>>(const []);
  final curriculumSubjects = LxVar<List<CurriculumSubject>>(const []);
  final reportCards = LxVar<List<ReportCardSummary>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(view);
    autoDispose(selectedPeriodId);
    autoDispose(periods);
    autoDispose(gradeGroups);
    autoDispose(curriculumSubjects);
    autoDispose(reportCards);
    autoDispose(errorMessage);

    for (final subscription in [
      _studentContext.classGroupId.stream,
      _studentContext.activeStudent.stream,
      _studentContext.isEnrolled.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(subscription.listen((_) => unawaited(loadAcademicData())));
    }

    unawaited(loadAcademicData());
  }

  DataStatus get dataStatus {
    if (isBusy.value &&
        gradeGroups.value.isEmpty &&
        curriculumSubjects.value.isEmpty &&
        reportCards.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty &&
        gradeGroups.value.isEmpty &&
        curriculumSubjects.value.isEmpty &&
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
    switch (view.value) {
      case AcademicView.grades:
        return l10n.noGradesForPeriod;
      case AcademicView.curriculum:
        return l10n.noCurriculumProgressYet;
      case AcademicView.reportCards:
        return l10n.noReportCardsYet;
    }
  }

  List<SubjectGradeGroup> get filteredGradeGroups {
    final periodId = selectedPeriodId.value;
    if (periodId == null) {
      return gradeGroups.value;
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

  void selectView(AcademicView nextView) {
    view(nextView);
  }

  void selectPeriod(String? periodId) {
    selectedPeriodId(periodId);
  }

  Future<void> loadAcademicData() async {
    final studentId = _studentContext.activeStudentId;
    final classGroupId = _studentContext.classGroupId.value;
    final yearId = _academicYear.selectedYearId.value;

    if (studentId == null || classGroupId == null || yearId == null) {
      periods(const []);
      gradeGroups(const []);
      curriculumSubjects(const []);
      reportCards(const []);
      errorMessage('');
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final periodRows = await client.academicPeriods.list(
          academicYearScope(yearId),
        );
        final parsedPeriods = periodRows
            .map(AcademicPeriod.fromJson)
            .toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));

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
            classSubject['id'] as String: subjectNameById[
                    classSubject['subjectId'] as String] ??
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

        final periodNameById = {
          for (final period in parsedPeriods) period.id: period.name,
        };
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
              subjectName: subjectNameByClassSubjectId[classSubjectId] ??
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
        final groups = grouped.entries
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

        final classSubjectIds = classSubjectRows
            .map((row) => row['id'] as String)
            .toList();
        final matterRows = classSubjectIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.classSubjectMatters.list(
                recordsForField('classSubjectId', classSubjectIds),
              );
        final subjectMatterIds = matterRows
            .map((row) => row['subjectMatterId'] as String?)
            .whereType<String>()
            .toSet()
            .toList();
        final subjectMatterRows = subjectMatterIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.subjectMatters.list(
                entitiesByIds(subjectMatterIds),
              );
        final subjectMatterNameById = {
          for (final matter in subjectMatterRows)
            matter['id'] as String:
                matter['name'] as String? ?? matter['id'] as String,
        };

        final curriculum = classSubjectRows.map((classSubject) {
          final classSubjectId = classSubject['id'] as String;
          final subjectName =
              subjectNameByClassSubjectId[classSubjectId] ?? classSubjectId;
          final units = matterRows
              .where(
                (matter) => matter['classSubjectId'] == classSubjectId,
              )
              .map(
                (matter) => CurriculumUnit(
                  name: subjectMatterNameById[
                          matter['subjectMatterId'] as String] ??
                      systemL10n().unitFallback,
                  completedPercentage:
                      (matter['completedPercentage'] as num?)?.round() ?? 0,
                  status: matter['status'] as String? ?? 'not_started',
                ),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          return CurriculumSubject(
            subjectName: subjectName,
            completedPercentage:
                (classSubject['completedPercentage'] as num?)?.round() ?? 0,
            units: units,
          );
        }).toList()
          ..sort((a, b) => a.subjectName.compareTo(b.subjectName));

        final reportCardRows = await client.results.list(
          publishedReportCardsForStudent(studentId),
        );
        final cards = reportCardRows
            .map(
              (row) => ReportCardSummary.fromJson(
                row,
                periodName:
                    periodNameById[row['periodId'] as String?] ??
                    row['periodId'] as String? ??
                    systemL10n().periodFallback,
              ),
            )
            .toList()
          ..sort((a, b) {
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

        periods(parsedPeriods);
        gradeGroups(groups);
        curriculumSubjects(curriculum);
        reportCards(cards);

        if (selectedPeriodId.value != null &&
            parsedPeriods.every(
              (period) => period.id != selectedPeriodId.value,
            )) {
          selectedPeriodId(null);
        }
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
        periods(const []);
        gradeGroups(const []);
        curriculumSubjects(const []);
        reportCards(const []);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
        periods(const []);
        gradeGroups(const []);
        curriculumSubjects(const []);
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

  Future<void> loadDetail() async {
    await runTask(() async {
      try {
        final row = await _schoolClient().results.get(reportCardId);
        detail(
          ReportCardDetail.fromJson(
            row,
            periodName: periodName,
          ),
        );
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadReportCard(error.toString()));
        detail(null);
      }
    });
  }
}
