import 'dart:async';
import 'dart:typed_data';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import '../my_students/linked_student.dart';

class ChildProfileController extends LevitController
    with LevitReactiveTasksMixin {
  ChildProfileController({
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
  }) : _session = session,
       _schoolClient = schoolClient,
       _studentContext = studentContext,
       _academicYear = academicYear;

  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;
  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;

  final leftoverPapers = LxVar<List<DocumentIssuanceRecord>>(const []);
  final student = LxVar<LinkedStudent?>(null);
  final pending = LxVar<Map<String, dynamic>?>(null);
  final latestRejected = LxVar<Map<String, dynamic>?>(null);
  final errorMessage = LxVar('');
  final statusMessage = LxVar('');
  final isSaving = LxVar(false);

  String? get guardianId => _session.grants.value?.actorId;

  String? get schoolId => _session.grants.value?.schoolId;

  bool get isSubmitter {
    final pendingRow = pending.value;
    final actorId = guardianId;
    if (pendingRow == null || actorId == null) {
      return false;
    }
    return pendingRow['submitterGuardianId'] == actorId;
  }

  DataStatus get dataStatus {
    if (isBusy.value && student.value == null) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && student.value == null) {
      return DataStatus.error;
    }
    if (student.value == null) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  @override
  void onInit() {
    super.onInit();
    autoDispose(leftoverPapers);
    autoDispose(student);
    autoDispose(pending);
    autoDispose(latestRejected);
    autoDispose(errorMessage);
    autoDispose(statusMessage);
    autoDispose(isSaving);
    unawaited(load());
  }

  Future<void> load() async {
    final active = _studentContext.activeStudent.value;
    if (active == null) {
      student(null);
      pending(null);
      latestRejected(null);
      leftoverPapers(const []);
      errorMessage('');
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final fresh = await client.students.get(active.id);
        student(LinkedStudent.fromJson(fresh));
        final rows = await optionalEntityList(
          client.studentPhotoSubmissions.list({
            'studentId': active.id,
            r'$limit': 50,
          }),
        );
        Map<String, dynamic>? nextPending;
        Map<String, dynamic>? nextRejected;
        for (final row in rows) {
          final status = row['status'] as String?;
          if (status == 'pending' && nextPending == null) {
            nextPending = row;
          } else if (status == 'rejected' && nextRejected == null) {
            nextRejected = row;
          }
        }
        pending(nextPending);
        latestRejected(nextPending == null ? nextRejected : null);
        leftoverPapers(
          (await listDocumentIssuances(
            client,
            studentId: active.id,
            academicYearId: _academicYear.selectedYearId.value,
          )).where((item) => isLeftoverFamilyPaper(item.templateKey)).toList(),
        );
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().childProfileLoadError('$error'));
      } on Object catch (error) {
        errorMessage(systemL10n().childProfileLoadError('$error'));
      }
    });
  }

  Future<bool> submitPortrait(Uint8List jpegBytes) async {
    final current = student.value;
    final resolvedSchoolId = schoolId;
    if (current == null || resolvedSchoolId == null || isSaving.value) {
      return false;
    }

    statusMessage('');
    isSaving(true);
    try {
      final client = _schoolClient();
      final uploaded = await uploadProfilePhoto(
        client: client,
        schoolId: resolvedSchoolId,
        ownerKind: 'student',
        ownerId: current.id,
        jpegBytes: jpegBytes,
      );
      await client.submitStudentPhoto({
        'requestId': await stableRequestId(
          studentPhotoCommandStorageKey('submit', current.id),
        ),
        'studentId': current.id,
        'attachmentId': uploaded.attachmentId,
      });
      await load();
      await _studentContext.reloadContext();
      statusMessage(systemL10n().childProfileSubmitted);
      return true;
    } on api.ApiError catch (error) {
      statusMessage(
        mutationFailureMessage(
          error,
          systemL10n().childProfileSubmitError('$error'),
        ),
      );
      return false;
    } on Object catch (error) {
      statusMessage(
        mutationFailureMessage(
          error,
          systemL10n().childProfileSubmitError('$error'),
        ),
      );
      return false;
    } finally {
      isSaving(false);
    }
  }

  Future<bool> withdrawPending() async {
    final current = student.value;
    final row = pending.value;
    if (current == null || row == null || !isSubmitter || isSaving.value) {
      return false;
    }

    statusMessage('');
    isSaving(true);
    try {
      await _schoolClient().withdrawStudentPhotoSubmission({
        'requestId': await stableRequestId(
          studentPhotoCommandStorageKey('withdraw', current.id),
        ),
        'submissionId': row['id'],
        'expectedVersion': row['version'],
      });
      await load();
      statusMessage(systemL10n().childProfileWithdrawn);
      return true;
    } on api.ApiError catch (error) {
      statusMessage(
        mutationFailureMessage(
          error,
          systemL10n().childProfileWithdrawError('$error'),
        ),
      );
      return false;
    } on Object catch (error) {
      statusMessage(
        mutationFailureMessage(
          error,
          systemL10n().childProfileWithdrawError('$error'),
        ),
      );
      return false;
    } finally {
      isSaving(false);
    }
  }

  Future<DocumentJobResult> downloadLeftover(DocumentIssuanceRecord paper) {
    return downloadReadyIssuance(
      _schoolClient(),
      sourceId: paper.sourceId,
      templateKey: paper.templateKey,
      studentId: student.value?.id,
      academicYearId: _academicYear.selectedYearId.value,
    );
  }
}
