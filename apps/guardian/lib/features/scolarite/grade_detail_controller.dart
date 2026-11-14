import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../common/utils/academic_period.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'models/grade_entry.dart';

class GradeDetailController extends LevitController
    with LevitReactiveTasksMixin {
  GradeDetailController({
    required this.gradeId,
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final String gradeId;
  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final entry = LxVar<GradeEntry?>(null);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(entry);
    autoDispose(errorMessage);
    unawaited(load());
  }

  Future<void> load() async {
    final studentId = _studentContext.activeStudentId;
    final classGroupId = _studentContext.classGroupId.value;
    final yearId = _academicYear.selectedYearId.value;
    if (studentId == null || classGroupId == null) {
      errorMessage('Note introuvable');
      return;
    }

    await runTask(() async {
      try {
        final client = _schoolClient();
        final result = await client.assessmentResults.get(gradeId);
        final assessmentId = result['assessmentId'] as String?;
        if (assessmentId == null) {
          errorMessage('Note introuvable');
          return;
        }
        final assessment = await client.assessments.get(assessmentId);

        var subjectName = systemL10n().subjectFallback;
        final classSubjectId = assessment['classSubjectId'] as String?;
        if (classSubjectId != null) {
          try {
            final classSubject = await client.classSubjects.get(classSubjectId);
            final subjectId = classSubject['subjectId'] as String?;
            if (subjectId != null) {
              final subject = await client.subjects.get(subjectId);
              subjectName = subject['name'] as String? ?? subjectName;
            }
          } on Object {
            // fallback
          }
        }

        var periodName =
            assessment['periodId'] as String? ?? systemL10n().periodFallback;
        if (yearId != null) {
          try {
            final periods = await client.academicPeriods.list(
              academicYearScope(yearId),
            );
            final period = periods
                .where((p) => p['id'] == assessment['periodId'])
                .firstOrNull;
            if (period != null) {
              periodName = academicPeriodLabel(period);
            }
          } on Object {
            // fallback
          }
        }

        entry(
          GradeEntry.fromMaps(
            result: result,
            assessment: assessment,
            subjectName: subjectName,
            periodName: periodName,
          ),
        );
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
        entry(null);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
        entry(null);
      }
    });
  }
}
