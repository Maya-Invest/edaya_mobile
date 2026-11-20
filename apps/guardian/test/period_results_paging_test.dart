import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_guardian_v2/features/scolarite/period_results_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Transport implements Transport {
  _Transport(this.respond);
  final Object? Function(String method, Uri uri) respond;
  final paths = <String>[];

  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    final uri = Uri.parse(path);
    paths.add(uri.path);
    return respond(method, uri) as T;
  }
}

void main() {
  PeriodResultsController controller(_Transport transport) =>
      PeriodResultsController(
        client: createSchoolClient(transport),
        studentId: 'pupil',
        yearId: 'year',
        initialPeriod: 'period',
        subjectId: 'subject',
        focusMarkId: 'third',
      );

  final first = {
    'academicYearId': 'year',
    'periodId': 'period',
    'periodName': 'Term',
    'state': 'published',
    'section': {'sectionKind': 'subject', 'subjectId': 'subject'},
    'marks': [
      {'id': 'first'},
    ],
    'focusedMark': {'id': 'third'},
    'nextCursor': 'next',
  };

  test(
    'a direct link reads one page and merges a focused mark when paging catches up',
    () async {
      var attempts = 0;
      final transport = _Transport((method, uri) {
        expect(method, 'GET');
        expect(uri.path, '/core/guardian/results/subject');
        if (!uri.queryParameters.containsKey('cursor')) {
          expect(uri.queryParameters['focusMarkId'], 'third');
          return first;
        }
        if (attempts++ == 0) throw ApiError(503, 'Temporarily unavailable');
        return {
          ...first,
          'marks': [
            {'id': 'second'},
            {'id': 'third'},
          ],
          'focusedMark': null,
          'nextCursor': null,
        };
      });
      final c = controller(transport);
      await c.initialize();
      expect(transport.paths.length, 1);
      expect(c.marks.map((m) => m['id']), ['first', 'third']);
      await c.loadMore();
      expect(c.pageFailed.value, isTrue);
      expect(c.marks.length, 2);
      await c.loadMore();
      expect(c.pageFailed.value, isFalse);
      expect(c.marks.map((m) => m['id']), ['first', 'second', 'third']);
      expect(c.result.value!['nextCursor'], isNull);
    },
  );

  test(
    'a newer client can open a subject on a server with only the original read',
    () async {
      final transport = _Transport((method, uri) {
        if (method == 'GET') throw ApiError(405, 'Unsupported');
        if (uri.path.endsWith('/get-guardian-period-results')) {
          return {
            ...first,
            'sections': [first['section']],
          };
        }
        if (uri.path.endsWith('/academic-periods/list')) {
          return [
            {'id': 'period', 'name': 'Term'},
          ];
        }
        throw StateError(uri.path);
      });
      final c = controller(transport);
      await c.initialize();
      expect(c.failed.value, isFalse);
      expect(c.result.value!['periodName'], 'Term');
      expect(transport.paths.length, 3);
    },
  );

  test('revoked access clears loaded marks and never falls back', () async {
    final transport = _Transport((method, uri) {
      if (uri.queryParameters.containsKey('cursor')) {
        throw ApiError(403, 'Access revoked');
      }
      return first;
    });
    final c = controller(transport);
    await c.initialize();
    await c.loadMore();
    expect(c.failed.value, isTrue);
    expect(c.marks, isEmpty);
    expect(transport.paths, List.filled(2, '/core/guardian/results/subject'));
  });
}
