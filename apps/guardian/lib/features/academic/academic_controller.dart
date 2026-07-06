import 'dart:async';

import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/l10n/l10n_lookup.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'academic_data.dart';
import 'models/curriculum_scope_models.dart';

enum AcademicDetailTab { progress, logbook }

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

  final selectedTab = LxVar(AcademicDetailTab.progress);
  final selectedClassSubjectId = LxVar<String?>(null);
  final classSubjectOptions = LxVar<List<CurriculumClassSubjectOption>>(const []);
  final progressOverview = LxVar<CurriculumProgressOverview?>(null);
  final logbookEntries = LxVar<List<CurriculumLogEntry>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(selectedTab);
    autoDispose(selectedClassSubjectId);
    autoDispose(classSubjectOptions);
    autoDispose(progressOverview);
    autoDispose(logbookEntries);
    autoDispose(errorMessage);

    for (final subscription in [
      _studentContext.classGroupId.stream,
      _studentContext.activeStudent.stream,
      _studentContext.isEnrolled.stream,
      _studentContext.classLabel.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(subscription.listen((_) => unawaited(_reloadScope())));
    }

    unawaited(_reloadScope());
  }

  String? get selectedScopeLabel {
    final selectedId = selectedClassSubjectId.value;
    if (selectedId == null) {
      return null;
    }
    for (final option in classSubjectOptions.value) {
      if (option.id == selectedId) {
        return option.label;
      }
    }
    return null;
  }

  DataStatus get dataStatus {
    if (isBusy.value &&
        classSubjectOptions.value.isEmpty &&
        progressOverview.value == null &&
        logbookEntries.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty &&
        classSubjectOptions.value.isEmpty &&
        progressOverview.value == null &&
        logbookEntries.value.isEmpty) {
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
    if (classSubjectOptions.value.isEmpty) {
      return l10n.noCurriculumProgressYet;
    }
    if (selectedTab.value == AcademicDetailTab.logbook) {
      return l10n.noTeachingLogEntries;
    }
    return l10n.noCurriculumProgressYet;
  }

  void selectTab(AcademicDetailTab tab) {
    selectedTab(tab);
  }

  void selectSubject(String? classSubjectId) {
    if (classSubjectId == null ||
        classSubjectId == selectedClassSubjectId.value) {
      return;
    }
    selectedClassSubjectId(classSubjectId);
    unawaited(loadAcademicData());
  }

  Future<void> _reloadScope() async {
    final classGroupId = _studentContext.classGroupId.value;
    final classLabel = _studentContext.classLabel.value;

    if (classGroupId == null || classLabel == null) {
      classSubjectOptions(const []);
      selectedClassSubjectId(null);
      progressOverview(null);
      logbookEntries(const []);
      errorMessage('');
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final options = await fetchClassSubjectOptions(
          client: _schoolClient(),
          classGroupId: classGroupId,
          classLabel: classLabel,
          subjectFallback: systemL10n().subjectFallback,
        );
        classSubjectOptions(options);

        final currentId = selectedClassSubjectId.value;
        final resolvedId = currentId != null &&
                options.any((option) => option.id == currentId)
            ? currentId
            : options.firstOrNull?.id;
        selectedClassSubjectId(resolvedId);

        if (resolvedId == null) {
          progressOverview(null);
          logbookEntries(const []);
          return;
        }

        await loadAcademicData();
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
        classSubjectOptions(const []);
        selectedClassSubjectId(null);
        progressOverview(null);
        logbookEntries(const []);
      }
    });
  }

  Future<void> loadAcademicData() async {
    final classGroupId = _studentContext.classGroupId.value;
    final classLabel = _studentContext.classLabel.value;
    final classSubjectId = selectedClassSubjectId.value;

    if (classGroupId == null ||
        classLabel == null ||
        classSubjectId == null) {
      progressOverview(null);
      logbookEntries(const []);
      return;
    }

    final selectedOption = classSubjectOptions.value
        .where((option) => option.id == classSubjectId)
        .firstOrNull;
    if (selectedOption == null) {
      progressOverview(null);
      logbookEntries(const []);
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final matterFallback = systemL10n().unitFallback;
        final results = await Future.wait([
          fetchCurriculumProgressOverview(
            client: client,
            classSubjectId: classSubjectId,
            matterFallback: matterFallback,
          ),
          fetchCurriculumLogEntries(
            client: client,
            classGroupId: classGroupId,
            classSubjectId: classSubjectId,
            classLabel: classLabel,
            subjectLabel: selectedOption.subjectName,
            matterFallback: matterFallback,
          ),
        ]);

        progressOverview(results[0] as CurriculumProgressOverview);
        logbookEntries(results[1] as List<CurriculumLogEntry>);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
        progressOverview(null);
        logbookEntries(const []);
      }
    });
  }
}
