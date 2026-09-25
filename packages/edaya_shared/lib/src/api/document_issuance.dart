import 'dart:math';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/settings/app_settings_models.dart';
import '../features/settings/app_settings_storage.dart';
import '../l10n/l10n_extension.dart';
import 'mutation_feedback.dart';

typedef OpenDocumentUrl = Future<bool> Function(Uri uri);

OpenDocumentUrl openDocumentUrl = (uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
};

enum DocumentJobOutcome { opened, rendering, failed, missing }

class DocumentJobResult {
  const DocumentJobResult._(this.outcome, {this.failureCode});

  const DocumentJobResult.opened() : this._(DocumentJobOutcome.opened);
  const DocumentJobResult.rendering() : this._(DocumentJobOutcome.rendering);
  const DocumentJobResult.missing() : this._(DocumentJobOutcome.missing);
  const DocumentJobResult.failed([String? code])
    : this._(DocumentJobOutcome.failed, failureCode: code);

  final DocumentJobOutcome outcome;
  final String? failureCode;
}

const leftoverFamilyPaperTemplates = {
  'schooling-certificate.v1',
  'enrollment-record.v1',
  'student-id.v1',
  'student-id-card.v1',
  'withdrawal-certificate.v1',
  'convocation.v1',
};

bool isLeftoverFamilyPaper(String templateKey) =>
    leftoverFamilyPaperTemplates.contains(templateKey);

String leftoverFamilyPaperLabel(String templateKey) {
  return switch (templateKey) {
    'schooling-certificate.v1' => 'Certificat de scolarité',
    'enrollment-record.v1' => "Dossier d'inscription",
    'student-id.v1' || 'student-id-card.v1' => "Carte d'élève",
    'withdrawal-certificate.v1' => 'Certificat de radiation',
    'convocation.v1' => 'Convocation',
    _ => templateKey,
  };
}

class DocumentIssuanceRecord {
  const DocumentIssuanceRecord({
    required this.id,
    required this.templateKey,
    required this.status,
    required this.sourceId,
    this.title,
    this.number,
    this.failureCode,
    this.studentId,
    this.classGroupId,
    this.createdAt,
  });

