import 'package:edaya_api_client/edaya_api_client.dart';
import '../session/roll_call.dart';
import '../session/attendance_draft_queue.dart';
import '../session/live_session_controller.dart';
import '../../live/runtime.dart';
import '../../app/workspace_navigation.dart';
import 'dart:async';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../design/components/components.dart';
import '../context/teacher_context_controller.dart';
import '../../mock/mock_store.dart';

class DailyAttendanceController extends LevitController {
  DailyAttendanceController({
    required this.classId,
    required this.client,
    required this.outbox,
    DateTime? schoolDay,
  }) : date = LxVar(schoolDay ?? DateTime.now());
  final String classId;
  final SchoolClientFactory client;
  final TeacherOutboxStore outbox;
  final LxVar<DateTime> date;
  final rows = LxVar<List<Map<String, dynamic>>>([]);
  final submitted = LxVar(false);
  final busy = LxVar(false);
  final draftWrites = AttendanceDraftQueue();
  final message = LxVar('');
  final draftPending = LxVar(false);
  final draftConflict = LxVar(false);
  int version = 0;
  Map<String, dynamic> get anchor => {
    'kind': 'daily',
    'classGroupId': classId,
    'date': DateTime.utc(
      date.value.year,
      date.value.month,
      date.value.day,
    ).toIso8601String(),
  };
  String get draftId => 'daily-$classId-${anchor['date']}';
  @override
  void onInit() {
    super.onInit();
    for (final variable in [
      date,
      rows,
      submitted,
      busy,
      draftWrites.writing,
      message,
      draftPending,
      draftConflict,
    ]) {
      autoDispose(variable);
    }
    unawaited(load());
  }

  Future<void> load() async {
    message('');
    busy(true);
    try {
      final call = await client().runQuery('get-teacher-attendance-call', {
        'anchor': anchor,
      });
      version = (call['version'] as num).toInt();
      submitted(call['submitted'] as bool);
      final queued = (await outbox.listPending())
          .where((entry) => entry.id == draftId)
          .firstOrNull;
      draftPending(queued != null && !submitted.value);
      draftConflict(queued != null && !teacherOutboxEntryIsReplayable(queued));
      final entries =
          (submitted.value
                  ? call['records'] as List
                  : queued != null && teacherOutboxEntryIsReplayable(queued)
                  ? (queued.payload['body'] as Map)['entries'] as List
                  : call['entries'] as List)
              .cast<Map>();
      final students = (call['students'] as List).cast<Map>();
      final photos = <String, String?>{};
      if (students.isNotEmpty) {
        try {
          for (final student in await client().students.listAll(
            entitiesByIds(students.map((s) => s['id'] as String).toList()),
          )) {
            photos[student['id'] as String] = student['photoUrl'] as String?;
          }
        } on Object {
          /* Portraits are optional on historical rosters. */
        }
      }
      final records = (call['records'] as List).cast<Map>();
      rows([
        for (final student in students)
          {
            ...Map<String, dynamic>.from(student),
            ...Map<String, dynamic>.from(
              entries
                      .where((row) => row['studentId'] == student['id'])
                      .firstOrNull ??
                  {},
            ),
            'id': student['id'],
            'photoUrl': photos[student['id']],
            'record': records
                .where((row) => row['studentId'] == student['id'])
                .firstOrNull,
          },
      ]);
    } on Object catch (error) {
      rows([]);
      message('$error');
    } finally {
      busy(false);
    }
  }

