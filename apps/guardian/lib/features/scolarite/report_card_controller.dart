import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../common/utils/academic_period.dart';
import 'models/report_card_summary.dart';

class ReportCardController extends LevitController
    with LevitReactiveTasksMixin {
  ReportCardController({
    required this.reportCardId,
    required SchoolClientFactory schoolClient,
  }) : _schoolClient = schoolClient;

  final String reportCardId;
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
        final client = _schoolClient();
        final row = await client.results.get(reportCardId);
        var periodName =
            row['periodId'] as String? ?? systemL10n().periodFallback;
        final periodId = row['periodId'] as String?;
        final yearId = row['academicYearId'] as String?;
        if (periodId != null && yearId != null) {
          try {
            final periods = await client.academicPeriods.list(
              academicYearScope(yearId),
            );
            final period = periods.where((p) => p['id'] == periodId).firstOrNull;
            if (period != null) {
              periodName = academicPeriodLabel(period);
            }
          } on Object {
            // fallback
          }
        }

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
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadReportCard(error.toString()));
        detail(null);
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
