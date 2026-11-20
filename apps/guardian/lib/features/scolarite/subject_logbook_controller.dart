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
    this.byId = false,
    required StudentContextController studentContext,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _schoolClient = schoolClient;

  final String subject;
  final bool byId;
  final subjectLabel = LxVar<String?>(null);
  final StudentContextController _studentContext;
  final SchoolClientFactory _schoolClient;
  int _loadGeneration = 0;

  @override
  void onClose() {
    _loadGeneration++;
    super.onClose();
  }

  final entries = LxVar<List<CurriculumLogEntry>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(entries);
    autoDispose(subjectLabel);
    autoDispose(errorMessage);
    for (final stream in [
      _studentContext.activeStudent.stream,
      _studentContext.classGroupId.stream,
    ]) {
      autoDispose(stream.listen((_) => unawaited(load())));
    }
    unawaited(load());
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    final studentId = _studentContext.activeStudentId;
    final yearId = _studentContext.activeYearId;
    final classGroupId = _studentContext.classGroupId.value;
    final classLabel = _studentContext.classLabel.value;
    bool isCurrent() =>
        !isClosed &&
        generation == _loadGeneration &&
        yearId == _studentContext.activeYearId &&
        studentId == _studentContext.activeStudentId &&
        classGroupId == _studentContext.classGroupId.value &&
        classLabel == _studentContext.classLabel.value;
    errorMessage('');
    subjectLabel(null);
    entries(const []);
    if (studentId == null ||
        yearId == null ||
        classGroupId == null ||
        classLabel == null) {
      entries(const []);
      return;
    }

    await runTask(() async {
      try {
        final client = _schoolClient();
        final participation = await StudentSubjectParticipation.load(
          client,
          studentId,
          academicYearId: yearId,
        );
        if (!isCurrent()) return;
        final options = await fetchClassSubjectOptions(
          client: client,
          participation: participation,
          offeringId: byId ? subject : null,
          classGroupId: classGroupId,
          classLabel: classLabel,
          subjectFallback: systemL10n().subjectFallback,
        );
        if (!isCurrent()) return;
        final option = options
            .where((o) => byId ? o.id == subject : o.subjectName == subject)
            .singleOrNull;
        if (option == null) {
          entries(const []);
          return;
        }

        subjectLabel(option.subjectName);
        final logEntries = await fetchCurriculumLogEntries(
          participation: participation,
          client: client,
          classGroupId: classGroupId,
          classSubjectId: option.id,
          classLabel: classLabel,
          subjectLabel: option.subjectName,
          matterFallback: systemL10n().unitFallback,
        );
        if (!isCurrent()) return;
        entries(logEntries.where((e) => e.hasContent).toList());
      } on Object catch (error) {
        if (!isCurrent()) return;
        errorMessage(systemL10n().couldNotLoadAcademicData(error.toString()));
        entries(const []);
      }
    });
  }
}
