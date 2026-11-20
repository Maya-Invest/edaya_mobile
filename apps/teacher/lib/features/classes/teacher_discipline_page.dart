import '../../design/workspace_layout.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../app/formatters.dart';
import '../../live/entity_queries.dart';

class TeacherDisciplineController extends LevitController {
  TeacherDisciplineController({
    required this.classId,
    required this.client,
    this.incidentId,
    this.editFacts = false,
    required this.outbox,
  });
  final String classId;
  final SchoolClientFactory client;
  final String? incidentId;
  final bool editFacts;
  final nextCursor = LxVar<String?>(null);
  final readFailed = LxVar(false);
  bool failedContinuation = false;
  Completer<void>? _abort;
  final TeacherOutboxStore outbox;
  final incidents = LxVar<List<Map<String, dynamic>>>([]);
  final students = LxVar<List<Map<String, dynamic>>>([]);
  final message = LxVar('');
  final busy = LxVar(false);
  @override
  void onInit() {
    super.onInit();
    autoDispose(nextCursor);
    autoDispose(readFailed);
    autoDispose(incidents);
    autoDispose(students);
    autoDispose(message);
    autoDispose(busy);
    unawaited(load());
  }

  @override
  void onClose() {
    _abort?.complete();
    _abort = null;
    super.onClose();
  }

  Future<void> load({bool more = false}) async {
    if (isClosed || (more && (busy.value || nextCursor.value == null))) return;
    _abort?.complete();
    final abort = _abort = Completer<void>();
    bool current() => identical(_abort, abort) && !isClosed;
    busy(true);
    if (readFailed.value) message('');
    readFailed(false);
    try {
      final api = client();
      final id = incidentId;
      if (id != null) {
        final data = await api.getTeacherIncidentDetail({
          'classGroupId': classId,
          'incidentId': id,
        }, abortTrigger: abort.future);
        if (!current()) return;
        final incident = data['incident'] as Map<String, dynamic>;
        if (incident['id'] != id)
          throw const FormatException('Unexpected incident');
        final eligibility = data['eligibility'] as Map<String, dynamic>;
        final historical = ((eligibility['context'] as Map)['students'] as List)
            .cast<Map>();
        final names = <String, Map<String, dynamic>>{
          for (final student in historical)
            student['id'] as String: {
              'id': student['id'],
              'firstName': student['name'],
              'lastName': '',
            },
        };
        if (editFacts) {
          final placements = await api.enrollments.listAll(
            activeEnrollmentsForClass(classId),
          );
          if (!current()) return;
          final ids = placements
              .map((row) => row['studentId'] as String)
              .toSet()
              .toList();
          for (var start = 0; start < ids.length; start += 100) {
            final rows = await api.students.list({
              ...entitiesByIds(ids.skip(start).take(100).toList()),
              r'$limit': 100,
            });
            if (!current()) return;
            for (final row in rows) {
              names[row['id'] as String] = row;
            }
          }
        }
        students(names.values.toList());
        incidents([
          {
            ...incident,
            'proposal': eligibility['official'],
            'eligibility': eligibility,
          },
        ]);
      } else {
        final previousCount = incidents.value.length;
        final rows = more ? [...incidents.value] : <Map<String, dynamic>>[];
        var cursor = more ? nextCursor.value : null;
        do {
          final data = await api.getTeacherIncidents({
            'classGroupId': classId,
            'cursor': ?cursor,
          }, abortTrigger: abort.future);
          if (!current()) return;
          rows.addAll((data['items'] as List).cast<Map<String, dynamic>>());
          cursor = data['nextCursor'] as String?;
        } while (!more && cursor != null && rows.length < previousCount);
        incidents({for (final row in rows) row['id']: row}.values.toList());
        nextCursor(cursor);
      }
    } on Object catch (error) {
      if (!current()) return;
      if (error is ApiError && [401, 403, 404].contains(error.status)) {
        incidents([]);
        students([]);
        nextCursor(null);
      }
      if (more && error is ApiError && error.status == 400) {
        incidents([]);
        nextCursor(null);
      }
      failedContinuation = more;
      readFailed(true);
      message('$error');
    } finally {
      if (current()) {
        _abort = null;
        busy(false);
      }
    }
  }

