import '../../design/workspace_layout.dart';
import '../../app/workspace_navigation.dart';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../live/entity_queries.dart';
import '../context/academic_year_controller.dart';
import '../context/teacher_context_controller.dart';
import '../inbox/live_inbox_controller.dart';

class NewRecordForm extends StatefulWidget {
  const NewRecordForm({super.key, required this.message});
  final bool message;
  @override
  State<NewRecordForm> createState() => _NewRecordFormState();
}

class _NewRecordFormState extends State<NewRecordForm> {
  final title = TextEditingController(), body = TextEditingController();
  final requestId = newSchoolRequestId();
  String? classId, studentId, guardianId;
  List<Map<String, dynamic>> pupils = [], guardians = [];
  Set<String> participants = {}, savedParticipants = {};
  DateTime date = SchoolClock.now();
  String kind = 'minor_infraction', error = '';
  bool busy = false, dirty = false, confirming = false, recorded = false;
  String pupilSearch = '';
  bool committed = false;
  int lookup = 0;
  int classPickerRevision = 0;
  SchoolClient get client => context.levit.find<SchoolClientFactory>()();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final active = context.levit
          .find<TeacherContextController>()
          .activeAssignment;
      if (active != null) loadClass(active.classGroupId);
    });
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> loadClass(String id) async {
    final seq = ++lookup;
    setState(() {
      classId = id;
      studentId = guardianId = null;
      pupilSearch = '';
      pupils = [];
      guardians = [];
      participants = {};
      error = '';
    });
    try {
      final year = context.levit
          .find<AcademicYearController>()
          .selectedYearId
          .value;
      final rows = await client.enrollments.listAll(
        activeEnrollmentsForClass(id, academicYearId: year),
      );
      final ids = rows.map((r) => r['studentId'] as String).toSet().toList();
      final students = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : await client.students.listAll(entitiesByIds(ids));
      if (mounted && seq == lookup) setState(() => pupils = students);
    } catch (e) {
      if (mounted && seq == lookup) {
        setState(() => error = context.tr.couldNotLoadStudents(e));
      }
    }
  }

  Future<void> loadGuardians(String id) async {
    final seq = ++lookup;
    setState(() {
      studentId = id;
      guardianId = null;
      guardians = [];
      error = '';
    });
    try {
      final response = await client.runQuery(
        'list-teacher-guardian-recipients',
        {'classGroupId': classId, 'studentId': id},
      );
      if (mounted && seq == lookup) {
        setState(
          () => guardians = (response['guardians'] as List)
              .cast<Map<String, dynamic>>(),
        );
      }
    } catch (e) {
      if (mounted && seq == lookup) {
        setState(() => error = context.tr.guardiansUnavailable(e));
      }
    }
  }

  Future<void> submit() async {
    if (busy ||
        committed ||
        classId == null ||
        title.text.trim().isEmpty ||
        body.text.trim().isEmpty ||
        (widget.message && guardianId == null)) {
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      if (widget.message) {
        final thread = await client.runCommand('start-teacher-conversation', {
          'classGroupId': classId,
          'studentId': studentId,
          'guardianId': guardianId,
          'subject': title.text.trim(),
          'body': body.text.trim(),
          'requestId': requestId,
        });
        if (!mounted) return;
        await context.levit.find<LiveInboxController>().loadInbox();
        if (mounted) await openSaved('/inbox/conversation/${thread['id']}');
      } else {
        if (!recorded) {
          try {
            await client.runCommand('record-incident', {
              'id': requestId,
              'schoolId': context.levit
                  .find<AppSessionController>()
                  .grants
                  .value!
                  .schoolId,
              'classGroupId': classId,
              'date': date.toUtc().toIso8601String(),
              'kind': kind,
              'title': title.text.trim(),
              'description': body.text.trim(),
            });
          } on Object {
            final existing = await client.incidents.get(requestId);
            if (existing['classGroupId'] != classId ||
                existing['title'] != title.text.trim()) {
              rethrow;
            }
          }
          recorded = true;
        }
        for (final pupil in participants.difference(savedParticipants)) {
          final linkId = '$requestId-$pupil';
          try {
            await client.runCommand('add-student-involvement', {
              'id': linkId,
              'incidentId': requestId,
              'studentId': pupil,
              'role': 'subject',
            });
          } on Object {
            // A lost response can leave a committed association on the server.
            final saved = await client.studentIncidentInvolvements.list({
              'incidentId': requestId,
            });
            if (!saved.any(
              (row) => row['id'] == linkId && row['studentId'] == pupil,
            )) {
              rethrow;
            }
          }
          savedParticipants.add(pupil);
        }
        if (mounted) await openSaved('/incidents/$classId/$requestId');
      }
    } catch (e) {
      if (!mounted) return;
      if (widget.message &&
          e is ApiError &&
          [403, 404].contains(e.status) &&
          studentId != null) {
        await loadGuardians(studentId!);
      }
      if (mounted) {
        setState(
          () => error = recorded
              ? context.tr.incidentSavedStillToLink(
                  participants
                      .difference(savedParticipants)
                      .map(
                        (id) => label(pupils.firstWhere((p) => p["id"] == id)),
                      )
                      .join(", "),
                  e,
                )
              : context.tr.couldNotSaveChangesLabel(e),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openSaved(String path) async {
    // Publish the successful write to the sheet's exit guard before routing.
    setState(() {
      committed = true;
      dirty = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) context.go(path);
  }

  String label(Map row) => '${row['firstName']} ${row['lastName']}';
  @override
  Widget build(BuildContext context) => LWatch(() => _buildForm(context));

  Widget _buildForm(BuildContext context) {
    final tc = context.levit.find<TeacherContextController>();
    final visiblePupils = pupils.where(
      (p) =>
          p['id'] == studentId ||
          participants.contains(p['id']) ||
          _searchName(label(p)).contains(pupilSearch),
    );
    return PopScope(
      canPop: committed || (!dirty && !busy),
      onPopInvokedWithResult: (popped, _) async {
        if (popped || busy || confirming) return;
        confirming = true;
        final discard = await confirmWorkspaceDiscard(context);
        if (!mounted) return;
        confirming = false;
        if (!discard) return;
        setState(() => dirty = false);
        await WidgetsBinding.instance.endOfFrame;
        if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
          closeWorkspaceSheet(context);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WorkspaceColumns(
            sectionSpacing: 12,
            first: [
              DropdownButtonFormField<String>(
                key: ValueKey((classId, classPickerRevision)),
                isExpanded: true,
                initialValue: classId,
                decoration: InputDecoration(
                  labelText: context.tr.teachingSelectClass,
                ),
                items: [
                  for (final c in tc.assignedClasses.value.where(
                    (c) => tc.visibleClassGroupIds.contains(c.id),
                  ))
                    DropdownMenuItem(value: c.id, child: Text(c.label)),
                ],
                onChanged: busy || recorded
                    ? null
                    : (id) async {
                        if (id == null || id == classId) return;
                        if (dirty && !await confirmWorkspaceDiscard(context)) {
                          if (mounted) setState(() => classPickerRevision++);
                          return;
                        }
                        if (!mounted) return;
                        title.clear();
                        body.clear();
                        setState(() => dirty = false);
                        await loadClass(id);
                      },
              ),
              if (pupils.isNotEmpty)
                TextField(
                  key: ValueKey(('search', classId)),
                  decoration: InputDecoration(
                    labelText: context.tr.searchForAStudent,
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (text) =>
                      setState(() => pupilSearch = _searchName(text.trim())),
                ),
              if (pupilSearch.isNotEmpty && visiblePupils.isEmpty)
                Text(context.tr.noStudentsFound),
              if (widget.message) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey(classId),
                  initialValue: studentId,
                  decoration: InputDecoration(labelText: context.tr.student),
                  items: [
                    for (final p in visiblePupils)
                      DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text(label(p)),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (id) {
                          if (id != null) {
                            dirty = true;
                            loadGuardians(id);
                          }
                        },
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey((studentId, guardianId)),
                  initialValue: guardianId,
                  decoration: InputDecoration(
                    labelText: context.tr.guardianRecipient,
                  ),
                  items: [
                    for (final g in guardians)
                      DropdownMenuItem(
                        value: g['id'] as String,
                        child: Text(g['name'] as String),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (id) => setState(() => guardianId = id),
                ),
              ] else ...[
                ListTile(
                  title: Text(
                    'Date · ${MaterialLocalizations.of(context).formatMediumDate(date)}',
                  ),
                  onTap: busy || recorded
                      ? null
                      : () async {
                          final selected = await showWorkspaceDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: SchoolClock.now(),
                          );
                          if (selected != null && mounted) {
                            setState(() {
                              dirty = true;
                              date = selected;
                            });
                          }
                        },
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: kind,
                  decoration: InputDecoration(
                    labelText: context.tr.incidentType,
                  ),
                  items: [
                    for (final e in {
                      'minor_infraction': context.tr.workflowIncidentMinor,
                      'major_infraction': context.tr.workflowIncidentMajor,
                      'positive': context.tr.positiveIncident,
                      'emergency': context.tr.workflowIncidentEmergency,
                    }.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: busy || recorded
                      ? null
                      : (v) => setState(() {
                          dirty = true;
                          kind = v!;
                        }),
                ),
                for (final p in visiblePupils)
                  CheckboxListTile(
                    title: Text(label(p)),
                    value: participants.contains(p['id']),
                    onChanged: busy || recorded
                        ? null
                        : (v) => setState(() {
                            dirty = true;
                            if (v == true) {
                              participants.add(p['id'] as String);
                            } else {
                              participants.remove(p['id']);
                            }
                          }),
                  ),
              ],
              if (recorded && error.isNotEmpty) Text(error),
            ],
            second: [
              TextField(
                controller: title,
                enabled: !busy && !recorded,
                decoration: InputDecoration(
                  labelText: widget.message
                      ? context.tr.messagingSubject
                      : context.tr.titleLabel,
                ),
                onChanged: (_) => setState(() => dirty = true),
              ),
              TextField(
                controller: body,
                enabled: !busy && !recorded,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: widget.message
                      ? context.tr.firstMessage
                      : context.tr.whatHappened,
                ),
                onChanged: (_) => setState(() => dirty = true),
              ),
              if (!recorded && error.isNotEmpty) Text(error),
              FilledButton(
                onPressed:
                    busy ||
                        committed ||
                        classId == null ||
                        title.text.trim().isEmpty ||
                        body.text.trim().isEmpty ||
                        (widget.message && guardianId == null)
                    ? null
                    : submit,
                child: Text(
                  widget.message
                      ? context.tr.messagingSend
                      : recorded
                      ? context.tr.retryLinkingStudents
                      : context.tr.saveIncident,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _searchName(String name) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'ï': 'i',
    'î': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'œ': 'oe',
  };
  return name.toLowerCase().replaceAllMapped(
    RegExp('[àâäéèêëïîôöùûüçœ]'),
    (match) => accents[match[0]]!,
  );
}
