import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/l10n/l10n_lookup.dart';
import '../context/academic_year_controller.dart';
import '../context/teacher_context_controller.dart';
import '../evaluations/evaluations_controller.dart';

class ReportCardClassSummary {
  const ReportCardClassSummary({
    required this.classGroupId,
    required this.classLabel,
    required this.generatedCount,
    required this.commentFilledCount,
  });

  final String classGroupId;
  final String classLabel;
  final int generatedCount;
  final int commentFilledCount;
}

class ReportCardsController extends LevitController with LevitReactiveTasksMixin {
  ReportCardsController({
    required TeacherContextController teacherContext,
    required AcademicYearController academicYear,
    required EvaluationsController evaluations,
    required SchoolClientFactory schoolClient,
  }) : _teacherContext = teacherContext,
       _academicYear = academicYear,
       _evaluations = evaluations,
       _schoolClient = schoolClient;

  final TeacherContextController _teacherContext;
  final AcademicYearController _academicYear;
  final EvaluationsController _evaluations;
  final SchoolClientFactory _schoolClient;

  final classSummaries = LxVar<List<ReportCardClassSummary>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(classSummaries);
    autoDispose(errorMessage);

    for (final subscription in [
      _teacherContext.assignedClasses.stream,
      _evaluations.selectedPeriodId.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(subscription.listen((_) {
        unawaited(loadClassSummaries());
      }));
    }

    unawaited(_ensurePeriodsLoaded());
  }

  List<Map<String, dynamic>> get periods => _evaluations.periods.value;

  String? get selectedPeriodId => _evaluations.selectedPeriodId.value;

  String? get selectedPeriodLabel => _evaluations.selectedPeriodLabel;

  Future<void> selectPeriod(String? periodId) async {
    if (periodId == null) {
      return;
    }
    _evaluations.selectPeriod(periodId);
    await loadClassSummaries();
  }

  DataStatus get dataStatus {
    if (_evaluations.isBusy.value && classSummaries.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && classSummaries.value.isEmpty) {
      return DataStatus.error;
    }
    if (_teacherContext.assignedClasses.value.isEmpty) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage => systemL10n().noClassesAssignedForYear;

  Future<void> _ensurePeriodsLoaded() async {
    if (_evaluations.periods.value.isEmpty) {
      await _evaluations.loadPeriods();
    }
    await loadClassSummaries();
  }

  Future<void> loadClassSummaries() async {
    final periodId = selectedPeriodId;
    final classes = _teacherContext.assignedClasses.value;
    if (periodId == null || classes.isEmpty) {
      classSummaries(const []);
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final summaries = <ReportCardClassSummary>[];

        for (final assigned in classes) {
          final results = await client.results.list({
            'classGroupId': assigned.id,
            'periodId': periodId,
          });
          final generated = results.where(
            (row) => row['status'] == 'draft' || row['status'] == 'published',
          );
          final withComments = generated.where((row) {
            final teacherComment = row['teacherComment'] as String?;
            if (teacherComment != null && teacherComment.trim().isNotEmpty) {
              return true;
            }
            return _hasSectionComment(row['sectionResults']);
          });

          summaries.add(
            ReportCardClassSummary(
              classGroupId: assigned.id,
              classLabel: assigned.label,
              generatedCount: generated.length,
              commentFilledCount: withComments.length,
            ),
          );
        }

        classSummaries(summaries);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadReportCards('$error'));
        classSummaries(const []);
      }
    });
  }

  bool _hasSectionComment(dynamic sections) {
    if (sections is! List) {
      return false;
    }
    for (final section in sections) {
      if (section is! Map) {
        continue;
      }
      final comment = section['comment'] as String?;
      if (comment != null && comment.trim().isNotEmpty) {
        return true;
      }
      if (_hasSectionComment(section['subResults'])) {
        return true;
      }
    }
    return false;
  }
}