  Future<bool> setStatus(
    String studentId,
    String status, {
    String? reason,
    String? notes,
    String? teacherExplanation,
  }) async {
    if (busy.value) return false;
    final row = rows.value.where((s) => s['id'] == studentId).firstOrNull;
    if (row == null) return false;
    if (submitted.value) {
      if (reason?.trim().isEmpty ?? true) return false;
      final record = row['record'] as Map;
      final proposal = {
        'workflow': 'attendance',
        'targetId': record['id'],
        'status': status,
        'notes': notes ?? record['notes'],
        'teacherExplanation':
            teacherExplanation ?? record['teacherExplanation'],
      };
      final pending = record['pendingCorrection'] as Map?;
      final result = await send(
        pending == null
            ? 'request-teacher-correction'
            : 'revise-teacher-correction',
        {
          'requestId': newSchoolRequestId(),
          'expectedVersion':
              pending?['version'] ?? record['workflowVersion'] ?? 0,
          if (pending != null) 'correctionId': pending['id'],
          'proposal': proposal,
          'reason': reason,
        },
        'correction-${record['id']}',
        TeacherOutboxKind.correction,
      );
      if (result != null) await load();
      return result != null ||
          message.value == systemL10n().attendanceSavedLocally;
    }
    return draftWrites.add(
      () => _setDraftStatus(studentId, status, notes, teacherExplanation),
      active: () => !isClosed,
    );
  }

  Future<bool> _setDraftStatus(
    String studentId,
    String status,
    String? notes,
    String? teacherExplanation,
  ) async {
    final previous = rows.value;
    rows([
      for (final current in rows.value)
        current['id'] == studentId
            ? {
                ...current,
                'status': status,
                'notes': notes ?? current['notes'],
                'teacherExplanation':
                    teacherExplanation ?? current['teacherExplanation'],
              }
            : current,
    ]);
    return _saveDraft(previous);
  }

  Future<bool> _saveDraft(List<Map<String, dynamic>> previous) async {
    final result = await send(
      'save-teacher-attendance-draft',
      {
        'requestId': newSchoolRequestId(),
        'expectedVersion': version,
        'anchor': anchor,
        'entries': [
          for (final current in rows.value)
            if (current['status'] != null)
              {
                'studentId': current['id'],
                'status': current['status'],
                'notes': current['notes'],
                'teacherExplanation': current['teacherExplanation'],
              },
        ],
      },
      draftId,
      TeacherOutboxKind.attendance,
    );
    draftPending(result == null);
    draftConflict(false);
    if (result != null) {
      version = (result['version'] as num).toInt();
      return true;
    }
    if (message.value == systemL10n().attendanceSavedLocally) return true;
    rows(previous);
    draftConflict(true);
    return false;
  }

  Future<Map<String, dynamic>?> send(
    String command,
    Map<String, dynamic> body,
    String id,
    TeacherOutboxKind kind,
  ) async {
    final exclusive = command != 'save-teacher-attendance-draft';
    if (exclusive) busy(true);
    try {
      final result = await client().runCommand(command, body);
      await outbox.remove(id);
      message(
        kind == TeacherOutboxKind.correction
            ? systemL10n().workflowCorrectionPending
            : '',
      );
      return result;
    } on Object catch (error) {
      final retryable = isRetryableTeacherWriteFailure(error);
      await outbox.enqueue(
        buildTeacherOutboxEntry(
          id: id,
          kind: kind,
          idempotencyKey: id,
          payload: {'command': command, 'body': body},
          lastError: '$error',
          state: retryable
              ? TeacherOutboxState.pending
              : TeacherOutboxState.conflict,
        ),
      );
      message(retryable ? systemL10n().attendanceSavedLocally : '$error');
      return null;
    } finally {
      if (exclusive) busy(false);
    }
  }

  bool get arrivalWindowActive {
    final now = DateTime.now().toUtc();
    final start = DateTime.parse(anchor['date'] as String);
    return !now.isBefore(start) &&
        now.isBefore(start.add(const Duration(days: 1)));
  }

