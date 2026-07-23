import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../common/utils/academic_period.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'models/grade_entry.dart';
import 'results_controller.dart';

class SubjectGradesController extends LevitController
    with LevitReactiveTasksMixin {
  SubjectGradesController({
    required this.periodId,
    required this.subject,
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final String periodId;
  final String subject;
  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final periodLabel = LxVar('');
  final grades = LxVar<List<GradeEntry>>(const []);
  final average = LxVar<double?>(null);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(periodLabel);
    autoDispose(grades);
    autoDispose(average);
    autoDispose(errorMessage);
    unawaited(load());
  }

  String get averageLabel {
    final value = average.value;
    if (value == null) return '—';
    final formatted = value % 1 == 0
        ? value.toInt().toString()
        : value.toStringAsFixed(1).replaceAll('.', ',');
    return '$formatted / 20';
  }

  Future<void> load() async {
    final studentId = _studentContext.activeStudentId;
    final classGroupId = _studentContext.classGroupId.value;
    final yearId = _academicYear.selectedYearId.value;
    if (studentId == null || classGroupId == null || yearId == null) {
      return;
    }

    await runTask(() async {
      try {
        final client = _schoolClient();
        final periodRows = sortAcademicPeriods(
          await client.academicPeriods.list(academicYearScope(yearId)),
        );
        final period = periodRows.where((p) => p['id'] == periodId).firstOrNull;
        periodLabel(
          period == null ? periodId : academicPeriodLabel(period),
        );

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
          for (final s in subjectRows)
            s['id'] as String: s['name'] as String? ?? s['id'] as String,
        };
        final subjectNameByClassSubjectId = {
          for (final cs in classSubjectRows)
            cs['id'] as String:
                subjectNameById[cs['subjectId'] as String] ??
                cs['subjectId'] as String,
        };

        final assessmentRows = await client.assessments.list(
          classGroupScope(classGroupId),
        );
        final assessmentById = {
          for (final a in assessmentRows) a['id'] as String: a,
        };
        final resultRows = assessmentById.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.assessmentResults.list({
                'studentId': studentId,
                ...recordsForField('assessmentId', assessmentById.keys.toList()),
              });

        final entries = <GradeEntry>[];
        for (final result in resultRows) {
          final assessment = assessmentById[result['assessmentId'] as String?];
          if (assessment == null) continue;
          if (assessment['periodId'] != periodId) continue;
          final classSubjectId = assessment['classSubjectId'] as String?;
          final name =
              subjectNameByClassSubjectId[classSubjectId] ??
              systemL10n().subjectFallback;
          if (name != subject) continue;
          entries.add(
            GradeEntry.fromMaps(
              result: result,
              assessment: assessment,
              subjectName: name,
              periodName: periodLabel.value,
            ),
          );
        }
        entries.sort((a, b) {
          final aDate = a.date;
          final bDate = b.date;
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate);
        });
        grades(entries);

        var totalWeight = 0.0;
        var weightedSum = 0.0;
        for (final entry in entries) {
          final score = entry.score;
          if (score == null) continue;
          totalWeight += entry.coefficient;
          weightedSum += score * entry.coefficient;
        }
        average(totalWeight == 0 ? null : weightedSum / totalWeight);
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
      }
    });
  }
}

// Re-export helper used by pages for navigation.
String subjectRouteParam(String subject) =>
    ResultsController.subjectRouteParam(subject);
