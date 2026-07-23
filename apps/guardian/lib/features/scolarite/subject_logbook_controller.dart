import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/student_context_controller.dart';
import 'academic_data.dart';
import 'models/curriculum_scope_models.dart';

class SubjectLogbookController extends LevitController
    with LevitReactiveTasksMixin {
  SubjectLogbookController({
    required this.subject,
    required StudentContextController studentContext,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _schoolClient = schoolClient;

  final String subject;
  final StudentContextController _studentContext;
  final SchoolClientFactory _schoolClient;

  final entries = LxVar<List<CurriculumLogEntry>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(entries);
    autoDispose(errorMessage);
    unawaited(load());
  }

  Future<void> load() async {
    final classGroupId = _studentContext.classGroupId.value;
    final classLabel = _studentContext.classLabel.value;
    if (classGroupId == null || classLabel == null) {
      entries(const []);
      return;
    }

    await runTask(() async {
      try {
        final client = _schoolClient();
        final options = await fetchClassSubjectOptions(
          client: client,
          classGroupId: classGroupId,
          classLabel: classLabel,
          subjectFallback: systemL10n().subjectFallback,
        );
        final option = options.where((o) => o.subjectName == subject).firstOrNull;
        if (option == null) {
          entries(const []);
          return;
        }

        final logEntries = await fetchCurriculumLogEntries(
          client: client,
          classGroupId: classGroupId,
          classSubjectId: option.id,
          classLabel: classLabel,
          subjectLabel: option.subjectName,
          matterFallback: systemL10n().unitFallback,
        );
        entries(logEntries.where((e) => e.hasContent).toList());
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
        entries(const []);
      }
    });
  }
}
