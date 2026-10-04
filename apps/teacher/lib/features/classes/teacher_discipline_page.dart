import 'dart:async';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/entity_queries.dart';
import '../context/teacher_context_controller.dart';

class TeacherDisciplineController extends LevitController {
  TeacherDisciplineController({
    required this.classId,
    required this.client,
    required this.teacherId,
    required this.outbox,
  });
  final String classId;
  final SchoolClientFactory client;
  final String? teacherId;
  final TeacherOutboxStore outbox;
  final incidents = LxVar<List<Map<String, dynamic>>>([]);
  final students = LxVar<List<Map<String, dynamic>>>([]);
  final message = LxVar('');
  final busy = LxVar(false);
  @override
  void onInit() {
    super.onInit();
    autoDispose(incidents);
    autoDispose(students);
    autoDispose(message);
    autoDispose(busy);
    unawaited(load());
  }

  Future<void> load() async {
    busy(true);
    try {
      final api = client();
      final enrollments = await api.enrollments.list(
        activeEnrollmentsForClass(classId),
      );
      final ids = enrollments.map((e) => e['studentId'] as String).toList();
      students(ids.isEmpty ? [] : await api.students.list(entitiesByIds(ids)));
      final result = <Map<String, dynamic>>[];
      final namedStudents = {
        for (final student in students.value) student['id'] as String: student,
      };
      final authored = (await api.incidents.listAll({
        'classGroupId': classId,
      })).where((incident) => incident['reporterId'] == teacherId).toList();
      final states = await Future.wait(
        authored.map(
          (incident) => api.runQuery('get-teacher-workflow-state', {
            'proposal': {
              'workflow': 'discipline',
              'targetId': incident['id'],
              'title': incident['title'],
              'description': incident['description'],
              'kind': incident['kind'],
              // The state query returns the canonical, including historical, participants.
              'studentIds': <String>[],
            },
          }),
        ),
      );
      for (var index = 0; index < authored.length; index++) {
        final incident = authored[index];
        final eligibility = states[index];
        for (final student
            in ((eligibility['context'] as Map)['students'] as List)
                .cast<Map>()) {
          namedStudents.putIfAbsent(
            student['id'] as String,
            () => {
              'id': student['id'],
              'firstName': student['name'],
              'lastName': '',
            },
          );
        }
        result.add({
          ...incident,
          'proposal': eligibility['official'],
          'eligibility': eligibility,
        });
      }
      students(namedStudents.values.toList());
      incidents(result);
    } on Object catch (error) {
      message('$error');
    } finally {
      busy(false);
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
      message(
        correction
            ? systemL10n().workflowCorrectionPending
            : systemL10n().workflowSynced,
      );
    } on Object catch (error) {
      if (!isRetryableTeacherWriteFailure(error)) {
        message('$error');
        busy(false);
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
      message(systemL10n().attendanceSavedLocally);
    } finally {
      busy(false);
    }
    await load();
    return true;
  }
}

class TeacherDisciplinePage extends LScopedView<TeacherDisciplineController> {
  const TeacherDisciplinePage({super.key, required this.classId});
  final String classId;
  @override
  TeacherDisciplineController onConfigScope(LevitScope scope) => scope.put(
    () => TeacherDisciplineController(
      classId: classId,
      client: scope.find<SchoolClientFactory>(),
      teacherId: scope.find<TeacherContextController>().teacherId.value,
      outbox: scope.find<TeacherOutboxStore>(),
    ),
  );
  @override
  Widget buildView(
    BuildContext context,
    TeacherDisciplineController controller,
  ) => PrototypeDetailScaffold(
    title: context.tr.workflowDiscipline,
    fallbackRoute: '/classes/$classId',
    body: ListView(
      padding: const EdgeInsets.all(PrototypeSpacing.md),
      children: [
        if (controller.busy.value) const LinearProgressIndicator(),
        if (controller.message.value.isNotEmpty) Text(controller.message.value),
        for (final incident in controller.incidents.value)
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                Wrap(
                  spacing: PrototypeSpacing.sm,
                  children: [
                    TextButton(
                      onPressed: controller.busy.value
                          ? null
                          : () => showLevitDialog<void>(
                              context: context,
                              builder: (_) => _IncidentFactsForm(
                                controller: controller,
                                incident: incident,
                              ),
                            ),
                      child: Text(
                        (incident['eligibility'] as Map)['locked'] == true
                            ? context.tr.workflowRequestCorrection
                            : context.tr.edit,
                      ),
                    ),
                    TextButton(
                      onPressed: controller.busy.value
                          ? null
                          : () => showLevitDialog<void>(
                              context: context,
                              builder: (_) => _FollowUpForm(
                                controller: controller,
                                incidentId: incident['id'] as String,
                              ),
                            ),
                      child: Text(context.tr.workflowFollowUp),
                    ),
                  ],
                ),
                for (final event
                    in ((incident['eligibility'] as Map)['history'] as List)
                        .cast<Map>()
                        .where((e) => e['action'] == 'follow_up'))
                  Text((event['payload'] as Map)['text'] as String),
              ],
            ),
          ),
      ],
    ),
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
