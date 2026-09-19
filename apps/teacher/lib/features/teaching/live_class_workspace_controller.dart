import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/teacher_context_controller.dart';
import 'teaching_data.dart';
import 'teaching_models.dart';

class LiveClassWorkspaceController extends LevitController
    with LevitReactiveTasksMixin {
  LiveClassWorkspaceController({
    required this.classGroupId,
    required TeacherContextController teacherContext,
    required SchoolClientFactory schoolClient,
  }) : _teacherContext = teacherContext,
       _schoolClient = schoolClient;

  final String classGroupId;
  final TeacherContextController _teacherContext;
  final SchoolClientFactory _schoolClient;

  final selectedClassSubjectId = LxVar<String?>(null);
  final classSubjectOptions = LxVar<List<TeachingClassSubjectOption>>(const []);
  final progressOverview = LxVar<TeachingProgressOverview?>(null);
  final logbookEntries = LxVar<List<TeachingLogEntry>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(selectedClassSubjectId);
    autoDispose(classSubjectOptions);
    autoDispose(progressOverview);
    autoDispose(logbookEntries);
    autoDispose(errorMessage);
    unawaited(load());
  }

  String get classLabel {
    for (final assigned in _teacherContext.assignedClasses.value) {
      if (assigned.id == classGroupId) {
        return assigned.label;
      }
    }
    return classGroupId;
  }

  TeachingClassSubjectOption? get selectedOption {
    final id = selectedClassSubjectId.value;
    if (id == null) {
      return null;
    }
    return classSubjectOptions.value.where((item) => item.id == id).firstOrNull;
  }

  Future<void> selectSubject(String? classSubjectId) async {
    selectedClassSubjectId(classSubjectId);
    await loadTeachingData();
  }

  Future<void> load() async {
    errorMessage('');
    await runTask(() async {
      try {
        final classLabelById = {classGroupId: classLabel};
        final options = await fetchTeachingSubjectsForClass(
          client: _schoolClient(),
          classGroupId: classGroupId,
          taughtClassSubjectIds: _teacherContext.taughtClassSubjectIds.value,
          isHomeroomClass: _teacherContext.assignedClassGroupIds.value.contains(
            classGroupId,
          ),
          classLabelById: classLabelById,
          subjectFallback: systemL10n().subjectFallback,
        );
        classSubjectOptions(options);
        if (options.isEmpty) {
          selectedClassSubjectId(null);
          progressOverview(null);
          logbookEntries(const []);
          return;
        }
        final current = selectedClassSubjectId.value;
        if (current == null || !options.any((item) => item.id == current)) {
          selectedClassSubjectId(options.first.id);
        }
        await loadTeachingData();
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadTeachingData('$error'));
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadTeachingData('$error'));
      }
    });
  }

  Future<void> loadTeachingData() async {
    final option = selectedOption;
    if (option == null) {
      progressOverview(null);
      logbookEntries(const []);
      return;
    }
    try {
      final client = _schoolClient();
      final matterFallback = systemL10n().chapterFallback;
      final results = await Future.wait([
        fetchTeachingProgressOverview(
          client: client,
          classSubjectId: option.id,
          matterFallback: matterFallback,
        ),
        fetchTeachingLogEntries(
          client: client,
          classGroupId: option.classGroupId,
          classSubjectId: option.id,
          classLabel: option.classLabel,
          subjectLabel: option.subjectName,
          matterFallback: matterFallback,
        ),
      ]);
      progressOverview(results[0] as TeachingProgressOverview);
      logbookEntries(results[1] as List<TeachingLogEntry>);
    } on Object catch (error) {
      errorMessage(systemL10n().couldNotLoadTeachingData('$error'));
    }
  }
}