  Future<bool> save(
    Map<String, dynamic> incident,
    Map<String, dynamic> proposal, {
    String? reason,
  }) async {
    final eligibility = incident['eligibility'] as Map;
    final locked = eligibility['locked'] == true;
    if (locked && (reason?.trim().isEmpty ?? true)) return false;
    final pending = (eligibility['corrections'] as List)
        .cast<Map>()
        .where((r) => r['status'] == 'pending')
        .firstOrNull;
    final command = locked
        ? (pending == null
              ? 'request-teacher-correction'
              : 'revise-teacher-correction')
        : 'edit-teacher-incident';
    final body = <String, dynamic>{
      'requestId': newSchoolRequestId(),
      'expectedVersion': pending?['version'] ?? eligibility['version'],
      'proposal': proposal,
      if (locked) 'reason': reason,
      if (pending != null) 'correctionId': pending['id'],
    };
    return send(command, body, correction: locked);
  }

  Future<bool> followUp(String incidentId, String text) => send(
    'append-incident-follow-up',
    {'requestId': newSchoolRequestId(), 'incidentId': incidentId, 'text': text},
    correction: false,
  );
  Future<bool> send(
    String command,
    Map<String, dynamic> body, {
    required bool correction,
  }) async {
    if (busy.value) return false;
    busy(true);
    try {
      await client().runCommand(command, body);
      if (isClosed) return true;
      message(
        correction
            ? systemL10n().workflowCorrectionPending
            : systemL10n().workflowSynced,
      );
    } on Object catch (error) {
      if (!isRetryableTeacherWriteFailure(error)) {
        if (!isClosed) message('$error');
        return false;
      }
      await outbox.enqueue(
        buildTeacherOutboxEntry(
          id: body['requestId'] as String,
          kind: TeacherOutboxKind.correction,
          idempotencyKey: body['requestId'] as String,
          payload: {'command': command, 'body': body},
          lastError: '$error',
        ),
      );
      if (!isClosed) message(systemL10n().attendanceSavedLocally);
    } finally {
      if (!isClosed) busy(false);
    }
    await load();
    return true;
  }
}

class TeacherDisciplinePage extends LScopedView<TeacherDisciplineController> {
  const TeacherDisciplinePage({
    super.key,
    required this.classId,
    this.incidentId,
    this.mode,
  });
  final String? incidentId, mode;
  final String classId;
  @override
  TeacherDisciplineController onConfigScope(LevitScope scope) => scope.put(
    () => TeacherDisciplineController(
      classId: classId,
      client: scope.find<SchoolClientFactory>(),
      incidentId: incidentId,
      editFacts: mode == 'facts',
      outbox: scope.find<TeacherOutboxStore>(),
    ),
  );
  @override
  Widget buildView(
    BuildContext context,
    TeacherDisciplineController controller,
  ) {
    if (incidentId == null) {
      return PrototypeDetailScaffold(
        title: context.tr.workflowDiscipline,
        fallbackRoute: '/classes/$classId',
        body: ListView(children: [teacherIncidentRows(context, controller)]),
      );
    }
    final rows = controller.incidents.value.where(
      (r) => incidentId == null || r['id'] == incidentId,
    );
    final incident = rows.firstOrNull;
    if (incident != null && mode == 'facts') {
      return _IncidentFactsForm(controller: controller, incident: incident);
    }
    if (incident != null && mode == 'follow') {
      return _FollowUpForm(
        controller: controller,
        incidentId: incident['id'] as String,
      );
    }
    return PrototypeDetailScaffold(
      title: context.tr.workflowDiscipline,
      fallbackRoute: '/classes/$classId',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          if (controller.busy.value) const LinearProgressIndicator(),
          if (controller.message.value.isNotEmpty)
            Text(controller.message.value),
          if (controller.readFailed.value && !controller.busy.value)
            TextButton(
              onPressed: controller.load,
              child: Text(context.tr.retry),
            ),
          for (final incident in rows) ...[
            SurfaceCard(
              child: WorkspaceColumns(
                first: [
                  Text(
                    incident['title'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(incident['description'] as String? ?? ''),
                  if ((incident['eligibility'] as Map)['locked'] == true)
                    Text(context.tr.workflowIncidentTakenOver),
                  for (final id
                      in ((incident['proposal'] as Map)['studentIds'] as List))
                    Text(
                      controller.students.value
                              .where((s) => s['id'] == id)
                              .map((s) => '${s['firstName']} ${s['lastName']}')
                              .firstOrNull ??
                          '',
                    ),
                  PopupMenuButton<String>(
                    tooltip: context.tr.workspaceActions,
                    enabled: !controller.busy.value,
                    onSelected: (step) =>
                        openEditor(context, incident['id'] as String, step),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'facts',
                        child: Text(
                          (incident['eligibility'] as Map)['locked'] == true
                              ? context.tr.workflowRequestCorrection
                              : context.tr.featureEditFacts,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'follow',
                        child: Text(context.tr.workflowFollowUp),
                      ),
                    ],
                  ),
                ],
                second: [
                  Text(
                    context.tr.followUp,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final event
                      in ((incident['eligibility'] as Map)['history'] as List)
                          .cast<Map>()
                          .where((e) => e['action'] == 'follow_up'))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text((event['payload'] as Map)['text'] as String),
                      subtitle: _eventDate(context, event),
                    ),
                ],
              ),
            ),
            const SizedBox(height: PrototypeSpacing.listGap),
          ],
        ],
      ),
    );
  }

  void openEditor(BuildContext context, String id, String step) {
    final path = '/incidents/$classId/$id?mode=$step';
    if (incidentId == null) {
      context.push(path);
    } else {
      context.replace(path);
    }
  }
}

