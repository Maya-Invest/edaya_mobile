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
    required SchoolClientFactory schoolClient,
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
  }) : _schoolClient = schoolClient,
       _studentContext = studentContext,
       _academicYear = academicYear;

  final SchoolClientFactory _schoolClient;
  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;

  final leftoverPapers = LxVar<List<DocumentIssuanceRecord>>(const []);
  final student = LxVar<LinkedStudent?>(null);
  final decision = LxVar<Map<String, dynamic>?>(null);
  final photoError = LxVar('');
  final papersError = LxVar('');
  final papersLoading = LxVar(false);
  final nextCursor = LxVar<String?>(null);
  final errorMessage = LxVar('');
  final statusMessage = LxVar('');
  final isSaving = LxVar(false);

  GuardianPupilSelection? _selection;
  int _generation = 0;
  Completer<void>? _abort;
  GuardianPupilSelection? get selection => _studentContext.verifiedSelection;
  bool get _visible =>
      _selection != null && _selection == selection && !isClosed;

  Map<String, dynamic>? get ownSubmission => _visible
      ? (decision.value?['ownSubmission'] as Map<String, dynamic>?)
      : null;

  DataStatus get dataStatus {
    if (selection == null) {
      return _studentContext.isLoading.value
          ? DataStatus.loading
          : DataStatus.empty;
    }
    if (!_visible) return DataStatus.loading;
    if (errorMessage.value.isNotEmpty) return DataStatus.error;
    return student.value == null ? DataStatus.loading : DataStatus.ready;
  }

  @override
  void onInit() {
    super.onInit();
    autoDispose(leftoverPapers);
    autoDispose(student);
    autoDispose(decision);
    autoDispose(photoError);
    autoDispose(papersError);
    autoDispose(papersLoading);
    autoDispose(nextCursor);
    autoDispose(errorMessage);
    autoDispose(statusMessage);
    autoDispose(isSaving);
    for (final stream in [
      _studentContext.activeStudent.stream,
      _academicYear.selectedYearId.stream,
      _studentContext.isLoading.stream,
    ]) {
      autoDispose(
        stream.listen((_) {
          if (_selection != selection) unawaited(load());
        }),
      );
    }
    unawaited(load());
  }

  @override
  void onClose() {
    _cancelReads();
    super.onClose();
  }

  void _cancelReads() {
    _generation++;
    _abort?.complete();
    _abort = null;
  }

  void _clear() {
    student(null);
    decision(null);
    nextCursor(null);
    leftoverPapers(const []);
    photoError('');
    papersError('');
    papersLoading(false);
    statusMessage('');
  }

  Future<void> load() async {
    _cancelReads();
    final scope = selection;
    _selection = scope;
    _clear();
    errorMessage('');
    if (scope == null || isClosed) return;
    student(_studentContext.activeStudent.value);
    _abort = Completer<void>();
    await runTask(() async {
      await Future.wait([_readPhoto(scope), _readPapers(scope)]);
    });
  }

  Map<String, dynamic> _query(GuardianPupilSelection scope) => {
    'studentId': scope.studentId,
    'academicYearId': scope.academicYearId,
  };

  bool _current(int generation) => generation == _generation && _visible;

  void _readFailed(Object error, LxVar<String> sectionError) {
    final message = systemL10n().childProfileLoadError('$error');
    if (error is api.ApiError && (error.status == 401 || error.status == 403)) {
      _cancelReads();
      _clear();
      errorMessage(message);
    } else {
      sectionError(message);
    }
  }

  Future<void> _readPhoto(GuardianPupilSelection scope) async {
    final generation = _generation;
    photoError('');
    decision(null);
    try {
      final data = await _schoolClient().getGuardianChildPhoto(
        _query(scope),
        abortTrigger: _abort!.future,
      );
      if (!_current(generation)) return;
      final pupil = LinkedStudent.fromJson(
        data['student'] as Map<String, dynamic>,
      );
      if (pupil.id != scope.studentId ||
          pupil.schoolId != scope.schoolId ||
          data['academicYearId'] != scope.academicYearId) {
        throw const FormatException('Unexpected pupil profile');
      }
      final result = data['decision'] as Map<String, dynamic>;
      if (!const {'none', 'rejected', 'pending'}.contains(result['status'])) {
        throw const FormatException('Unexpected photo decision');
      }
      student(pupil);
      decision(result);
    } on Object catch (error) {
      if (_current(generation)) _readFailed(error, photoError);
    }
  }

  Future<void> retryPhoto() async {
    if (_visible && photoError.value.isNotEmpty) await _readPhoto(_selection!);
  }

  Future<void> _readPapers(
    GuardianPupilSelection scope, [
    String? cursor,
  ]) async {
    final generation = _generation;
    papersError('');
    papersLoading(true);
    try {
      final data = await _schoolClient().getGuardianPapers({
        ..._query(scope),
        'cursor': ?cursor,
      }, abortTrigger: _abort!.future);
      if (!_current(generation)) return;
      if (data['studentId'] != scope.studentId ||
          data['academicYearId'] != scope.academicYearId) {
        throw const FormatException('Unexpected school document scope');
      }
      final rows = (data['items'] as List).cast<Map<String, dynamic>>().map(
        DocumentIssuanceRecord.fromJson,
      );
      leftoverPapers([if (cursor != null) ...leftoverPapers.value, ...rows]);
      nextCursor(data['nextCursor'] as String?);
    } on Object catch (error) {
      if (!_current(generation)) return;
      if (cursor != null && error is api.ApiError && error.status == 400) {
        leftoverPapers(const []);
        nextCursor(null);
        await _readPapers(scope);
      } else {
        _readFailed(error, papersError);
      }
    } finally {
      if (_current(generation)) papersLoading(false);
    }
  }

  Future<void> loadMorePapers() async {
    if (_visible &&
        !papersLoading.value &&
        (nextCursor.value != null || papersError.value.isNotEmpty)) {
      await _readPapers(_selection!, nextCursor.value);
    }
  }

  Future<bool> submitPortrait(
    Uint8List jpegBytes, {
    GuardianPupilSelection? expectedSelection,
  }) async {
    final current = student.value;
    final scope = selection;
    if (!_visible ||
        scope == null ||
        current == null ||
        (expectedSelection != null && scope != expectedSelection) ||
        decision.value == null ||
        decision.value?['status'] == 'pending' ||
        isSaving.value) {
      return false;
    }

    statusMessage('');
    isSaving(true);
    try {
      final client = _schoolClient();
      final uploaded = await uploadProfilePhoto(
        client: client,
        schoolId: scope.schoolId,
        ownerKind: 'student',
        ownerId: current.id,
        jpegBytes: jpegBytes,
      );
      if (scope != selection || isClosed) return false;
      final key =
          schoolStoragePrefix(client) +
          studentPhotoCommandStorageKey('submit', current.id);
      final requestId = await stableRequestId(key);
      if (scope != selection || isClosed) return false;
      await client.submitStudentPhoto({
        'requestId': requestId,
        'studentId': current.id,
        'attachmentId': uploaded.attachmentId,
      });
      if (client is DemoSchoolClient) await clearStoredId(key);
      if (scope != selection || isClosed) return true;
      await _studentContext.reloadContext();
      if (scope != selection || isClosed) return true;
      await load();
      if (scope != selection || isClosed) return true;
      statusMessage(systemL10n().childProfileSubmitted);
      return true;
    } on api.ApiError catch (error) {
      if (scope != selection || isClosed) return false;
      statusMessage(
        mutationFailureMessage(
          error,
          systemL10n().childProfileSubmitError('$error'),
        ),
      );
      return false;
    } on Object catch (error) {
      if (scope != selection || isClosed) return false;
      statusMessage(
        mutationFailureMessage(
          error,
          systemL10n().childProfileSubmitError('$error'),
        ),
      );
      return false;
    } finally {
      if (!isClosed) isSaving(false);
    }
  }

  Future<bool> withdrawPending() async {
    final current = student.value;
    final scope = selection;
    final row = ownSubmission;
    if (scope == null || current == null || row == null || isSaving.value) {
      return false;
    }

    statusMessage('');
    isSaving(true);
    try {
      final client = _schoolClient();
      final key =
          schoolStoragePrefix(client) +
          studentPhotoCommandStorageKey('withdraw', current.id);
      final requestId = await stableRequestId(key);
      if (scope != selection || isClosed) return false;
      await client.withdrawStudentPhotoSubmission({
        'requestId': requestId,
        'submissionId': row['id'],
        'expectedVersion': row['version'],
      });
      if (client is DemoSchoolClient) await clearStoredId(key);
      if (scope != selection || isClosed) return true;
      await load();
      if (scope != selection || isClosed) return true;
      statusMessage(systemL10n().childProfileWithdrawn);
      return true;
    } on api.ApiError catch (error) {
      if (scope != selection || isClosed) return false;
      statusMessage(
        mutationFailureMessage(
          error,
          systemL10n().childProfileWithdrawError('$error'),
        ),
      );
      return false;
    } on Object catch (error) {
      if (scope != selection || isClosed) return false;
      statusMessage(
        mutationFailureMessage(
          error,
          systemL10n().childProfileWithdrawError('$error'),
        ),
      );
      return false;
    } finally {
      if (!isClosed) isSaving(false);
    }
  }

  Future<DocumentJobResult> downloadLeftover(DocumentIssuanceRecord paper) {
    if (!_visible || !leftoverPapers.value.any((row) => row.id == paper.id)) {
      return Future.value(const DocumentJobResult.missing());
    }
    final generation = _generation;
    return downloadReadyIssuance(
      _schoolClient(),
      readyIssuanceId: paper.id,
      canOpen: () => _current(generation),
      sourceId: paper.sourceId,
      templateKey: paper.templateKey,
      studentId: student.value?.id,
      academicYearId: _academicYear.selectedYearId.value,
    );
  }
}
