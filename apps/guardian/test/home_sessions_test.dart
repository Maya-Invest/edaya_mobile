import 'package:edaya_guardian_v2/features/home/dashboard_controller.dart';
import 'package:edaya_guardian_v2/features/calendar/models/calendar_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
