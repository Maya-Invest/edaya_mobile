import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/l10n/l10n_lookup.dart';
import '../context/academic_year_controller.dart';
import '../context/teacher_context_controller.dart';
import 'models/teaching_models.dart';
import 'teaching_data.dart';

enum TeachingDetailTab { progress, logbook }

class TeachingController extends LevitController with LevitReactiveTasksMixin {
  TeachingController({
    required TeacherContextController teacherContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _teacherContext = teacherContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final TeacherContextController _teacherContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final selectedClassSubjectId = LxVar<String?>(null);
  final classSubjectOptions = LxVar<List<TeachingClassSubjectOption>>(const []);
  final progressOverview = LxVar<TeachingProgressOverview?>(null);
  final logbookEntries = LxVar<List<TeachingLogEntry>>(const []);
  final selectedTab = LxVar(TeachingDetailTab.progress);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(selectedClassSubjectId);
    autoDispose(classSubjectOptions);
    autoDispose(progressOverview);
    autoDispose(logbookEntries);
    autoDispose(selectedTab);
    autoDispose(errorMessage);

    for (final subscription in [
      _teacherContext.assignedClasses.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(subscription.listen((_) {
        unawaited(_reloadScope());
      }));
    }

    unawaited(_reloadScope());
  }

  List<AssignedClass> get assignedClasses => _teacherContext.assignedClasses.value;

  TeachingClassSubjectOption? get selectedOption {
    final classSubjectId = selectedClassSubjectId.value;
    if (classSubjectId == null) {
      return null;
    }
    return classSubjectOptions.value
        .where((option) => option.id == classSubjectId)
        .firstOrNull;
  }

  String? get selectedScopeLabel => selectedOption?.label;

  DataStatus get dataStatus {
    if (_teacherContext.isLoading.value || (isBusy.value && progressOverview.value == null)) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty &&
        selectedClassSubjectId.value == null) {
      return DataStatus.error;
    }
    if (selectedClassSubjectId.value == null) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage {
    if (assignedClasses.isEmpty) {
      return systemL10n().noClassesAssignedForYear;
    }
    if (classSubjectOptions.value.isEmpty) {
      return systemL10n().noSubjectsAssignedForYear;
    }
    return systemL10n().teachingSelectSubject;
  }

  Future<void> selectSubject(String? classSubjectId) async {
    selectedClassSubjectId(classSubjectId);
    await loadTeachingData();
  }

  void selectTab(TeachingDetailTab tab) {
    selectedTab(tab);
  }

  Future<void> loadTeachingData() async {
    final classSubjectId = selectedClassSubjectId.value;
    if (classSubjectId == null) {
      progressOverview(null);
      logbookEntries(const []);
      return;
    }

    final option = selectedOption;
    if (option == null) {
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final matterFallback = systemL10n().chapterFallback;
        final results = await Future.wait([
          fetchTeachingProgressOverview(
            client: client,
            classSubjectId: classSubjectId,
            matterFallback: matterFallback,
          ),
          fetchTeachingLogEntries(
            client: client,
            classGroupId: option.classGroupId,
            classSubjectId: classSubjectId,
            classLabel: option.classLabel,
            subjectLabel: option.subjectName,
            matterFallback: matterFallback,
          ),
        ]);
        progressOverview(results[0] as TeachingProgressOverview);
        logbookEntries(results[1] as List<TeachingLogEntry>);
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadTeachingData('$error'));
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadTeachingData('$error'));
      }
    });
  }

  Future<void> _reloadScope() async {
    if (assignedClasses.isEmpty) {
      selectedClassSubjectId(null);
      classSubjectOptions(const []);
      progressOverview(null);
      logbookEntries(const []);
      return;
    }

    await _loadClassSubjectOptions();

    final currentSubjectId = selectedClassSubjectId.value;
    if (currentSubjectId == null ||
        !classSubjectOptions.value.any((entry) => entry.id == currentSubjectId)) {
      await _selectDefaultSubject();
    }
    await loadTeachingData();
  }

  Future<void> _loadClassSubjectOptions() async {
    final classLabelById = {
      for (final assigned in assignedClasses) assigned.id: assigned.label,
    };

    try {
      final options = await fetchAllTeachingClassSubjectOptions(
        client: _schoolClient(),
        classLabelById: classLabelById,
        taughtClassSubjectIds: _teacherContext.taughtClassSubjectIds.value,
        homeroomClassGroupIds: _teacherContext.assignedClassGroupIds.value,
        subjectFallback: systemL10n().subjectFallback,
      );
      classSubjectOptions(options);
    } on Object catch (error) {
      errorMessage(systemL10n().couldNotLoadSubjects('$error'));
      classSubjectOptions(const []);
    }
  }

  Future<void> _selectDefaultSubject() async {
    final options = classSubjectOptions.value;
    selectedClassSubjectId(options.isEmpty ? null : options.first.id);
  }
}
