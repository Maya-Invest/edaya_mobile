import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_guardian_v2/features/scolarite/report_card_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Documents implements api.Transport {
  _Documents({required this.annual});
  final bool annual;
  final paths = <String>[];
  final queries = <Map<String, dynamic>>[];

  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    paths.add(path);
    if (path == '/core/entities/results/report') {
      return {
            'id': 'report',
            'aggregation': {'source': annual ? 'report_cards' : 'assessments'},
          }
          as T;
    }
    if (path == '/core/queries/list-document-issuances') {
      queries.add(options!.body as Map<String, dynamic>);
      return {
            'items': [
              {'id': 'document', 'status': 'requested'},
            ],
          }
          as T;
    }
    throw StateError('Unexpected request $path');
  }
}

void main() {
  for (final annual in [true, false]) {
    test(
      'report actions wait for download and use the ${annual ? "annual" : "period"} template',
      () async {
        final documents = _Documents(annual: annual);
        final controller = ReportCardController(
          reportCardId: 'report',
          downloadOnly: true,
          schoolClient: () => api.createSchoolClient(documents),
        );
        controller.onInit();
        addTearDown(controller.onClose);
        await Future<void>.delayed(Duration.zero);
        expect(documents.paths, isEmpty);
        await controller.downloadPdf();
        expect(documents.paths, [
          '/core/entities/results/report',
          '/core/queries/list-document-issuances',
        ]);
        expect(documents.queries.single, {
          'sourceId': 'report',
          'templateKey': annual ? 'annual-report-card.v1' : 'report-card.v1',
        });
        expect(controller.downloadStatus.value, ReportCardPdfStatus.pending);
      },
    );
  }
}
