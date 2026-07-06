import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../calendar/models/teacher_session.dart';
import 'models/session_detail_models.dart';
import 'session_detail_controller.dart';
import 'session_route_args.dart';
import 'widgets/attendance_row_tile.dart';

class SessionDetailsSheet extends LScopedView<SessionDetailController> {
  const SessionDetailsSheet({super.key, required this.session});

  final TeacherSession session;

  @override
  SessionDetailController onConfigScope(LevitScope scope) {
    return scope.put(
      () => SessionDetailController(
        session: session,
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, SessionDetailController controller) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: LWatch(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${session.classLabel} · ${session.subjectLabel}',
                          ),
                          Text(
                            context.tr.sessionDateTime(
                              context.formatLongDate(session.startsAt),
                              context.tr.timeRange(
                                context.formatTimeOfDay(session.startsAt),
                                context.formatTimeOfDay(session.endsAt),
                              ),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            context.tr.attendanceProgress(
                              controller.recordedAttendanceCount,
                              controller.students.value.length,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (controller.supportsLogbook)
                  SegmentedButton<SessionDetailSegment>(
                    segments: [
                      ButtonSegment(
                        value: SessionDetailSegment.attendance,
                        label: Text(context.tr.attendance),
                        icon: const Icon(Icons.fact_check_outlined),
                      ),
                      ButtonSegment(
                        value: SessionDetailSegment.logbook,
                        label: Text(context.tr.logbook),
                        icon: const Icon(Icons.menu_book_outlined),
                      ),
                    ],
                    selected: {controller.segment.value},
                    onSelectionChanged: (selection) {
                      controller.segment(selection.first);
                    },
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.tr.attendance,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                if (controller.errorMessage.value.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    controller.errorMessage.value,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (controller.saveMessage.value.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(controller.saveMessage.value),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: _SegmentBody(
                    controller: controller,
                    session: session,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentBody extends StatelessWidget {
  const _SegmentBody({
    required this.controller,
    required this.session,
  });

  final SessionDetailController controller;
  final TeacherSession session;

  @override
  Widget build(BuildContext context) {
    if (controller.isBusy.value && controller.students.value.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (controller.segment.value) {
      case SessionDetailSegment.attendance:
        if (!controller.supportsAttendanceRecording) {
          return Center(
            child: Text(context.tr.attendanceRecordingLessonOnly),
          );
        }
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => context.push(
                  '/calendar/attendance-flow',
                  extra: AttendanceFlowArgs(
                    session: session,
                    controller: controller,
                  ),
                ),
                icon: const Icon(Icons.swipe),
                label: Text(context.tr.takeAttendance),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: controller.students.value.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final row = controller.students.value[index];
                  return AttendanceRowTile(
                    row: row,
                    onStatusTap: () =>
                        _showAttendanceDialog(context, controller, row),
                  );
                },
              ),
            ),
          ],
        );
      case SessionDetailSegment.logbook:
        return _LogbookForm(controller: controller);
    }
  }

  Future<void> _showAttendanceDialog(
    BuildContext context,
    SessionDetailController controller,
    SessionStudentRow row,
  ) async {
    final status = await showDialog<SessionAttendanceStatus>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(row.studentName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in SessionAttendanceStatus.values)
              ListTile(
                title: Text(option.label(context.tr)),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (status != null && context.mounted) {
      await controller.recordAttendance(row, status);
    }
  }
}

class _LogbookForm extends StatefulWidget {
  const _LogbookForm({required this.controller});

  final SessionDetailController controller;

  @override
  State<_LogbookForm> createState() => _LogbookFormState();
}

class _LogbookFormState extends State<_LogbookForm> {
  late final TextEditingController _contentController;
  late final TextEditingController _objectivesController;
  late final TextEditingController _homeworkController;
  late final TextEditingController _progressController;
  String? _selectedMatterId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final logbook = widget.controller.logbook.value;
    _contentController = TextEditingController(text: logbook?.content ?? '');
    _objectivesController = TextEditingController(
      text: logbook?.objectives.join('\n') ?? '',
    );
    _homeworkController = TextEditingController(text: logbook?.homework ?? '');
    _progressController = TextEditingController(
      text: '${logbook?.progress ?? 0}',
    );
    final matters = widget.controller.subjectMatters.value;
    _selectedMatterId = matters.isNotEmpty ? matters.first.id : null;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _objectivesController.dispose();
    _homeworkController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matters = widget.controller.subjectMatters.value;
    if (widget.controller.session.classSubjectId == null) {
      return Center(
        child: Text(context.tr.logbookNotAvailableForSession),
      );
    }
    if (matters.isEmpty) {
      return Center(
        child: Text(context.tr.noCurriculumChaptersLinked),
      );
    }

    return ListView(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedMatterId,
          decoration: InputDecoration(
            labelText: context.tr.chapterLabel,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final matter in matters)
              DropdownMenuItem(
                value: matter.id,
                child: Text(matter.name),
              ),
          ],
          onChanged: (value) => setState(() => _selectedMatterId = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _contentController,
          decoration: InputDecoration(
            labelText: context.tr.contentLabel,
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _objectivesController,
          decoration: InputDecoration(
            labelText: context.tr.objectivesLabel,
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _homeworkController,
          decoration: InputDecoration(
            labelText: context.tr.homeworkLabel,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _progressController,
          decoration: InputDecoration(
            labelText: context.tr.progressPercentLabel,
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr.saveLogbook),
        ),
      ],
    );
  }

  TeacherSession get session => widget.controller.session;

  Future<void> _save() async {
    final matterId = _selectedMatterId;
    if (matterId == null) {
      return;
    }
    final matter = widget.controller.subjectMatters.value.firstWhere(
      (entry) => entry.id == matterId,
    );
    setState(() => _saving = true);
    final ok = await widget.controller.saveLogbook(
      classSubjectMatterId: matterId,
      chapter: matter.name,
      content: _contentController.text.trim(),
      objectives: _objectivesController.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(),
      homework: _homeworkController.text.trim(),
      progress: int.tryParse(_progressController.text.trim()) ?? 0,
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr.logbookSaved)),
        );
      }
    }
  }
}
