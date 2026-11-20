import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' show ApiError;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../calendar/teacher_session.dart';

/// One visible Home workspace. Keep its last confirmed day while revalidating.
class HomeTimetableController extends LevitController {
  HomeTimetableController({
    required this.read,
    required this.schoolNow,
    required this.classId,
  });

  final Future<List<TeacherSession>> Function(PlanningDateRange) read;
  final tz.TZDateTime Function() schoolNow;
  final String classId;
  static const pollInterval = Duration(minutes: 1);
  static const _readTimeout = Duration(seconds: 90);
  final entries = LxVar<List<TeacherSession>?>(null);
  final failed = LxVar(false);
  late final clock = LxVar(schoolNow());
  Timer? _poll, _boundary;
  bool _visible = false;
  int _generation = 0;
  Future<void>? _pending;

  @override
  void onInit() {
    super.onInit();
    autoDispose(entries);
    autoDispose(failed);
    autoDispose(clock);
  }

  List<TeacherSession> get preview => homeLessonPreview(
    entries.value ?? const [],
    now: clock.value,
    schoolTime: (t) => tz.TZDateTime.from(t, clock.value.location),
    classIds: [classId],
  );

  void setVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    _poll?.cancel();
    _boundary?.cancel();
    if (!visible) {
      // A request made before Home was covered must not replace a newer read on resume.
      _generation++;
      _pending = null;
      return;
    }
    unawaited(refresh());
    _poll = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() {
    if (!_visible || isClosed) return Future.value();
    final now = schoolNow();
    if (!isSameCalendarDay(now, clock.value)) {
      _generation++;
      _pending = null;
      entries(null);
      failed(false);
    }
    clock(now);
    _scheduleBoundary();
    final pending = _pending;
    if (pending != null) return pending;
    final generation = ++_generation;
    return _pending = _readDay(now, generation).whenComplete(() {
      if (!isClosed && generation == _generation) _pending = null;
    });
  }

  Future<void> _readDay(tz.TZDateTime now, int generation) async {
    final start = tz.TZDateTime(now.location, now.year, now.month, now.day);
    final end = tz.TZDateTime(now.location, now.year, now.month, now.day + 1);
    String dateKey(DateTime time) =>
        time.toUtc().toIso8601String().substring(0, 10);
    try {
      final rows = await read(
        PlanningDateRange(
          startDate: dateKey(start),
          endDate: dateKey(end.subtract(const Duration(microseconds: 1))),
        ),
      ).timeout(_readTimeout);
      if (isClosed || generation != _generation) return;
      entries(rows);
      failed(false);
    } on Object catch (error) {
      if (isClosed || generation != _generation) return;
      if (error is ApiError && (error.status == 401 || error.status == 403)) {
        entries(null);
      }
      failed(true);
    }
    final current = schoolNow();
    if (!isSameCalendarDay(now, current)) {
      if (_visible) unawaited(refresh());
      return;
    }
    clock(current);
    _scheduleBoundary();
  }

  // The clock advances at known lesson boundaries even if a read is still pending.
  void _scheduleBoundary() {
    _boundary?.cancel();
    if (!_visible || isClosed) return;
    final now = clock.value;
    var next = tz.TZDateTime(now.location, now.year, now.month, now.day + 1);
    for (final lesson in preview) {
      for (final at in [lesson.startsAt, lesson.endsAt]) {
        if (at.isAfter(now) && at.isBefore(next)) {
          next = tz.TZDateTime.from(at, now.location);
        }
      }
    }
    _boundary = Timer(
      next.difference(now) + const Duration(milliseconds: 10),
      () {
        final current = schoolNow();
        if (!isSameCalendarDay(current, clock.value)) {
          unawaited(refresh());
        } else {
          clock(current);
          _scheduleBoundary();
        }
      },
    );
  }

  @override
  void onClose() {
    _generation++;
    _visible = false;
    _poll?.cancel();
    _boundary?.cancel();
    super.onClose();
  }
}
