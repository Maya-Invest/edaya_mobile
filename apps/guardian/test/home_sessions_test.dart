import 'dart:async';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:edaya_guardian_v2/features/home/dashboard_controller.dart';
import 'package:edaya_guardian_v2/features/calendar/models/calendar_session.dart';
import 'package:flutter_test/flutter_test.dart';

class _HomeRequests implements Transport {
  final timetable = <Completer<Map<String, dynamic>>>[];
  final cards = <Completer<Map<String, dynamic>>>[];
  final days = <String?>[];

  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    final reply = Completer<Map<String, dynamic>>();
    if (path.contains('/guardian/home/highlights')) {
      cards.add(reply);
      days.add(Uri.parse(path).queryParameters['day']);
    } else if (path.endsWith('/get-student-timetable')) {
      timetable.add(reply);
    } else {
      throw StateError(path);
    }
    return await reply.future as T;
  }
}

void main() {
  tz.initializeTimeZones();
  DashboardController controller(_HomeRequests reads) => DashboardController(
    client: createSchoolClient(reads),
    studentId: 'student',
    yearId: 'year',
    schoolId: 'school',
    timeZone: 'America/Toronto',
  );
  final highlights = {
    'cards': {'balance': 42},
    'attendance': {'one': 'late'},
    'unavailable': ['progress'],
  };
  final schedule = {
    'events': [
      {
        'id': 'one',
        'kind': 'lesson',
        'classGroupId': 'class',
        'title': 'Math',
        'startsAt': '2026-11-12T14:00:00Z',
        'endsAt': '2026-11-12T15:00:00Z',
      },
    ],
  };
  tearDown(() => SchoolClock.sample = null);

  testWidgets(
    'timetable appears while cards load and a partial denial preserves it',
    (tester) async {
      SchoolClock.sample = DateTime.utc(2026, 11, 12, 14, 30);
      final reads = _HomeRequests(), home = controller(reads);
      home.setVisible(true);
      reads.timetable.single.complete(schedule);
      await tester.pump();
      expect(home.preview.single.id, 'one');
      expect(home.highlights.value, isEmpty);
      reads.cards.single.complete(highlights);
      await tester.pump();
      expect(home.errors.value, {'progress'});
      expect(home.attendance.value, {'one': 'late'});
      expect(home.preview.single.id, 'one');
      home.setVisible(false);
    },
  );

  testWidgets(
    'late responses cannot restore a revoked child or a hidden dashboard',
    (tester) async {
      final reads = _HomeRequests(), home = controller(reads);
      home.setVisible(true);
      reads.cards.first.completeError(ApiError(403, 'Guardian access changed'));
      await tester.pump();
      reads.timetable.first.complete(schedule);
      await tester.pump();
      expect(home.sessions.value, isNull);
      expect(home.errors.value, contains('sessions'));
      home.setVisible(false);
      home.setVisible(true);
      reads.cards.last.complete(highlights);
      await tester.pump();
      expect(home.highlights.value['balance'], 42);
      home.setVisible(false);
      reads.timetable.last.complete(schedule);
      await tester.pump();
      expect(home.sessions.value, isNull);
    },
  );

  testWidgets(
    'school midnight refreshes both sections with the new local date',
    (tester) async {
      SchoolClock.sample = DateTime.utc(2026, 11, 13, 4, 59, 59);
      final reads = _HomeRequests(), home = controller(reads);
      home.setVisible(true);
      reads.timetable.first.complete({'events': []});
      await tester.pump();
      expect(reads.days, ['2026-11-12']);
      SchoolClock.sample = DateTime.utc(2026, 11, 13, 5);
      await tester.pump(const Duration(seconds: 2));
      expect(reads.days, ['2026-11-12', '2026-11-13']);
      reads.cards.first.complete(highlights);
      reads.cards.last.complete({
        'cards': {},
        'attendance': {},
        'unavailable': [],
      });
      reads.timetable.last.complete({'events': []});
      await tester.pump();
      expect(home.attendance.value, isEmpty);
      expect(home.highlights.value, isEmpty);
      home.setVisible(false);
    },
  );
  final day = DateTime(2026, 11, 12, 9, 30);
  CalendarSession session(
    String id,
    int hour, {
    String? status,
    int date = 12,
  }) => CalendarSession(
    id: id,
    title: id,
    kind: 'lesson',
    startsAt: DateTime(2026, 11, date, hour),
    endsAt: DateTime(2026, 11, date, hour + 1),
    status: status,
  );
  test(
    'current occurrence and the next one exclude cancelled and other days',
    () {
      expect(
        homeSessionPreview([
          session('finished', 8),
          session('now', 9),
          session('cancelled', 10, status: 'cancelled'),
          session('next', 11),
          session('tomorrow', 9, date: 13),
        ], day).map((s) => s.id),
        ['now', 'next'],
      );
    },
  );
  test(
    'between sessions returns the next two and end boundary removes the current session',
    () {
      final rows = [
        session('first', 9),
        session('second', 11),
        session('third', 12),
      ];
      expect(
        homeSessionPreview(rows, DateTime(2026, 11, 12, 10)).map((s) => s.id),
        ['second', 'third'],
      );
      expect(homeSessionPreview(rows, DateTime(2026, 11, 12, 13)), isEmpty);
    },
  );
}
