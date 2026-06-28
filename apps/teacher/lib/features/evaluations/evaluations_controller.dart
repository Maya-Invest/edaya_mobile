import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import '../../common/utils/academic_period.dart';
import '../../common/utils/entity_filters.dart';
import 'package:edaya_shared/edaya_shared.dart';
import '../context/academic_year_controller.dart';
import '../context/staff_context_controller.dart';
import 'models/evaluation_models.dart';

class EvaluationsController extends LevitController with LevitReactiveTasksMixin {
  EvaluationsController({
    required StaffContextController staffContext,
    required AcademicYearController academicYear,
  }) : _staffContext = staffContext,
       _academicYear = academicYear;

  final StaffContextController _staffContext;
  final AcademicYearController _academicYear;

  final evaluations = LxVar<List<EvaluationSummary>>(const []);
  final periods = LxVar<List<Map<String, dynamic>>>(const []);
  final selectedPeriodId = LxVar<String?>(null);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(evaluations);
    autoDispose(periods);
    autoDispose(selectedPeriodId);
    autoDispose(errorMessage);

    for (final subscription in [
      _staffContext.assignedClasses.stream,
      _staffContext.classFilterId.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(subscription.listen((_) {
        unawaited(reloadPeriodsAndEvaluations());
      }));
    }

    unawaited(reloadPeriodsAndEvaluations());
  }

  String? get selectedPeriodLabel {
    final periodId = selectedPeriodId.value;
    if (periodId == null) {
      return null;
    }
    for (final period in periods.value) {
      if (period['id'] == periodId) {
        return academicPeriodLabel(period);
      }
    }
    return periodId;
  }

  Future<void> reloadPeriodsAndEvaluations() async {
    await loadPeriods();
    await loadEvaluations();
  }

  Future<void> loadPeriods() async {
    final yearId = _academicYear.selectedYearId.value;
    if (yearId == null) {
      periods(const []);
      selectedPeriodId(null);
      return;
    }

    try {
      final client = AppRuntime.schoolClient();
      final rows = sortAcademicPeriods(
        await client.academicPeriods.list(academicPeriodsForYear(yearId)),
      );
      periods(rows);

      final currentId = selectedPeriodId.value;
      if (currentId == null || !rows.any((row) => row['id'] == currentId)) {
        selectedPeriodId(currentAcademicPeriodId(rows));
      }
    } on Object {
      periods(const []);
      selectedPeriodId(null);
    }
  }

  void selectPeriod(String periodId) {
    selectedPeriodId(periodId);
    unawaited(loadEvaluations());
  }

  DataStatus get dataStatus {
    if (isBusy.value && evaluations.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && evaluations.value.isEmpty) {
      return DataStatus.error;
    }
    if (_staffContext.assignedClasses.value.isEmpty) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage {
    if (selectedPeriodId.value == null) {
      return 'Select a period to view evaluations.';
    }
    return 'No evaluations for this period.';
  }

  Future<void> loadEvaluations() async {
    final classGroupIds = _staffContext.visibleClassGroupIds;
    final periodId = selectedPeriodId.value;
    if (classGroupIds.isEmpty || periodId == null) {
      evaluations(const []);
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = AppRuntime.schoolClient();
        final classLabelById = {
          for (final assigned in _staffContext.assignedClasses.value)
            assigned.id: assigned.label,
        };

        final summaries = <EvaluationSummary>[];
        for (final classGroupId in classGroupIds) {
          final assessmentRows = await client.assessments.list(
            assessmentsForClassPeriod(classGroupId, periodId),
          );
          final enrollments = await client.enrollments.list(
            activeEnrollmentsForClass(classGroupId),
          );
          final totalStudents = enrollments.length;

          for (final assessment in assessmentRows) {
            final assessmentId = assessment['id'] as String;
            final results = await client.assessmentResults.list(
              resultsForAssessment(assessmentId),
            );
            final graded = results
                .where((row) => row['score'] != null)
                .length;
            final classSubjectId = assessment['classSubjectId'] as String?;
            if (classSubjectId == null) {
              continue;
            }
            var subjectLabel = 'Subject';
            try {
              final classSubject = await client.classSubjects.get(
                classSubjectId,
              );
              final subjectId = classSubject['subjectId'] as String?;
              if (subjectId != null) {
                final subject = await client.subjects.get(subjectId);
                subjectLabel = subject['name'] as String? ?? subjectLabel;
              }
            } on Object {
              subjectLabel = 'Subject';
            }

            summaries.add(
              EvaluationSummary(
                id: assessmentId,
                title: assessment['title'] as String? ?? assessmentId,
                classGroupId: classGroupId,
                classSubjectId: classSubjectId,
                classLabel: classLabelById[classGroupId] ?? classGroupId,
                subjectLabel: subjectLabel,
                date: (assessment['dueAt'] as String?)?.substring(0, 10) ??
                    '',
                maxScore: (assessment['maxScore'] as num?)?.toDouble() ?? 20,
                gradedCount: graded,
                totalStudents: totalStudents,
              ),
            );
          }
        }

        summaries.sort((a, b) => b.date.compareTo(a.date));
        evaluations(summaries);
      } on api.ApiError catch (error) {
        errorMessage('Could not load evaluations: $error');
        evaluations(const []);
      } on Object catch (error) {
        errorMessage('Could not load evaluations: $error');
        evaluations(const []);
      }
    });
  }
}

