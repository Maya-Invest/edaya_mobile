import 'dart:async';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import '../calendar/models/calendar_session.dart';
import '../fees/models/student_charge_line.dart';
import '../scolarite/academic_data.dart';

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
    this.guardianSubjectId,
    this.classGroupId,
  });
  final SchoolClient client;
  final String studentId, yearId, schoolId;
  final String? guardianSubjectId, classGroupId;
  final sessions = LxVar<List<CalendarSession>?>(null);
  final attendance = LxVar<Map<String, String>>({});
  final highlights = LxVar<Map<String, Object?>>({});
  final errors = LxVar<Set<String>>({});
  final now = LxVar<DateTime>(DateTime.now());
  tz.Location location = tz.UTC;
  Timer? _poll, _boundary;
  bool _visible = false;
  int _generation = 0;
  Future<void>? _pending;
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

  void setVisible(bool value) {
    if (value == _visible) return;
    _visible = value;
    _poll?.cancel();
    _boundary?.cancel();
    if (value) {
      unawaited(refresh());
      _poll = Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(refresh()),
      );
    }
  }

  Future<void> refresh() {
    if (!_visible || isClosed) return Future.value();
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final failed = <String>{};
    bool revoked = false;
    final next = <String, Object?>{};
    Future<T?> read<T>(String key, Future<T> Function() load) async {
      try {
        return await load().timeout(const Duration(seconds: 30));
      } catch (e) {
        failed.add(key);
        if (e is ApiError && (e.status == 401 || e.status == 403)) {
          revoked = true;
          if (!isClosed && generation == _generation) {
            sessions(null);
            attendance({});
            highlights({});
          }
        }
        return null;
      }
    }

    final school = await read('school', () => client.schools.get(schoolId));
    try {
      location = tz.getLocation(school?['timeZone'] as String? ?? 'UTC');
    } catch (_) {
      location = tz.UTC;
    }
    final clock = tz.TZDateTime.now(location);
    if (isClosed || generation != _generation) return;
    if (now.value.year != clock.year ||
        now.value.month != clock.month ||
        now.value.day != clock.day) {
      sessions(null);
      attendance({});
    }
    now(clock);
    String date(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final occurrences = await read(
      'sessions',
      () => fetchStudentTimetableOccurrences(
        client,
        studentId,
        range: PlanningDateRange(startDate: date(clock), endDate: date(clock)),
      ),
    );
    if (isClosed || generation != _generation) return;
    if (occurrences != null) {
      sessions(
        occurrences
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
    }
    final records = await read(
      'attendance',
      () => client.attendance.listAll({'studentId': studentId}),
    );
    if (records != null) {
      final map = <String, String>{};
      for (final r in records) {
        final id =
            r['lessonSessionId'] ?? r['activitySessionId'] ?? r['assessmentId'];
        if (id is String && r['status'] is String) {
          map[id] = r['status'] as String;
        }
      }
      if (!isClosed && generation == _generation) attendance(map);
      next['absent'] = records.where((r) => r['status'] == 'absent').length;
      next['late'] = records.where((r) => r['status'] == 'late').length;
    }
    await Future.wait([
      read('fees', () async {
        final rows = await client.studentCharges.listAll({
          'studentId': studentId,
          'academicYearId': yearId,
        });
        final charges = rows
            .where((r) => r['status'] != 'cancelled')
            .map(StudentChargeLine.fromJson)
            .toList();
        next['overdue'] = charges
            .where(
              (r) =>
                  r.status == ChargeStatus.overdue ||
                  (r.remainingObligation > 0 &&
                      r.dueDate != null &&
                      r.dueDate!.isBefore(clock)),
            )
            .length;
        final upcoming =
            charges
                .where((r) => r.remainingObligation > 0 && r.dueDate != null)
                .toList()
              ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
        next['dueDate'] = upcoming.firstOrNull?.dueDate;
        next['balance'] = charges.fold<int>(
          0,
          (sum, r) => sum + r.remainingObligation,
        );
      }),
      read('results', () async {
        final rows = await client.results.listAll({
          'studentId': studentId,
          'status': 'published',
        });
        next['reports'] = rows.length;
        if (rows.isEmpty) {
          final marks = await client.assessmentResults.listAll({
            'studentId': studentId,
          });
          next['marks'] = marks.length;
        }
      }),
      read('inbox', () async {
        if (guardianSubjectId == null) return;
        final rows = await client.messageDeliveries.listAll({
          'subjectId': guardianSubjectId,
        });
        next['unread'] = rows.where((r) => r['status'] != 'read').length;
      }),
      read('child', () async {
        final rows = await client.studentPhotoSubmissions.listAll({
          'studentId': studentId,
        });
        rows.sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
        next['photo'] = rows.firstOrNull?['status'];
        final documents = await listDocumentIssuances(
          client,
          studentId: studentId,
          academicYearId: yearId,
        );
        next['documents'] = documents
            .where(
              (d) =>
                  isLeftoverFamilyPaper(d.templateKey) &&
                  (d.isDownloadable || d.isPending),
            )
            .length;
      }),
      read('progress', () async {
        if (classGroupId == null) return;
        final options = await fetchClassSubjectOptions(
          client: client,
          studentId: studentId,
          classGroupId: classGroupId!,
          classLabel: '',
          subjectFallback: '—',
        );
        final overviews = await Future.wait(
          options.map(
            (o) => fetchCurriculumProgressOverview(
              client: client,
              classSubjectId: o.id,
              matterFallback: '—',
            ),
          ),
        );
        next['progress'] = overviews.isEmpty
            ? null
            : (overviews.fold<double>(
                        0,
                        (sum, o) => sum + o.classSubjectCompletedPercentage,
                      ) /
                      overviews.length)
                  .round();
      }),
      read('surveys', () async {
        final rows = await listGuardianFamilyFeedbackCampaigns(client);
        next['surveys'] = rows
            .where((r) => r.studentId == studentId && r.slotState == 'open')
            .length;
      }),
    ]);
    if (isClosed || generation != _generation) return;
    if (revoked) {
      sessions(null);
      attendance({});
      highlights({});
      errors({
        'sessions',
        'attendance',
        'results',
        'fees',
        'progress',
        'inbox',
        'surveys',
        'child',
      });
      return;
    }
    highlights({...highlights.value, ...next});
    errors(failed);
    now(tz.TZDateTime.now(location));
    _schedule();
  }

  void _schedule() {
    _boundary?.cancel();
    if (!_visible || isClosed) return;
    final clock = tz.TZDateTime.now(location);
    var at = tz.TZDateTime(location, clock.year, clock.month, clock.day + 1);
    for (final s in sessions.value ?? <CalendarSession>[]) {
      for (final t in [s.startsAt, s.endsAt]) {
        if (t.isAfter(clock) && t.isBefore(at)) {
          at = tz.TZDateTime.from(t, location);
        }
      }
    }
    _boundary = Timer(
      at.difference(clock) + const Duration(milliseconds: 20),
      () {
        if (isClosed) return;
        now(tz.TZDateTime.now(location));
        unawaited(refresh());
        _schedule();
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
