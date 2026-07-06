import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/src/api/planning_data.dart';
import 'package:flutter_test/flutter_test.dart';

class QueuedTransport implements Transport {
  QueuedTransport(this.responses);

  final List<Object?> responses;

  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    final next = responses.removeAt(0);
    if (next is Exception) {
      throw next;
    }
    return next as T;
  }
}

void main() {
  test('fetchClassTimetableOccurrences returns empty when loaders miss', () async {
    final transport = QueuedTransport([
      ApiError(404, const {}),
      ApiError(404, const {}),
      ApiError(404, const {}),
    ]);
    final client = createSchoolClient(transport);

    final occurrences = await fetchClassTimetableOccurrences(
      client,
      'cg-1',
      range: const PlanningDateRange(
        startDate: '2026-01-01',
        endDate: '2026-01-31',
      ),
    );

    expect(occurrences, isEmpty);
  });
}