Widget teacherIncidentRows(
  BuildContext context,
  TeacherDisciplineController controller,
) {
  return Column(
    children: [
      if (controller.busy.value) const LinearProgressIndicator(),
      if (controller.message.value.isNotEmpty) Text(controller.message.value),
      if (controller.incidents.value.isEmpty &&
          !controller.busy.value &&
          !controller.readFailed.value)
        ListTile(title: Text(context.tr.noIncidents)),
      if (controller.incidents.value.isNotEmpty)
        ComparisonHeading([context.tr.incident, 'Date', context.tr.status]),
      for (final row in controller.incidents.value)
        LayoutBuilder(
          builder: (context, box) {
            Future<void> open() async {
              await context.push(
                '/incidents/${Uri.encodeComponent(controller.classId)}/${Uri.encodeComponent(row['id'] as String)}',
              );
              if (context.mounted) await controller.load();
            }

            final date = DateTime.tryParse('${row['date']}');
            final status = switch (row['status']) {
              'resolved' => context.tr.messagingResolved,
              'cancelled' => context.tr.feeStatusCancelled,
              'open' when row['locked'] == true =>
                context.tr.workflowIncidentTakenOver,
              'open' => context.tr.familyFeedbackSlotOpen,
              _ => '—',
            };
            return useComparisonRows(context, box.maxWidth)
                ? ComparisonRow(
                    cells: [
                      row['title'] as String,
                      date == null ? '—' : formatDate(date),
                      status,
                    ],
                    onTap: open,
                  )
                : ListTile(
                    title: Text(row['title'] as String),
                    subtitle: Text(row['description'] as String? ?? ''),
                    onTap: open,
                  );
          },
        ),
      if (!controller.busy.value &&
          (controller.readFailed.value || controller.nextCursor.value != null))
        TextButton(
          onPressed: () => controller.load(
            more:
                controller.nextCursor.value != null &&
                (!controller.readFailed.value || controller.failedContinuation),
          ),
          child: Text(
            controller.readFailed.value
                ? context.tr.retry
                : context.tr.showMore,
          ),
        ),
    ],
  );
}

class _IncidentFactsForm extends StatefulWidget {
  const _IncidentFactsForm({required this.controller, required this.incident});
  final TeacherDisciplineController controller;
  final Map<String, dynamic> incident;
  @override
  State<_IncidentFactsForm> createState() => _IncidentFactsFormState();
}