  factory DocumentIssuanceRecord.fromJson(Map<String, dynamic> json) {
    return DocumentIssuanceRecord(
      id: json['id'] as String,
      templateKey: json['templateKey'] as String? ?? '',
      status: json['status'] as String? ?? 'requested',
      sourceId: json['sourceId'] as String? ?? '',
      title: json['title'] as String?,
      number: json['number'] as String?,
      failureCode: json['failureCode'] as String?,
      studentId: json['studentId'] as String?,
      classGroupId: json['classGroupId'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  final String id;
  final String templateKey;
  final String status;
  final String sourceId;
  final String? title;
  final String? number;
  final String? failureCode;
  final String? studentId;
  final String? classGroupId;
  final String? createdAt;

  bool get isDownloadable => status == 'ready' || status == 'preview';
  bool get isPending => status == 'requested' || status == 'rendering';
  bool get isFailed => status == 'failed';
  bool get isReplaced => status == 'superseded' || status == 'voided';
}

String documentRequestLocale() {
  final locale =
      AppSettingsStorage.cached.language.locale ??
      WidgetsBinding.instance.platformDispatcher.locale;
  return locale.languageCode == 'en' ? 'en' : 'fr';
}

String newDocumentRequestId() {
  final random = Random.secure();
  return '${DateTime.now().toUtc().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}';
}

String studentYearAccountSourceId({
  required String schoolId,
  required String studentId,
  required String academicYearId,
  required String currency,
}) {
  if (currency.trim().isEmpty) {
    throw ArgumentError('School finance currency is required');
  }
  return 'sya:$schoolId:$studentId:$academicYearId:${currency.trim()}';
}

String attendanceSheetSourceId(String classGroupId, DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '$classGroupId:${day.year}-$month-$date';
}

Map<String, dynamic> unwrapIssuance(Map<String, dynamic> result) {
  if (result['id'] is String && result['status'] is String) {
    return result;
  }
  final issuance = result['issuance'];
  if (issuance is Map<String, dynamic>) {
    return issuance;
  }
  throw StateError('Document issuance response was empty');
}

List<Map<String, dynamic>> unwrapIssuanceList(dynamic result) {
  if (result is List) {
    return result.whereType<Map<String, dynamic>>().toList();
  }
  if (result is Map<String, dynamic>) {
    final items = result['items'];
    if (items is List) {
      return items.whereType<Map<String, dynamic>>().toList();
    }
  }
  return const [];
}

Future<List<DocumentIssuanceRecord>> listDocumentIssuances(
  api.SchoolClient client, {
  String? studentId,
  String? academicYearId,
  String? classGroupId,
  String? templateKey,
  String? sourceId,
  String? status,
}) async {
  final result = await client.requestRoute<dynamic>(
    'POST',
    '/core/queries/list-document-issuances',
    body: {
      'studentId': ?studentId,
      'academicYearId': ?academicYearId,
      'classGroupId': ?classGroupId,
      'templateKey': ?templateKey,
      'sourceId': ?sourceId,
      'status': ?status,
    },
  );
  return unwrapIssuanceList(
    result,
  ).map(DocumentIssuanceRecord.fromJson).toList();
}

Future<DocumentIssuanceRecord> getDocumentIssuance(
  api.SchoolClient client,
  String id,
) async {
  final result = await client.runQuery('get-document-issuance', {'id': id});
  return DocumentIssuanceRecord.fromJson(unwrapIssuance(result));
}

Future<DocumentIssuanceRecord> requestDocumentIssuance(
  api.SchoolClient client, {
  required String templateKey,
  required String sourceId,
  String? academicYearId,
  String? academicPeriodId,
  String? classSubjectId,
  String? studentId,
  String? classGroupId,
  String? teacherId,
  Map<String, String>? staffFields,
  String? requestId,
  String? locale,
}) async {
  final result = await client.runCommand('request-document-issuance', {
    'requestId': requestId ?? newDocumentRequestId(),
    'templateKey': templateKey,
    'sourceId': sourceId,
    'locale': locale ?? documentRequestLocale(),
    'academicYearId': ?academicYearId,
    'academicPeriodId': ?academicPeriodId,
    'classSubjectId': ?classSubjectId,
    'studentId': ?studentId,
    'classGroupId': ?classGroupId,
    'teacherId': ?teacherId,
    'staffFields': ?staffFields,
  });
  return DocumentIssuanceRecord.fromJson(unwrapIssuance(result));
}

Future<void> openGrantedDocument(api.SchoolClient client, String id) async {
  final grant = await client.runQuery('grant-document-download', {'id': id});
  final url = grant['downloadUrl'] as String?;
  if (url == null || url.isEmpty) {
    throw StateError('Document download URL was empty');
  }
  final opened = await openDocumentUrl(Uri.parse(url));
  if (!opened) {
    throw StateError('Could not open the PDF');
  }
}

Future<DocumentIssuanceRecord> waitForTerminalIssuance(
  api.SchoolClient client,
  String id, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final started = DateTime.now();
  var latest = await getDocumentIssuance(client, id);
  while (DateTime.now().difference(started) < timeout) {
    if (!latest.isPending) {
      return latest;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    latest = await getDocumentIssuance(client, id);
  }
  return latest;
}

Future<DocumentJobResult> downloadReadyIssuance(
  api.SchoolClient client, {
  required String sourceId,
  String? templateKey,
  String? studentId,
  String? academicYearId,
}) async {
  final items = await listDocumentIssuances(
    client,
    studentId: studentId,
    academicYearId: academicYearId,
    templateKey: templateKey,
    sourceId: sourceId,
  );
  final ready = items.where((item) => item.isDownloadable).toList();
  if (ready.isNotEmpty) {
    await openGrantedDocument(client, ready.first.id);
    return const DocumentJobResult.opened();
  }
  if (items.any((item) => item.isPending)) {
    return const DocumentJobResult.rendering();
  }
  final failed = items.where((item) => item.isFailed).toList();
  if (failed.isNotEmpty) {
    return DocumentJobResult.failed(failed.first.failureCode);
  }
  return const DocumentJobResult.missing();
}

Future<DocumentJobResult> requestAndOpenDocument(
  api.SchoolClient client, {
  required String templateKey,
  required String sourceId,
  String? academicYearId,
  String? academicPeriodId,
  String? classSubjectId,
  String? studentId,
  String? classGroupId,
  String? teacherId,
}) async {
  final requested = await requestDocumentIssuance(
    client,
    templateKey: templateKey,
    sourceId: sourceId,
    academicYearId: academicYearId,
    academicPeriodId: academicPeriodId,
    classSubjectId: classSubjectId,
    studentId: studentId,
    classGroupId: classGroupId,
    teacherId: teacherId,
  );
  final settled = await waitForTerminalIssuance(client, requested.id);
  if (settled.isDownloadable) {
    await openGrantedDocument(client, settled.id);
    return const DocumentJobResult.opened();
  }
  if (settled.isFailed) {
    return DocumentJobResult.failed(settled.failureCode);
  }
  return const DocumentJobResult.rendering();
}

String documentJobMessage(AppLocalizations l10n, DocumentJobResult result) {
  return switch (result.outcome) {
    DocumentJobOutcome.opened => l10n.documentsOpened,
    DocumentJobOutcome.rendering => l10n.documentsRendering,
    DocumentJobOutcome.missing => l10n.documentsNotIssued,
    DocumentJobOutcome.failed => l10n.documentsFailed(result.failureCode ?? ''),
  };
}

void showDocumentJobSnackBar(BuildContext context, DocumentJobResult result) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(
    SnackBar(content: Text(documentJobMessage(context.tr, result))),
  );
}

String documentStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'requested' => l10n.documentStatusRequested,
    'rendering' => l10n.documentStatusRendering,
    'ready' => l10n.documentStatusReady,
    'failed' => l10n.documentStatusFailed,
    'superseded' => l10n.documentStatusSuperseded,
    'voided' => l10n.documentStatusVoided,
    'preview' => l10n.documentStatusPreview,
    _ => status,
  };
}

class DocumentActionButton extends StatefulWidget {
  const DocumentActionButton({
    super.key,
    required this.label,
    required this.run,
    this.icon = Icons.picture_as_pdf_outlined,
  });

  final String label;
  final Future<DocumentJobResult> Function() run;
  final IconData icon;

  @override
  State<DocumentActionButton> createState() => _DocumentActionButtonState();
}

class _DocumentActionButtonState extends State<DocumentActionButton> {
  bool _busy = false;

  Future<void> _handle() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await widget.run();
      if (mounted) {
        showDocumentJobSnackBar(context, result);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              mutationFailureMessage(error, context.tr.documentsOpenFailed),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: _busy ? null : _handle,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(widget.icon),
      label: Text(widget.label),
    );
  }
}