  Future<bool> recordArrival(
    Map<String, dynamic> row, {
    bool departure = false,
  }) async {
    final record = row['record'] as Map;
    final id = '${departure ? 'departure' : 'arrival'}-${record['id']}';
    final queued = (await outbox.listPending())
        .where(
          (entry) => entry.id == id && teacherOutboxEntryIsReplayable(entry),
        )
        .firstOrNull;
    final result = await send(
      departure
          ? 'record-teacher-attendance-departure'
          : 'record-teacher-attendance-arrival',
      (queued?.payload['body'] as Map?)?.cast<String, dynamic>() ??
          {
            'requestId': newSchoolRequestId(),
            'recordId': record['id'],
            'expectedVersion': record['workflowVersion'] ?? 0,
            'occurredAt': DateTime.now().toUtc().toIso8601String(),
          },
      id,
      TeacherOutboxKind.attendance,
    );
    if (result != null) await load();
    return result != null ||
        message.value == systemL10n().attendanceSavedLocally;
  }

  Future<void> markRemainingPresent() async {
    if (busy.value ||
        submitted.value ||
        !rows.value.any((s) => s['status'] == null))
      return;
    final previous = rows.value;
    rows([
      for (final row in previous)
        if (row['status'] == null) {...row, 'status': 'present'} else row,
    ]);
    await draftWrites.add(() => _saveDraft(previous), active: () => !isClosed);
  }

  Future<void> syncDraft() async {
    if (busy.value) return;
    busy(true);
    try {
      for (final entry in await outbox.listPending()) {
        if (entry.id != draftId) continue;
        if (!teacherOutboxEntryIsReplayable(entry)) {
          message(entry.lastError ?? systemL10n().attendanceSubmitNeedsSync);
          return;
        }
        await syncTeacherOutboxEntry(client(), entry);
        await outbox.remove(entry.id);
      }
      await load();
    } on Object catch (error) {
      message('$error');
    } finally {
      busy(false);
    }
  }

  Future<void> finish() async {
    await draftWrites.settled;
    if (submitted.value || busy.value || isClosed) return;
    if (rows.value.isEmpty || rows.value.any((s) => s['status'] == null)) {
      message(systemL10n().attendanceIncomplete);
      return;
    }
    busy(true);
    try {
      for (final entry in await outbox.listPending()) {
        if (entry.id == draftId) {
          if (!teacherOutboxEntryIsReplayable(entry)) {
            throw StateError(systemL10n().attendanceSubmitNeedsSync);
          }
          await syncTeacherOutboxEntry(client(), entry);
          await outbox.remove(entry.id);
        }
      }
      final call = await client().runQuery('get-teacher-attendance-call', {
        'anchor': anchor,
      });
      if (call['submitted'] == true || call['version'] != version) {
        await load();
        if (!submitted.value) message(systemL10n().rollRegisterChanged);
        return;
      }
      await client().runCommand('submit-teacher-attendance', {
        'requestId': newSchoolRequestId(),
        'expectedVersion': call['version'],
        'anchor': anchor,
        'entries': [],
      });
      await load();
    } on Object catch (error) {
      message('$error');
    } finally {
      busy(false);
    }
  }
}

