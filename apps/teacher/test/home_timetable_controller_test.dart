import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' show ApiError;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher_v2/features/calendar/teacher_session.dart';
import 'package:edaya_teacher_v2/features/home/home_timetable_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tzdata.initializeTimeZones();
  testWidgets(
    'visible Home discovers lessons, retains its preview on a slow or failed read and expires an ended lesson on time',
    (tester) async {
      final start = tz.TZDateTime.utc(2026, 11, 8, 10);
      final origin = tester.binding.clock.now();
      final scope = Levit.createScope('today');
      final requests = <Completer<List<TeacherSession>>>[];
      final c = scope.put(
        () => HomeTimetableController(
          schoolNow: () =>
              start.add(tester.binding.clock.now().difference(origin)),
          classId: 'a',
          read: (_) {
            final read = Completer<List<TeacherSession>>();
            requests.add(read);
            return read.future;
          },
        ),
      );
      final lesson = TeacherSession(
        id: 'new',
        title: 'New lesson',
        kind: 'lesson',
        startsAt: start.add(const Duration(minutes: 2)),
        endsAt: start.add(const Duration(minutes: 3, seconds: 30)),
        classGroupId: 'a',
        classLabel: 'A',
        subjectLabel: 'EPS',
      );
      try {
        c.setVisible(true);
        requests.first.complete([]);
        await tester.pump();
        expect(c.entries.value, isEmpty);
        await tester.pump(const Duration(minutes: 1));
        expect(requests, hasLength(2));
        requests.last.complete([lesson]);
        await tester.pump();
        expect(c.preview.single.id, 'new');
        await tester.pump(const Duration(minutes: 1, milliseconds: 20));
        expect(requests, hasLength(3));
        expect(c.preview.single.startsAt.isAfter(c.clock.value), false);
        await tester.pump(const Duration(minutes: 1));
        expect(
          requests,
          hasLength(3),
          reason: 'The delayed poll must be shared',
        );
        expect(c.preview.single.id, 'new');
        requests.last.completeError(TimeoutException('offline'));
        await tester.pump();
        expect(c.failed.value, true);
        expect(c.preview.single.id, 'new');
        await tester.pump(const Duration(seconds: 31));
        expect(c.preview, isEmpty);
        c.setVisible(false);
        await tester.pump(const Duration(minutes: 5));
        expect(requests, hasLength(3));
        c.setVisible(true);
        expect(requests, hasLength(4));
        requests.last.completeError(ApiError(403, {}));
        await tester.pump();
        expect(
          c.entries.value,
          isNull,
          reason: 'A revoked grant must clear the saved day',
        );
      } finally {
        scope.dispose();
      }
    },
  );

  testWidgets(
    'school midnight changes the UTC range and ignores a previous day response',
    (tester) async {
      final location = tz.getLocation('Europe/Paris');
      final start = tz.TZDateTime(location, 2026, 10, 24, 23, 59, 45);
      final origin = tester.binding.clock.now();
      final scope = Levit.createScope('midnight');
      final ranges = <PlanningDateRange>[];
      final requests = <Completer<List<TeacherSession>>>[];
      final c = scope.put(
        () => HomeTimetableController(
          classId: 'a',
          schoolNow: () =>
              start.add(tester.binding.clock.now().difference(origin)),
          read: (range) {
            ranges.add(range);
            final read = Completer<List<TeacherSession>>();
            requests.add(read);
            return read.future;
          },
        ),
      );
      try {
        c.setVisible(true);
        await tester.pump(const Duration(seconds: 16));
        expect(ranges.map((r) => [r.startDate, r.endDate]), [
          ['2026-10-23', '2026-10-24'],
          ['2026-10-24', '2026-10-25'],
        ]);
        requests[1].complete([]);
        await tester.pump();
        requests[0].completeError(TimeoutException('old day'));
        await tester.pump();
        expect(c.entries.value, isEmpty);
        expect(c.failed.value, false);
      } finally {
        scope.dispose();
      }
    },
  );
  testWidgets(
    'returning to Home refreshes immediately and ignores a delayed pre-background result',
    (tester) async {
      final scope = Levit.createScope('resume');
      final requests = <Completer<List<TeacherSession>>>[];
      final c = scope.put(
        () => HomeTimetableController(
          classId: 'a',
          schoolNow: () => tz.TZDateTime.utc(2026, 11, 8, 10),
          read: (_) {
            final read = Completer<List<TeacherSession>>();
            requests.add(read);
            return read.future;
          },
        ),
      );
      try {
        c.setVisible(true);
        requests.first.complete([]);
        await tester.pump(const Duration(seconds: 60));
        expect(requests, hasLength(2));
        c.setVisible(false);
        await tester.pump(const Duration(minutes: 3));
        expect(requests, hasLength(2));
        c.setVisible(true);
        expect(requests, hasLength(3));
        requests.last.complete([]);
        await tester.pump();
        requests[1].completeError(ApiError(403, {}));
        await tester.pump();
        expect(c.entries.value, isEmpty);
        expect(c.failed.value, false);
      } finally {
        scope.dispose();
      }
    },
  );
  testWidgets('an unresponsive timetable cannot block subsequent polls', (
    tester,
  ) async {
    final scope = Levit.createScope('stalled-timetable');
    final stalled = Completer<List<TeacherSession>>();
    var calls = 0;
    final c = scope.put(
      () => HomeTimetableController(
        classId: 'a',
        schoolNow: () => tz.TZDateTime.utc(2026, 11, 8, 10),
        read: (_) async => ++calls == 1 ? stalled.future : <TeacherSession>[],
      ),
    );
    try {
      c.setVisible(true);
      await tester.pump(const Duration(seconds: 91));
      expect(c.failed.value, true);
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 2);
      expect(c.entries.value, isEmpty);
      stalled.completeError(ApiError(403, {}));
      await tester.pump();
      expect(c.failed.value, false);
      expect(c.entries.value, isEmpty);
    } finally {
      scope.dispose();
    }
  });
}
