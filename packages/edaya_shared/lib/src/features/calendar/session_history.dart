import 'dart:async';
import 'package:intl/intl.dart';
import '../../app/edaya_tokens.g.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../access/school_client.dart';
import '../../demo/school_clock.dart';
import '../../l10n/l10n_extension.dart';

// Calendar arithmetic must not cross device daylight-saving offsets.
DateTime _calendarDate(Object? value) =>
    DateTime.parse('${value.toString().substring(0, 10)}T00:00:00Z');

class SessionHistoryController extends LevitController {
  SessionHistoryController({required this.read, required this.year});
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) read;
  final Map<String, dynamic> year;
  final entries = LxVar<List<Map<String, dynamic>>>(const []);
  final busy = LxVar(false);
  final error = LxVar(false);
  final hasMore = LxVar(true);
  final timeZone = LxVar('UTC');
  DateTime? _nextEnd;
  int _generation = 0;

  @override
  void onInit() {
    super.onInit();
    autoDispose(entries);
    autoDispose(busy);
    autoDispose(error);
    autoDispose(hasMore);
    autoDispose(timeZone);
    unawaited(load());
  }

  @override
  void onClose() {
    _generation++;
    super.onClose();
  }

  Future<void> refresh() async {
    _generation++;
    _nextEnd = null;
    busy(false);
    hasMore(true);
    await load(reset: true);
  }

  Future<void> load({bool reset = false}) async {
    if (busy.value || !hasMore.value) return;
    final generation = ++_generation;
    busy(true);
    error(false);
    try {
      final first = _calendarDate(year['startDate'] ?? year['startsAt']);
      final last = _calendarDate(year['endDate'] ?? year['endsAt']);
      final today = SchoolClock.now().toUtc().add(const Duration(days: 1));
      final end =
          _nextEnd ??
          (last.isBefore(today)
              ? last
              : DateTime.utc(today.year, today.month, today.day));
      if (end.isBefore(first)) {
        if (reset) entries(const []);
        hasMore(false);
        return;
      }
      final candidate = end.subtract(const Duration(days: 30));
      final start = candidate.isBefore(first) ? first : candidate;
      final result = await read({
        'academicYearId': year['id'],
        'startDate': start.toIso8601String().substring(0, 10),
        'endDate': end.toIso8601String().substring(0, 10),
      });
      if (isClosed || generation != _generation) return;
      final next = (result['entries'] as List).map(
        (r) => Map<String, dynamic>.from(r as Map),
      );
      final merged =
          <String, Map<String, dynamic>>{
              if (!reset)
                for (final row in entries.value)
                  '${row['kind']}/${row['id']}': row,
              for (final row in next) '${row['kind']}/${row['id']}': row,
            }.values.toList()
            ..sort((a, b) => '${b['startsAt']}'.compareTo('${a['startsAt']}'));
      entries(merged);
      timeZone(result['timeZone'] as String? ?? 'UTC');
      hasMore(result['hasMore'] == true);
      _nextEnd = _calendarDate(
        result['startDate'],
      ).subtract(const Duration(days: 1));
    } catch (_) {
      if (!isClosed && generation == _generation) error(true);
    } finally {
      if (!isClosed && generation == _generation) busy(false);
    }
  }
}

class SessionHistoryPanel extends LScopedView<SessionHistoryController> {
  const SessionHistoryPanel({
    super.key,
    required this.client,
    required this.query,
    required this.selection,
    required this.year,
    required this.onOpen,
  });
  final SchoolClientFactory client;
  final String query;
  final Map<String, dynamic> selection, year;
  final void Function(String) onOpen;
  @override
  SessionHistoryController onConfigScope(LevitScope scope) => scope.put(
    () => SessionHistoryController(
      year: year,
      read: (range) => client().runQuery(query, {...range, ...selection}),
    ),
  );
  @override
  Widget buildView(BuildContext context, SessionHistoryController controller) {
    final c = controller;
    final teacher = query == 'get-teacher-session-history';
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        key: PageStorageKey((
          'session-history',
          query,
          selection.toString(),
          year['id'],
        )),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (c.busy.value) const LinearProgressIndicator(),
          if (c.error.value)
            TextButton(onPressed: c.load, child: Text(context.tr.retry)),
          if (!c.busy.value && !c.error.value && c.entries.value.isEmpty)
            Text(context.tr.workspaceNoHistory),
          for (final row in c.entries.value)
            Builder(
              builder: (context) {
                final daily = row['kind'] == 'daily';
                final rawStart = DateTime.parse(row['startsAt'] as String);
                DateTime local(DateTime at) {
                  try {
                    return tz.TZDateTime.from(
                      at,
                      tz.getLocation(c.timeZone.value),
                    );
                  } catch (_) {
                    return at.toUtc();
                  }
                }

                final start = daily ? rawStart : local(rawStart);
                final attendance = row['attendance'] as Map?;
                final status = switch (attendance?['status']) {
                  'present' => context.tr.attendancePresent,
                  'absent' => context.tr.attendanceAbsent,
                  'late' => context.tr.attendanceLate,
                  _ => context.tr.workspaceNotRecorded,
                };
                final justification =
                    switch (attendance?['justificationStatus']) {
                      'excused' => context.tr.rollExcused,
                      'pending' => context.tr.workspaceJustificationPending,
                      'rejected' => context.tr.workspaceJustificationRejected,
                      _ => '',
                    };
                final details = [
                  DateFormat.yMMMd(context.localeTag).format(start),
                  if (!daily)
                    '${DateFormat.jm(context.localeTag).format(start)} – ${DateFormat.jm(context.localeTag).format(local(DateTime.parse(row['endsAt'] as String)))}',
                  if (!teacher) status,
                  if (!teacher && justification.isNotEmpty) justification,
                  if (teacher && row['attendanceComplete'] != null)
                    row['attendanceComplete'] == true
                        ? context.tr.workspaceAttendanceComplete
                        : context.tr.workspaceAttendanceIncomplete,
                  if (teacher && row['logbookComplete'] != null)
                    row['logbookComplete'] == true
                        ? context.tr.workspaceLogbookComplete
                        : context.tr.workspaceLogbookIncomplete,
                  if (attendance?['reason'] case final String reason) reason,
                ];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      EdayaTokens.radiusSurface,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      daily
                          ? context.tr.dailyAttendance
                          : '${row['subjectLabel'] ?? row['title']}',
                    ),
                    subtitle: Text(details.join(' · ')),
                    leading: Icon(
                      daily
                          ? Icons.fact_check_outlined
                          : Icons.event_note_outlined,
                    ),
                    trailing: daily ? null : const Icon(Icons.chevron_right),
                    onTap: daily ? null : () => onOpen(row['id'] as String),
                  ),
                );
              },
            ),
          if (c.hasMore.value)
            TextButton(
              onPressed: c.busy.value ? null : c.load,
              child: Text(context.tr.workspaceLoadOlder),
            ),
        ],
      ),
    );
  }
}