class DailyAttendancePage extends LScopedView<DailyAttendanceController> {
  const DailyAttendancePage({
    super.key,
    required this.classId,
    this.initialDate,
  });
  final String classId;
  final DateTime? initialDate;
  @override
  DailyAttendanceController onConfigScope(LevitScope scope) => scope.put(
    () => DailyAttendanceController(
      classId: classId,
      client: scope.find<SchoolClientFactory>(),
      outbox: scope.find<TeacherOutboxStore>(),
      schoolDay:
          initialDate ??
          scope.find<TeacherContextController>().schoolTime(DateTime.now()),
    ),
  );
  @override
  Widget buildView(
    BuildContext context,
    DailyAttendanceController controller,
  ) => PrototypeDetailScaffold(
    title: context.tr.dailyAttendance,
    fallbackRoute: '/classes/$classId',
    body: LWatch(
      () => RollCall(
        key: ValueKey(controller.draftId),
        dateControl: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _RegisterClassPicker(classId: classId, controller: controller),
            TextButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              onPressed: controller.busy.value
                  ? null
                  : () async {
                      final date = await showWorkspaceDatePicker(
                        context: context,
                        initialDate: controller.date.value,
                        firstDate: DateTime(2020),
                        lastDate: context.levit
                            .find<TeacherContextController>()
                            .schoolTime(DateTime.now()),
                      );
                      if (date != null) {
                        await controller.draftWrites.settled;
                        if (controller.isClosed) return;
                        controller.date(date);
                        controller.rows([]);
                        controller.message('');
                        await controller.load();
                      }
                    },
              label: Text(
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(controller.date.value),
              ),
            ),
          ],
        ),
        rows: [for (final r in controller.rows.value) _dailyPupil(r)],
        submitted: controller.submitted.value,
        busy: controller.busy.value,
        savingDraft: controller.draftWrites.writing.value,
        pending: controller.draftPending.value,
        conflict: controller.draftConflict.value,
        message: controller.message.value,
        windowOpen: controller.arrivalWindowActive,
        schoolTime: context.levit.find<TeacherContextController>().schoolTime,
        onFinish: controller.finish,
        onBulk: controller.markRemainingPresent,
        onSync: controller.draftConflict.value || controller.rows.value.isEmpty
            ? controller.load
            : controller.syncDraft,
        onSave: (row, status, comment, reason) => controller.setStatus(
          row.studentId,
          status.name,
          reason: reason,
          teacherExplanation: comment,
        ),
        onMove: (row, departure) => controller.recordArrival(
          controller.rows.value.firstWhere((r) => r['id'] == row.studentId),
          departure: departure,
        ),
      ),
    ),
  );
}

class _RegisterClassPicker extends StatelessWidget {
  const _RegisterClassPicker({required this.classId, required this.controller});
  final String classId;
  final DailyAttendanceController controller;

  @override
  Widget build(BuildContext context) {
    final teacher = context.levit.find<TeacherContextController>();
    return LWatch(() {
      final groups = teacher.assignedClasses.value;
      final current = groups.where((g) => g.id == classId).firstOrNull;
      final eligible = groups
          .where(
            (g) =>
                g.dailyAttendance &&
                teacher.assignments.value.any(
                  (a) => a.classGroupId == g.id && a.isHomeroom,
                ),
          )
          .toList();
      if (current == null) return const SizedBox.shrink();
      if (eligible.length <= 1)
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(current.label),
        );
      return TextButton.icon(
        icon: const Icon(Icons.school_outlined),
        label: Text(current.label),
        onPressed: controller.busy.value
            ? null
            : () async {
                final selected = await showWorkspaceEditor<String>(
                  context: context,
                  title: context.tr.classLabel,
                  builder: (_, close) => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final group in eligible)
                        ListTile(
                          title: Text(group.label),
                          selected: group.id == classId,
                          onTap: () => close(group.id),
                        ),
                    ],
                  ),
                );
                if (!context.mounted || selected == null || selected == classId)
                  return;
                await controller.draftWrites.settled;
                if (!context.mounted) return;
                await teacher.selectClass(selected);
                if (!context.mounted) return;
                context.replace(
                  Uri(
                    pathSegments: ['', 'classes', selected, 'attendance'],
                    queryParameters: {
                      'date': controller.date.value.toIso8601String().substring(
                        0,
                        10,
                      ),
                    },
                  ).toString(),
                );
              },
      );
    });
  }
}

LiveSessionStudent _dailyPupil(Map<String, dynamic> row) {
  final name = "${row['firstName']} ${row['lastName']}".trim();
  final record = row['record'] as Map?;
  return LiveSessionStudent(
    studentId: row['id'] as String,
    fullName: name,
    initials: personInitials(name),
    status: AttendanceStatus.values
        .where((s) => s.name == row['status'])
        .firstOrNull,
    photoUrl: row['photoUrl'] as String?,
    reason: row['teacherExplanation'] as String?,
    notes: row['notes'] as String?,
    pendingCorrection: (record?['pendingCorrection'] as Map?)
        ?.cast<String, dynamic>(),
    justification: record?['justificationStatus'] as String?,
    departedAt: DateTime.tryParse(record?['departedAt']?.toString() ?? ''),
  );
}
