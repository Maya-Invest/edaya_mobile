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
  }) : _schoolClient = schoolClient;

  final String reportCardId;
  final SchoolClientFactory _schoolClient;

  final detail = LxVar<ReportCardDetail?>(null);
  final errorMessage = LxVar('');
  final downloadStatus = LxVar(ReportCardPdfStatus.idle);
  final downloadMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(detail);
    autoDispose(errorMessage);
    autoDispose(downloadStatus);
    autoDispose(downloadMessage);
    unawaited(loadDetail());
  }

  Future<void> loadDetail() async {
    await runTask(() async {
      try {
        final client = _schoolClient();
        final row = await client.results.get(reportCardId);
        var periodName =
            row['periodId'] as String? ?? systemL10n().periodFallback;
        final periodId = row['periodId'] as String?;
        if (periodId != null) {
          try {
            // Report-card results identify their period, but do not carry a year.
            final period = await client.academicPeriods.get(periodId);
            periodName = academicPeriodLabel(period);
          } on Object {
            // fallback
          }
        }

        final classGroupId = row['classGroupId'] as String?;
        final subjectNameByClassSubjectId = classGroupId == null
            ? const <String, String>{}
            : await _loadSubjectNames(client, classGroupId);
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
      final issuance = await downloadReadyIssuance(
        client,
        sourceId: reportCardId,
        templateKey: 'report-card.v1',
      );
      if (issuance.outcome == DocumentJobOutcome.opened) {
        downloadStatus(ReportCardPdfStatus.idle);
        return;
      }
      if (issuance.outcome == DocumentJobOutcome.rendering) {
        downloadStatus(ReportCardPdfStatus.pending);
        downloadMessage(
          'Le PDF est en cours de génération. Réessayez dans un instant.',
        );
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
            downloadMessage('Lien de téléchargement indisponible.');
            return;
          }
          final uri = Uri.parse(url);
          final opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!opened) {
            downloadStatus(ReportCardPdfStatus.failed);
            downloadMessage('Impossible d\'ouvrir le PDF.');
            return;
          }
          downloadStatus(ReportCardPdfStatus.idle);
        case _PdfLookupStatus.pending:
          downloadStatus(ReportCardPdfStatus.pending);
          downloadMessage(
            'Le PDF est en cours de génération. Réessayez dans un instant.',
          );
        case _PdfLookupStatus.missing:
          downloadStatus(ReportCardPdfStatus.missing);
          downloadMessage('Aucun PDF disponible pour ce bulletin.');
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

  Future<Map<String, String>> _loadSubjectNames(
    api.SchoolClient client,
    String classGroupId,
  ) async {
    final classSubjectRows = await client.classSubjects.list(
      classGroupScope(classGroupId),
    );
    final subjectIds = classSubjectRows
        .map((row) => row['subjectId'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final subjectRows = subjectIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await client.subjects.list(entitiesByIds(subjectIds));
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