class _IncidentFactsFormState extends State<_IncidentFactsForm> {
  final reason = TextEditingController();
  bool get locked => (widget.incident['eligibility'] as Map)['locked'] == true;
  late final title = TextEditingController(
    text: widget.incident['title'] as String,
  );
  late final description = TextEditingController(
    text: widget.incident['description'] as String? ?? '',
  );
  late String kind = widget.incident['kind'] as String;
  late final selected = Set<String>.from(
    (widget.incident['proposal'] as Map)['studentIds'] as List,
  );
  @override
  void dispose() {
    reason.dispose();
    title.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(context.tr.workflowDiscipline),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: PrototypeSpacing.sm,
      children: [
        TextField(
          controller: title,
          decoration: InputDecoration(
            labelText: context.tr.workflowIncidentTitle,
          ),
        ),
        TextField(
          controller: description,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: context.tr.workflowIncidentFacts,
          ),
        ),
        DropdownButton<String>(
          value: kind,
          isExpanded: true,
          items: [
            for (final value in [
              'positive',
              'minor_infraction',
              'major_infraction',
              'emergency',
            ])
              DropdownMenuItem(
                value: value,
                child: Text(switch (value) {
                  'positive' => context.tr.workflowIncidentPositive,
                  'minor_infraction' => context.tr.workflowIncidentMinor,
                  'major_infraction' => context.tr.workflowIncidentMajor,
                  _ => context.tr.workflowIncidentEmergency,
                }),
              ),
          ],
          onChanged: (value) => setState(() => kind = value!),
        ),
        if (locked)
          TextField(
            controller: reason,
            decoration: InputDecoration(
              labelText: context.tr.marksCorrectionReason,
            ),
            onChanged: (_) => setState(() {}),
          ),
        for (final student in widget.controller.students.value)
          CheckboxListTile(
            title: Text('${student['firstName']} ${student['lastName']}'),
            value: selected.contains(student['id']),
            onChanged: (value) => setState(() {
              if (value == true) {
                selected.add(student['id'] as String);
              } else {
                selected.remove(student['id']);
              }
            }),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        onPressed:
            title.text.trim().isEmpty || (locked && reason.text.trim().isEmpty)
            ? null
            : () async {
                final proposal = <String, dynamic>{
                  ...Map<String, dynamic>.from(
                    widget.incident['proposal'] as Map,
                  ),
                  'title': title.text,
                  'description': description.text.trim().isEmpty
                      ? null
                      : description.text,
                  'kind': kind,
                  'studentIds': selected.toList(),
                };
                final saved = await widget.controller.save(
                  widget.incident,
                  proposal,
                  reason: locked ? reason.text.trim() : null,
                );
                if (saved && context.mounted) Navigator.pop(context);
              },
        child: Text(
          (widget.incident['eligibility'] as Map)['locked'] == true
              ? context.tr.workflowRequestCorrection
              : context.tr.save,
        ),
      ),
    ],
  );
}

class _FollowUpForm extends StatefulWidget {
  const _FollowUpForm({required this.controller, required this.incidentId});
  final TeacherDisciplineController controller;
  final String incidentId;
  @override
  State<_FollowUpForm> createState() => _FollowUpFormState();
}

class _FollowUpFormState extends State<_FollowUpForm> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr.workflowFollowUp),
    content: TextField(
      controller: text,
      maxLines: 4,
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        onPressed: text.text.trim().isEmpty
            ? null
            : () async {
                final saved = await widget.controller.followUp(
                  widget.incidentId,
                  text.text,
                );
                if (saved && context.mounted) Navigator.pop(context);
              },
        child: Text(context.tr.save),
      ),
    ],
  );
}

Widget? _eventDate(BuildContext context, Map event) {
  final time = DateTime.tryParse(
    '${event['createdAt'] ?? event['occurredAt'] ?? event['at']}',
  );
  return time == null
      ? null
      : Text(
          MaterialLocalizations.of(context).formatMediumDate(time.toLocal()),
        );
}
