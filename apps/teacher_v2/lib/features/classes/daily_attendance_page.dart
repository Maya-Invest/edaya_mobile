import '../../design/workspace_layout.dart';
import '../../app/workspace_navigation.dart';
import 'dart:async';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../session/attendance_page.dart';
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
  final message = LxVar('');
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
    for (final variable in [date, rows, submitted, busy, message]) {
      autoDispose(variable);
    }
    unawaited(load());
  }

  Future<void> load() async {
    busy(true);
    try {
      final call = await client().runQuery('get-teacher-attendance-call', {
        'anchor': anchor,
      });
      version = (call['version'] as num).toInt();
      submitted(call['submitted'] as bool);
      final entries = (call['entries'] as List).cast<Map>();
      final records = (call['records'] as List).cast<Map>();
      rows([
        for (final student in (call['students'] as List).cast<Map>())
          {
            ...Map<String, dynamic>.from(student),
            ...Map<String, dynamic>.from(
              entries
                      .where((row) => row['studentId'] == student['id'])
                      .firstOrNull ??
                  {},
            ),
            'record': records
                .where((row) => row['studentId'] == student['id'])
                .firstOrNull,
          },
      ]);
    } on Object catch (error) {
      message('$error');
    } finally {
      busy(false);
    }
  }

  Future<void> setStatus(
    String studentId,
    String status, {
    String? reason,
    String? notes,
    String? teacherExplanation,
  }) async {
    if (busy.value) return;
    final row = rows.value.where((s) => s['id'] == studentId).firstOrNull;
    if (row == null) return;
    if (submitted.value) {
      if (reason?.trim().isEmpty ?? true) return;
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
      return;
    }
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
    if (result != null) version = (result['version'] as num).toInt();
  }

  Future<Map<String, dynamic>?> send(
    String command,
    Map<String, dynamic> body,
    String id,
    TeacherOutboxKind kind,
  ) async {
    busy(true);
    try {
      final result = await client().runCommand(command, body);
      await outbox.remove(id);
      message(
        kind == TeacherOutboxKind.correction
            ? systemL10n().workflowCorrectionPending
            : systemL10n().workflowSynced,
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
      busy(false);
    }
  }

  bool get arrivalWindowActive {
    final now = DateTime.now().toUtc();
    final start = DateTime.parse(anchor['date'] as String);
    return !now.isBefore(start) &&
        now.isBefore(start.add(const Duration(days: 1)));
  }

  Future<void> recordArrival(Map<String, dynamic> row) async {
    final record = row['record'] as Map;
    final result = await send(
      'record-teacher-attendance-arrival',
      {
        'requestId': newSchoolRequestId(),
        'recordId': record['id'],
        'expectedVersion': record['workflowVersion'] ?? 0,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
      },
      'arrival-${record['id']}',
      TeacherOutboxKind.attendance,
    );
    if (result != null) await load();
  }

  Future<void> markRemainingPresent() async {
    for (final row in rows.value.where((s) => s['status'] == null).toList()) {
      await setStatus(row['id'] as String, 'present');
    }
  }

  Future<void> finish() async {
    if (rows.value.isEmpty || rows.value.any((s) => s['status'] == null)) {
      message(systemL10n().attendanceIncomplete);
      return;
    }
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
      await client().runCommand('submit-teacher-attendance', {
        'requestId': newSchoolRequestId(),
        'expectedVersion': call['version'],
        'anchor': anchor,
        'entries': [],
      });
      await load();
    } on Object catch (error) {
      message('$error');
    }
  }
}

class DailyAttendancePage extends LScopedView<DailyAttendanceController> {
  const DailyAttendancePage({super.key, required this.classId});
  final String classId;
  @override
  DailyAttendanceController onConfigScope(LevitScope scope) => scope.put(
    () => DailyAttendanceController(
      classId: classId,
      client: scope.find<SchoolClientFactory>(),
      outbox: scope.find<TeacherOutboxStore>(),
      schoolDay: scope.find<TeacherContextController>().schoolTime(
        DateTime.now(),
      ),
    ),
  );
  @override
  Widget buildView(
    BuildContext context,
    DailyAttendanceController controller,
  ) => PrototypeDetailScaffold(
    title: context.tr.dailyAttendance,
    fallbackRoute: '/classes/$classId',
    body: AttendanceLayout(
      controls: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${controller.rows.value.where((r) => r['status'] != null).length}/${controller.rows.value.length} renseignés',
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: controller.busy.value
                      ? null
                      : () async {
                          final date = await showWorkspaceDatePicker(
                            context: context,
                            initialDate: controller.date.value,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            controller.date(date);
                            await controller.load();
                          }
                        },
                  child: Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(controller.date.value),
                  ),
                ),
              ),
              if (!controller.submitted.value)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: controller.busy.value
                            ? null
                            : controller.markRemainingPresent,
                        child: Text(context.tr.attendanceMarkRemaining),
                      ),
                    ),
                    const SizedBox(width: PrototypeSpacing.sm),
                    FilledButton(
                      onPressed: controller.busy.value
                          ? null
                          : controller.finish,
                      child: Text(context.tr.attendanceFinish),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (controller.message.value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(PrototypeSpacing.sm),
            child: Text(controller.message.value),
          ),
      ],
      roster: ListView(
        children: [
          for (final row in controller.rows.value)
            ListTile(
              title: Text('${row['firstName']} ${row['lastName']}'),
              subtitle:
                  controller.submitted.value &&
                      controller.arrivalWindowActive &&
                      row['status'] == 'absent'
                  ? TextButton(
                      onPressed: controller.busy.value
                          ? null
                          : () => controller.recordArrival(row),
                      child: Text(context.tr.attendanceArrival),
                    )
                  : null,
              trailing: Text(switch (row['status']) {
                'present' => 'Présent',
                'absent' => 'Absent',
                'late' => 'Retard',
                _ => 'À saisir',
              }),
              onTap: controller.busy.value
                  ? null
                  : () async {
                      final entry = await showAttendanceExceptionSheet(
                        context: context,
                        studentName: '${row['firstName']} ${row['lastName']}',
                        initialStatus:
                            AttendanceStatus.values
                                .where((s) => s.name == row['status'])
                                .firstOrNull ??
                            AttendanceStatus.present,
                        initialReason: row['teacherExplanation'] as String?,
                        initialNotes: row['notes'] as String?,
                        correction: controller.submitted.value,
                      );
                      if (entry != null) {
                        await controller.setStatus(
                          row['id'] as String,
                          entry.status.name,
                          reason: entry.correctionReason,
                          notes: entry.notes,
                          teacherExplanation: entry.reason,
                        );
                      }
                    },
            ),
        ],
      ),
    ),
  );
}
