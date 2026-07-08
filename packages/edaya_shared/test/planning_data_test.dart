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
  test(
    'fetchClassTimetableOccurrences uses timetable query presentation fields',
    () async {
      final transport = QueuedTransport([
        {
          'events': [
            {
              'kind': 'lesson',
              'id': 'ls-1',
              'lessonSessionId': 'ls-1',
              'classGroupId': 'cg-1',
              'classSubjectId': 'cs-1',
              'startsAt': '2026-01-15T08:00:00.000Z',
              'endsAt': '2026-01-15T09:00:00.000Z',
              'title': 'Math',
              'subjectLabel': 'Mathematics',
              'teacherName': 'Ada Lovelace',
            },
          ],
        },
        [
          {
            'id': 'ls-1',
            'classSubjectId': 'cs-1',
            'status': 'pending',
          },
        ],
      ]);
      final client = createSchoolClient(transport);

      final occurrences = await fetchClassTimetableOccurrences(
        client,
        'cg-1',
        range: const PlanningDateRange(
          startDate: '2026-01-01',
          endDate: '2026-01-31',
        ),
        enrichStaffWorkspace: false,
      );

      expect(occurrences, hasLength(1));
      expect(occurrences.first.subjectLabel, 'Mathematics');
      expect(occurrences.first.teacherName, 'Ada Lovelace');
      expect(transport.responses, isEmpty);
    },
  );

  test(
    'fetchClassTimetableOccurrences skips staff enrichment when disabled',
    () async {
      final transport = QueuedTransport([
        {
          'events': [
            {
              'kind': 'activity',
              'id': 'act-sess-1',
              'activitySessionId': 'act-sess-1',
              'classGroupId': 'cg-1',
              'startsAt': '2026-01-15T10:00:00.000Z',
              'endsAt': '2026-01-15T11:00:00.000Z',
              'title': 'Swimming',
              'activityId': 'act-1',
            },
          ],
        },
        [
          {
            'id': 'act-sess-1',
            'activityId': 'act-1',
            'status': 'scheduled',
          },
        ],
      ]);
      final client = createSchoolClient(transport);

      final occurrences = await fetchClassTimetableOccurrences(
        client,
        'cg-1',
        range: const PlanningDateRange(
          startDate: '2026-01-01',
          endDate: '2026-01-31',
        ),
        enrichStaffWorkspace: false,
      );

      expect(occurrences, hasLength(1));
      expect(occurrences.first.subjectLabel, 'Swimming');
      expect(transport.responses, isEmpty);
    },
  );

  test(
    'fetchClassTimetableOccurrences tolerates activities list 403',
    () async {
      final transport = QueuedTransport([
        {
          'events': [
            {
              'kind': 'activity',
              'id': 'act-sess-1',
              'activitySessionId': 'act-sess-1',
              'classGroupId': 'cg-1',
              'startsAt': '2026-01-15T10:00:00.000Z',
              'endsAt': '2026-01-15T11:00:00.000Z',
              'title': 'Swimming',
              'activityId': 'act-1',
            },
          ],
        },
        [
          {
            'id': 'act-sess-1',
            'activityId': 'act-1',
            'status': 'scheduled',
          },
        ],
        const <Map<String, dynamic>>[],
        ApiError(403, const {}),
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

      expect(occurrences, hasLength(1));
      expect(occurrences.first.kind, 'activity');
      expect(occurrences.first.title, 'Swimming');
      expect(occurrences.first.subjectLabel, 'Swimming');
    },
  );

  test(
    'fetchClassTimetableOccurrences returns empty when loaders miss',
    () async {
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
    },
  );
}
