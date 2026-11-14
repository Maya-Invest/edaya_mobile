import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';

class DocumentsController extends LevitController with LevitReactiveTasksMixin {
  DocumentsController({
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final issuances = LxVar<List<DocumentIssuanceRecord>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(issuances);
    autoDispose(errorMessage);

    for (final subscription in [
      _studentContext.activeStudent.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(subscription.listen((_) => unawaited(loadDocuments())));
    }

    unawaited(loadDocuments());
  }

  DataStatus get dataStatus {
    if (isBusy.value && issuances.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && issuances.value.isEmpty) {
      return DataStatus.error;
    }
    if (_studentContext.activeStudent.value == null) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage {
    final l10n = systemL10n();
    if (_studentContext.activeStudent.value == null) {
      return l10n.selectAStudent;
    }
    if (issuances.value.isEmpty) {
      return l10n.documentsEmpty;
    }
    return l10n.nothingToShowYet;
  }

  Future<void> loadDocuments() async {
    final studentId = _studentContext.activeStudentId;
    final yearId = _academicYear.selectedYearId.value;
    if (studentId == null || yearId == null) {
      issuances(const []);
      errorMessage('');
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final items = await listDocumentIssuances(
          _schoolClient(),
          studentId: studentId,
          academicYearId: yearId,
        );
        issuances(items);
      } on api.ApiError catch (error) {
        errorMessage(mutationFailureMessage(error, error.toString()));
        issuances(const []);
      } on Object catch (error) {
        errorMessage(error.toString());
        issuances(const []);
      }
    });
  }

  Future<DocumentJobResult> download(DocumentIssuanceRecord issuance) async {
    if (!issuance.isDownloadable) {
      if (issuance.isPending) {
        return const DocumentJobResult.rendering();
      }
      if (issuance.isFailed) {
        return DocumentJobResult.failed(issuance.failureCode);
      }
      return const DocumentJobResult.missing();
    }
    await openGrantedDocument(_schoolClient(), issuance.id);
    return const DocumentJobResult.opened();
  }
}