class MarksEntryController extends LevitController with LevitReactiveTasksMixin {
  MarksEntryController({required this.evaluation});

  final EvaluationSummary evaluation;

  final students = LxVar<List<StudentMarkRow>>(const []);
  final errorMessage = LxVar('');
  final saveMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(students);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    unawaited(loadMarks());
  }

  Future<void> loadMarks() async {
    await runTask(() async {
      try {
        final client = AppRuntime.schoolClient();
        final enrollmentRows = await client.enrollments.list(
          activeEnrollmentsForClass(evaluation.classGroupId),
        );
        final studentIds = enrollmentRows
            .map((row) => row['studentId'] as String?)
            .whereType<String>()
            .toList();
        final studentRows = studentIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.students.list(entitiesByIds(studentIds));
        final studentById = {
          for (final row in studentRows)
            row['id'] as String: row,
        };
        final results = await client.assessmentResults.list(
          resultsForAssessment(evaluation.id),
        );
        final scoreByStudent = {
          for (final row in results)
            row['studentId'] as String: row,
        };

        final roster = studentIds
            .map((studentId) {
              final row = studentById[studentId];
              final firstName = row?['firstName'] as String? ?? '';
              final lastName = row?['lastName'] as String? ?? '';
              final fullName = '$firstName $lastName'.trim();
              final displayName = fullName.isEmpty ? studentId : fullName;
              final result = scoreByStudent[studentId];
              return StudentMarkRow(
                studentId: studentId,
                studentName: displayName,
                studentInitials: _initials(displayName),
                photoUrl: row?['photoUrl'] as String?,
                resultId: result?['id'] as String?,
                score: (result?['score'] as num?)?.toDouble(),
              );
            })
            .toList()
          ..sort((a, b) => a.studentName.compareTo(b.studentName));
        students(roster);
      } on Object catch (error) {
        errorMessage('Could not load marks: $error');
      }
    });
  }

  Future<bool> saveScore(StudentMarkRow row, double score) async {
    saveMessage('');
    try {
      final client = AppRuntime.schoolClient();
      final resultId = row.resultId ?? 'ar-${evaluation.id}-${row.studentId}';
      await client.recordAssessmentResult({
        'id': resultId,
        'studentId': row.studentId,
        'assessmentId': evaluation.id,
        'score': score,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      students(
        students.value
            .map(
              (entry) => entry.studentId == row.studentId
                  ? entry.copyWith(resultId: resultId, score: score)
                  : entry,
            )
            .toList(),
      );
      return true;
    } on Object catch (error) {
      saveMessage('Could not save mark: $error');
      return false;
    }
  }
}

class ClassSubjectOption {
  const ClassSubjectOption({
    required this.id,
    required this.classGroupId,
    required this.label,
  });

  final String id;
  final String classGroupId;
  final String label;
}

class EvaluationCreateController extends LevitController
    with LevitReactiveTasksMixin {
  EvaluationCreateController({
    required StaffContextController staffContext,
    required AcademicYearController academicYear,
    required EvaluationsController evaluations,
  }) : _staffContext = staffContext,
       _academicYear = academicYear,
       _evaluations = evaluations;

  final StaffContextController _staffContext;
  final AcademicYearController _academicYear;
  final EvaluationsController _evaluations;

  final classSubjects = LxVar<List<ClassSubjectOption>>(const []);
  final periods = LxVar<List<Map<String, dynamic>>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(classSubjects);
    autoDispose(periods);
    autoDispose(errorMessage);
    unawaited(loadClassSubjects());
    unawaited(loadPeriods());
  }

  List<AssignedClass> get assignedClasses => _staffContext.assignedClasses.value;

  Future<void> loadClassSubjects() async {
    final taughtIds = _staffContext.taughtClassSubjectIds.value;
    if (taughtIds.isEmpty) {
      classSubjects(const []);
      return;
    }

    await runTask(() async {
      try {
        final client = AppRuntime.schoolClient();
        final classLabelById = {
          for (final assigned in _staffContext.assignedClasses.value)
            assigned.id: assigned.label,
        };
        final rows = await client.classSubjects.list(
          entitiesByIds(taughtIds.toList()),
        );
        final subjectIds = rows
            .map((row) => row['subjectId'] as String?)
            .whereType<String>()
            .toSet()
            .toList();
        final subjectRows = subjectIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.subjects.list(entitiesByIds(subjectIds));
        final subjectNameById = {
          for (final subject in subjectRows)
            subject['id'] as String: subject['name'] as String? ?? 'Subject',
        };

        final options = rows
            .map((row) {
              final classGroupId = row['classGroupId'] as String;
              final subjectId = row['subjectId'] as String?;
              final subjectName = subjectId == null
                  ? 'Subject'
                  : subjectNameById[subjectId] ?? 'Subject';
              final classLabel = classLabelById[classGroupId] ?? classGroupId;
              return ClassSubjectOption(
                id: row['id'] as String,
                classGroupId: classGroupId,
                label: '$classLabel · $subjectName',
              );
            })
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
        classSubjects(options);
      } on Object catch (error) {
        errorMessage('Could not load subjects: $error');
        classSubjects(const []);
      }
    });
  }

  Future<void> loadPeriods() async {
    final yearId = _academicYear.selectedYearId.value;
    if (yearId == null) {
      periods(const []);
      return;
    }

    try {
      final client = AppRuntime.schoolClient();
      final rows = sortAcademicPeriods(
        await client.academicPeriods.list(academicPeriodsForYear(yearId)),
      );
      periods(rows);
    } on Object catch (error) {
      errorMessage('Could not load periods: $error');
      periods(const []);
    }
  }

  String? defaultPeriodId() {
    return currentAcademicPeriodId(periods.value);
  }

  Future<String?> createEvaluation({
    required String classGroupId,
    required String classSubjectId,
    required String periodId,
    required String title,
    required double maxScore,
    String kind = 'quiz',
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return 'Title is required.';
    }
    if (maxScore <= 0) {
      return 'Max score must be greater than zero.';
    }
    if (periodId.isEmpty) {
      return 'Period is required.';
    }

    errorMessage('');
    try {
      final client = AppRuntime.schoolClient();
      final id = 'asm-${DateTime.now().millisecondsSinceEpoch}';
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await client.createAssessment({
        'id': id,
        'classGroupId': classGroupId,
        'classSubjectId': classSubjectId,
        'periodId': periodId,
        'title': trimmedTitle,
        'kind': kind,
        'maxScore': maxScore,
        'coefficient': 1,
        'dueAt': today,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      await _evaluations.loadEvaluations();
      _evaluations.selectPeriod(periodId);
      return null;
    } on api.ApiError catch (error) {
      return 'Could not create evaluation: $error';
    } on Object catch (error) {
      return 'Could not create evaluation: $error';
    }
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}
