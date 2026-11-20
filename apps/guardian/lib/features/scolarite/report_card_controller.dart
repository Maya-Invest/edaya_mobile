import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common/utils/academic_period.dart';
import 'models/report_card_summary.dart';

enum ReportCardPdfStatus { idle, downloading, pending, missing, failed }

class ReportCardController extends LevitController
    with LevitReactiveTasksMixin {
  ReportCardController({
    required this.reportCardId,
    required SchoolClientFactory schoolClient,
    this.downloadOnly = false,
  }) : _schoolClient = schoolClient;

  final String reportCardId;
  final bool downloadOnly;
  final SchoolClientFactory _schoolClient;

  final detail = LxVar<ReportCardDetail?>(null);
  final errorMessage = LxVar('');
  final downloadStatus = LxVar(ReportCardPdfStatus.idle);
  final downloadMessage = LxVar('');
  String? _templateKey;

  String _reportTemplate(Map<String, dynamic> row) =>
      (row['aggregation'] as Map?)?['source'] == 'report_cards'
      ? 'annual-report-card.v1'
      : 'report-card.v1';

  @override
  void onInit() {
    super.onInit();
    autoDispose(detail);
    autoDispose(errorMessage);
    autoDispose(downloadStatus);
    autoDispose(downloadMessage);
    if (!downloadOnly) unawaited(loadDetail());
  }

  Future<void> loadDetail() async {
    await runTask(() async {
      try {
        final client = _schoolClient();
        final row = await client.results.get(reportCardId);
        _templateKey = _reportTemplate(row);
        final (periodName, subjectNameByClassSubjectId) = await (
          _periodName(client, row['periodId'] as String?),
          _loadSubjectNames(client, row),
        ).wait;
        detail(
          ReportCardDetail.fromJson(
            row,
            periodName: periodName,
            subjectNameByClassSubjectId: subjectNameByClassSubjectId,
          ),
        );
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadReportCard(error.toString()));
        detail(null);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadReportCard(error.toString()));
        detail(null);
      }
    });
  }

  Future<void> downloadPdf() async {
    if (downloadStatus.value == ReportCardPdfStatus.downloading) return;

    downloadStatus(ReportCardPdfStatus.downloading);
    downloadMessage('');

    try {
      final client = _schoolClient();
      final templateKey = _templateKey ??= _reportTemplate(
        await client.results.get(reportCardId),
      );
      if (isClosed) return;
      final issuance = await downloadReadyIssuance(
        client,
        sourceId: reportCardId,
        templateKey: templateKey,
      );
      if (issuance.outcome == DocumentJobOutcome.opened) {
        downloadStatus(ReportCardPdfStatus.idle);
        return;
      }
      if (issuance.outcome == DocumentJobOutcome.rendering) {
        downloadStatus(ReportCardPdfStatus.pending);
        downloadMessage(systemL10n().thePdfIsBeingGeneratedTryAgainShortly);
        return;
      }

      final lookup = await _lookupReadyPdf(client);
      switch (lookup.status) {
        case _PdfLookupStatus.ready:
          final response = await client.getDownloadUrl(
            attachmentId: lookup.attachmentId!,
          );
          final url = response['downloadUrl'] as String?;
          if (url == null || url.isEmpty) {
            downloadStatus(ReportCardPdfStatus.failed);
            downloadMessage(systemL10n().downloadLinkUnavailable);
            return;
          }
          final uri = Uri.parse(url);
          final opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!opened) {
            downloadStatus(ReportCardPdfStatus.failed);
            downloadMessage(systemL10n().documentsOpenFailed);
            return;
          }
          downloadStatus(ReportCardPdfStatus.idle);
        case _PdfLookupStatus.pending:
          downloadStatus(ReportCardPdfStatus.pending);
          downloadMessage(systemL10n().thePdfIsBeingGeneratedTryAgainShortly);
        case _PdfLookupStatus.missing:
          downloadStatus(ReportCardPdfStatus.missing);
          downloadMessage(systemL10n().noPdfIsAvailableForThisReportCard);
      }
    } on api.ApiError catch (error) {
      downloadStatus(ReportCardPdfStatus.failed);
      downloadMessage(error.toString());
    } on Object catch (error) {
      downloadStatus(ReportCardPdfStatus.failed);
      downloadMessage(error.toString());
    }
  }

  Future<_PdfLookup> _lookupReadyPdf(api.SchoolClient client) async {
    const attempts = 4;
    const delay = Duration(milliseconds: 750);
    var last = const _PdfLookup(status: _PdfLookupStatus.missing);

    for (var attempt = 0; attempt < attempts; attempt++) {
      final rows = await client.attachments.list({
        'ownerKind': 'report_card',
        'ownerId': reportCardId,
      });
      final ready = rows.where(_isReadyPdf).firstOrNull;
      if (ready != null) {
        return _PdfLookup(
          status: _PdfLookupStatus.ready,
          attachmentId: ready['id'] as String,
        );
      }
      if (rows.any((row) => row['status'] == 'pending_upload')) {
        last = const _PdfLookup(status: _PdfLookupStatus.pending);
      } else {
        last = const _PdfLookup(status: _PdfLookupStatus.missing);
      }
      if (attempt < attempts - 1) {
        await Future<void>.delayed(delay);
      }
    }
    return last;
  }

  bool _isReadyPdf(Map<String, dynamic> attachment) {
    if (attachment['status'] != 'ready') return false;
    final mime = (attachment['mimeType'] as String?)?.toLowerCase() ?? '';
    final name = (attachment['fileName'] as String?)?.toLowerCase() ?? '';
    return mime == 'application/pdf' || name.endsWith('.pdf');
  }

  Future<String> _periodName(api.SchoolClient client, String? periodId) async {
    if (periodId == null) return systemL10n().periodFallback;
    try {
      return academicPeriodLabel(await client.academicPeriods.get(periodId));
    } on Object {
      return periodId;
    }
  }

  Future<Map<String, String>> _loadSubjectNames(
    api.SchoolClient client,
    Map<String, dynamic> report,
  ) async {
    final classGroupId = report['classGroupId'] as String?;
    if (classGroupId == null) return const {};
    final missing = <String>{};
    void collect(dynamic sections) {
      if (sections is! List) return;
      for (final row in sections.whereType<Map>()) {
        if (row['sectionKind'] == 'module') {
          collect(row['subResults']);
        } else if (row['sectionKind'] == 'subject' && row['name'] == null) {
          final id = row['classSubjectId'];
          if (id is String && id.isNotEmpty) missing.add(id);
        }
      }
    }

    collect(report['sectionResults']);
    if (missing.isEmpty) return const {};
    final classSubjectRows = await client.classSubjects.listAll({
      ...classGroupScope(classGroupId),
      ...entitiesByIds(missing.toList()),
    });
    final subjectIds = classSubjectRows
        .map((row) => row['subjectId'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final subjectRows = subjectIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await client.subjects.listAll(entitiesByIds(subjectIds));
    final subjectNameById = {
      for (final subject in subjectRows)
        subject['id'] as String:
            subject['name'] as String? ?? subject['id'] as String,
    };

    return {
      for (final classSubject in classSubjectRows)
        classSubject['id'] as String:
            subjectNameById[classSubject['subjectId'] as String] ??
            classSubject['subjectId'] as String,
    };
  }
}

enum _PdfLookupStatus { ready, pending, missing }

class _PdfLookup {
  const _PdfLookup({required this.status, this.attachmentId});

  final _PdfLookupStatus status;
  final String? attachmentId;
}
