import 'dart:async';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import '../calendar/models/calendar_session.dart';

List<CalendarSession> homeSessionPreview(
  Iterable<CalendarSession> sessions,
  DateTime now,
) {
  final rows =
      sessions
          .where(
            (s) =>
                !{'canceled', 'cancelled'}.contains(s.status) &&
                s.endsAt.isAfter(now) &&
                s.startsAt.year == now.year &&
                s.startsAt.month == now.month &&
                s.startsAt.day == now.day,
          )
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  final current = rows.where((s) => !s.startsAt.isAfter(now)).lastOrNull;
  return [
    ?current,
    ...rows.where((s) => s.startsAt.isAfter(now)).take(current == null ? 2 : 1),
  ];
}

class DashboardController extends LevitController {
  DashboardController({
    required this.client,
    required this.studentId,
    required this.yearId,
    required this.schoolId,
    this.timeZone = 'UTC',
    this.classGroupId,
  });
  final SchoolClient client;
  final String studentId, yearId, schoolId, timeZone;
  final String? classGroupId;
  final sessions = LxVar<List<CalendarSession>?>(null);
  final attendance = LxVar<Map<String, String>>({});
  final highlights = LxVar<Map<String, Object?>>({});
  final errors = LxVar<Set<String>>({});
  final now = LxVar<DateTime>(SchoolClock.now());
  late final tz.Location location = _location(timeZone);
  static const _sections = {
    'attendance',
    'results',
    'fees',
    'progress',
    'inbox',
    'surveys',
    'child',
  };
  Timer? _boundary;
  bool _visible = false;
  int _generation = 0;
  Completer<void>? _cancel;
  Future<void>? _pending;
  static tz.Location _location(String zone) {
    try {
      return tz.getLocation(zone);
    } on Object {
      return tz.UTC;
    }
  }

  List<CalendarSession> get preview =>
      homeSessionPreview(sessions.value ?? [], now.value);

  @override
  void onInit() {
    super.onInit();
    autoDispose(sessions);
    autoDispose(attendance);
    autoDispose(highlights);
    autoDispose(errors);
    autoDispose(now);
  }

  void setVisible(bool visible) {
    if (visible == _visible) return;
    _visible = visible;
    _cancelRead();
    if (visible) unawaited(refresh());
  }

  void _cancelRead() {
    _generation++;
    final old = _cancel;
    if (old != null && !old.isCompleted) old.complete();
    _cancel = null;
    _pending = null;
    _boundary?.cancel();
  }

  Future<void> refresh() {
    if (!_visible || isClosed) return Future.value();
    if (_pending != null) return _pending!;
    final generation = ++_generation;
    final cancel = Completer<void>();
    _cancel = cancel;
    final clock = tz.TZDateTime.from(SchoolClock.now(), location);
    final previous = now.value;
    if (previous.year != clock.year ||
        previous.month != clock.month ||
        previous.day != clock.day) {
      sessions(null);
      attendance({});
    }
    now(clock);
    final day =
        '${clock.year.toString().padLeft(4, '0')}-${clock.month.toString().padLeft(2, '0')}-${clock.day.toString().padLeft(2, '0')}';
    bool current() => !isClosed && _visible && generation == _generation;
    Future<void> schedule() async {
      try {
        final events = await fetchStudentTimetableOccurrences(
          client,
          studentId,
          range: PlanningDateRange(startDate: day, endDate: day),
        ).timeout(const Duration(seconds: 30));
        if (!current()) return;
        sessions(
          events
              .map(
                (o) => CalendarSession(
                  id: o.id,
                  title: o.title,
                  kind: o.kind,
                  startsAt: tz.TZDateTime.from(o.startsAt, location),
                  endsAt: tz.TZDateTime.from(o.endsAt, location),
                  classSubjectId: o.classSubjectId,
                  subjectLabel: o.subjectLabel,
                  status: o.status,
                ),
              )
              .toList(),
        );
        errors({...errors.value}..remove('sessions'));
        // Keep the existing midnight timer if this result arrived the next day.
        final arrived = tz.TZDateTime.from(SchoolClock.now(), location);
        if (arrived.year == clock.year &&
            arrived.month == clock.month &&
            arrived.day == clock.day) {
          _scheduleBoundary();
        }
      } on Object {
        if (!current()) return;
        sessions(null);
        errors({...errors.value, 'sessions'});
      }
    }

    Future<void> cards() async {
      try {
        final result = await client
            .getGuardianHighlights({
              'studentId': studentId,
              'academicYearId': yearId,
              'day': day,
              if (classGroupId != null) 'classGroupId': classGroupId,
            }, abortTrigger: cancel.future)
            .timeout(const Duration(seconds: 30));
        if (!current()) return;
        final values = Map<String, Object?>.from(result['cards'] as Map);
        if (values['dueDate'] is String) {
          values['dueDate'] = DateTime.parse(values['dueDate'] as String);
        }
        highlights(values);
        attendance(Map<String, String>.from(result['attendance'] as Map));
        errors({
          ...errors.value.difference(_sections),
          ...(result['unavailable'] as List).cast<String>(),
        });
      } on Object catch (error) {
        if (!current()) return;
        attendance({});
        highlights({});
        errors({...errors.value, ..._sections});
        if (error is ApiError && (error.status == 401 || error.status == 403)) {
          sessions(null);
          errors({...errors.value, 'sessions'});
          _cancelRead();
        }
      }
    }

    _scheduleBoundary();
    return _pending = Future.wait([schedule(), cards()])
        .then<void>((_) {})
        .whenComplete(() {
          if (current()) _pending = null;
        });
  }

  void _scheduleBoundary() {
    _boundary?.cancel();
    if (!_visible || isClosed) return;
    final clock = tz.TZDateTime.from(SchoolClock.now(), location);
    final midnight = tz.TZDateTime(
      location,
      clock.year,
      clock.month,
      clock.day + 1,
    );
    var next = midnight;
    for (final event in sessions.value ?? <CalendarSession>[]) {
      for (final boundary in [event.startsAt, event.endsAt]) {
        if (boundary.isAfter(clock) && boundary.isBefore(next)) {
          next = tz.TZDateTime.from(boundary, location);
        }
      }
    }
    _boundary = Timer(
      next.difference(clock) + const Duration(milliseconds: 20),
      () {
        if (!_visible || isClosed) return;
        if (!SchoolClock.now().isBefore(midnight)) {
          _cancelRead();
          unawaited(refresh());
        } else {
          now(tz.TZDateTime.from(SchoolClock.now(), location));
          _scheduleBoundary();
        }
      },
    );
  }

  @override
  void onClose() {
    _visible = false;
    _cancelRead();
    super.onClose();
  }
}
