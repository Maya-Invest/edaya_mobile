import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../../common/utils/entity_filters.dart';
import 'models/report_card_roster_models.dart';
import 'report_card_logic.dart';

class ReportCardRosterController extends LevitController
    with LevitReactiveTasksMixin {
  ReportCardRosterController({
    required this.args,
    required String? Function() getAcademicYearId,
    required SchoolClientFactory schoolClient,
  }) : _getAcademicYearId = getAcademicYearId,
       _schoolClient = schoolClient;

  final ReportCardRosterArgs args;
  final String? Function() _getAcademicYearId;
  final SchoolClientFactory _schoolClient;

  final students = LxVar<List<ReportCardStudentRow>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(students);
    autoDispose(errorMessage);
    unawaited(loadRoster());
  }

  DataStatus get dataStatus {
    if (isBusy.value && students.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && students.value.isEmpty) {
      return DataStatus.error;
    }
    if (students.value.isEmpty) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage => systemL10n().noStudentsToRecord;

  Future<void> loadRoster() async {
    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final enrollmentRows = await client.enrollments.list(
          activeEnrollmentsForClass(
            args.classGroupId,
            academicYearId: _getAcademicYearId(),
          ),
        );
        final studentIds = enrollmentRows
            .map((row) => row['studentId'] as String?)
            .whereType<String>()
            .toList();
        final studentRows = studentIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.students.list(entitiesByIds(studentIds));

        final resultRows = await client.results.list({
          'classGroupId': args.classGroupId,
          'periodId': args.periodId,
        });
        final resultByStudent = <String, Map<String, dynamic>>{};
        for (final row in resultRows) {
          final studentId = row['studentId'] as String?;
          if (studentId == null || !reportCardIsGenerated(row)) {
            continue;
          }
          resultByStudent[studentId] = row;
        }

        final roster = studentRows.map((row) {
          final studentId = row['id'] as String;
          final firstName = row['firstName'] as String? ?? '';
          final lastName = row['lastName'] as String? ?? '';
          final fullName = '$firstName $lastName'.trim();
          final displayName = fullName.isEmpty ? studentId : fullName;
          final result = resultByStudent[studentId];
          return ReportCardStudentRow(
            studentId: studentId,
            studentName: displayName,
            studentInitials: _initials(displayName),
            photoUrl: row['photoUrl'] as String?,
            reportCardId: result?['id'] as String?,
            status: result?['status'] as String?,
            overallAverage: (result?['overallAverage'] as num?)?.toDouble(),
            rank: (result?['rank'] as num?)?.toInt(),
            classSize: (result?['classSize'] as num?)?.toInt(),
            hasComment: result == null ? false : reportCardHasComment(result),
          );
        }).toList()..sort((a, b) => a.studentName.compareTo(b.studentName));

        students(roster);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadReportCardRoster('$error'));
        students(const []);
      }
    });
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
