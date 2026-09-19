import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../calendar/models/teacher_session.dart';
import '../context/academic_year_controller.dart';
import 'attendance_exception_sheet.dart';
import 'models/session_detail_models.dart';
import 'session_detail_controller.dart';
import 'session_logbook_draft_storage.dart';
import 'session_logbook_logic.dart' as logbook;
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
        getAcademicYearId: () =>
            scope.find<AcademicYearController>().selectedYearId.value,
        schoolClient: scope.find<SchoolClientFactory>(),
        outboxStore: scope.find<TeacherOutboxStore>(),
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
                          if (controller.pendingOutboxCount.value > 0)
                            Text(
                              context.tr.attendanceSavedLocally,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.tertiary,
                                  ),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (controller.saveMessage.value.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(controller.saveMessage.value),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: _SegmentBody(controller: controller, session: session),
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
  const _SegmentBody({required this.controller, required this.session});

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
          return Center(child: Text(context.tr.attendanceRecordingLessonOnly));
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(
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
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: controller.isBusy.value
                      ? null
                      : () async {
                          await controller.markAllPresent();
                        },
                  child: Text(context.tr.markAllPresent),
                ),
              ],
            ),
            if (controller.pendingOutboxCount.value > 0) ...[
              const SizedBox(height: 8),
              StatusBadge(
                label: context.tr.attendanceSavedLocally,
                icon: Icons.schedule_outlined,
                tone: StatusBadgeTone.warning,
              ),
            ],
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
                        _showAttendanceException(context, controller, row),
                  );
                },
              ),
            ),
          ],
        );
      case SessionDetailSegment.logbook:
        return _LogbookPanel(controller: controller);
    }
  }

  Future<void> _showAttendanceException(
    BuildContext context,
    SessionDetailController controller,
    SessionStudentRow row,
  ) async {
    final result = await showAttendanceExceptionSheet(
      context: context,
      row: row,
      initialStatus: row.status,
    );
    if (result != null && context.mounted) {
      await controller.recordAttendance(
        row,
        result.status,
        reason: result.reason,
        notes: result.notes,
      );
    }
  }
}

class _LogbookPanel extends StatefulWidget {
  const _LogbookPanel({required this.controller});

  final SessionDetailController controller;

  @override
  State<_LogbookPanel> createState() => _LogbookPanelState();
}

class _LogbookPanelState extends State<_LogbookPanel> {
  late final TextEditingController _sessionNoteController;
  late final TextEditingController _objectivesController;
  late final TextEditingController _homeworkController;
  late final TextEditingController _familySummaryController;
  final List<_DraftEntryState> _draftEntries = [];
  bool _saving = false;
  bool _draftRestored = false;
  Timer? _autosaveTimer;

  @override
  void initState() {
    super.initState();
    final structured = logbook.decodeStructuredSessionNote(
      widget.controller.sessionNote.value,
    );
    _sessionNoteController = TextEditingController(text: structured.content);
    _objectivesController = TextEditingController(
      text: structured.objectives.join('\n'),
    );
    _homeworkController = TextEditingController(text: structured.homework ?? '');
    _familySummaryController = TextEditingController(
      text: structured.familySummary ?? '',
    );
    for (final controller in [
      _sessionNoteController,
      _objectivesController,
      _homeworkController,
      _familySummaryController,
    ]) {
      controller.addListener(_scheduleDraftSave);
    }
    unawaited(_restoreDraftIfPresent());
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    for (final controller in [
      _sessionNoteController,
      _objectivesController,
      _homeworkController,
      _familySummaryController,
    ]) {
      controller.removeListener(_scheduleDraftSave);
      controller.dispose();
    }
    for (final entry in _draftEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _scheduleDraftSave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_persistDraft());
    });
  }

  Future<void> _restoreDraftIfPresent() async {
    final draft = await SessionLogbookDraftStorage.load(
      widget.controller.session.id,
    );
    if (!mounted || draft == null) {
      return;
    }

    setState(() {
      _sessionNoteController.text = draft.sessionNote;
      _objectivesController.text = draft.objectives;
      _homeworkController.text = draft.homework;
      _familySummaryController.text = draft.familySummary;
      for (final entry in draft.progressEntries) {
        _draftEntries.add(
          _DraftEntryState(
            matterId: entry.matterId,
            completedPercentage: entry.completedPercentage,
            notes: entry.notes,
            isEditingExisting: entry.isEditingExisting,
          ),
        );
      }
      _draftRestored = true;
    });
  }

  Future<void> _persistDraft() async {
    await SessionLogbookDraftStorage.save(
      widget.controller.session.id,
      SessionLogbookDraft(
        sessionNote: _sessionNoteController.text,
        objectives: _objectivesController.text,
        homework: _homeworkController.text,
        familySummary: _familySummaryController.text,
        progressEntries: [
          for (final entry in _draftEntries)
            SessionLogbookDraftProgressEntry(
              matterId: entry.matterId ?? '',
              completedPercentage:
                  int.tryParse(entry.progressController.text.trim()) ?? 0,
              notes: entry.notesController.text,
              isEditingExisting: entry.isEditingExisting,
            ),
        ],
        updatedAt: DateTime.now(),
      ),
    );
  }

  Set<String> get _draftMatterIds =>
      _draftEntries.map((entry) => entry.matterId).whereType<String>().toSet();

  void _addDraftEntry({SessionSubjectMatterOption? matter}) {
    final usedIds = _draftMatterIds;
    final pickable = widget.controller.pickableMatters
        .where((entry) => !usedIds.contains(entry.id))
        .toList();
    final selected = matter ?? pickable.firstOrNull;
    if (selected == null && matter == null) {
      return;
    }

    setState(() {
      _draftEntries.add(
        _DraftEntryState(
          matterId: selected?.id ?? matter!.id,
          completedPercentage:
              matter?.sessionProgress?.completedPercentage ??
              selected?.cumulativePercentage ??
              matter?.cumulativePercentage ??
              0,
          notes: matter?.sessionProgress?.notes ?? '',
          isEditingExisting: matter?.hasSessionProgress ?? false,
          onChanged: _scheduleDraftSave,
        ),
      );
    });
    _scheduleDraftSave();
  }

  void _removeDraftEntry(_DraftEntryState entry) {
    setState(() {
      entry.dispose();
      _draftEntries.remove(entry);
    });
    _scheduleDraftSave();
  }

  List<SessionSubjectMatterOption> _matterChoicesForDraft(
    _DraftEntryState draft,
    List<SessionSubjectMatterOption> allMatters,
  ) {
    final usedByOthers = _draftEntries
        .where((entry) => !identical(entry, draft))
        .map((entry) => entry.matterId)
        .whereType<String>()
        .toSet();

    if (draft.isEditingExisting && draft.matterId != null) {
      return allMatters.where((matter) => matter.id == draft.matterId).toList();
    }

    return widget.controller.pickableMatters
        .where((matter) => !usedByOthers.contains(matter.id))
        .toList();
  }

  bool _canAddAnotherDraft(List<SessionSubjectMatterOption> allMatters) {
    final usedIds = _draftMatterIds;
    return widget.controller.pickableMatters.any(
      (matter) => !usedIds.contains(matter.id),
    );
  }

  SessionSubjectMatterOption? _matterById(
    List<SessionSubjectMatterOption> allMatters,
    String? matterId,
  ) {
    if (matterId == null) {
      return null;
    }
    for (final matter in allMatters) {
      if (matter.id == matterId) {
        return matter;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.supportsLogbook) {
      final notes = widget.controller.activityNotes.value;
      if (notes == null || notes.isEmpty) {
        return Center(child: Text(context.tr.noLogbookEntryForSession));
      }
      return ListView(
        children: [
          Text(
            context.tr.sessionNotesLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(notes),
        ],
      );
    }

    if (widget.controller.session.classSubjectId == null) {
      return Center(child: Text(context.tr.logbookNotAvailableForSession));
    }

    return LWatch(() {
      final allMatters = widget.controller.subjectMatters.value;
      final recordedMatters = widget.controller.recordedMatters
          .where((matter) => !_draftMatterIds.contains(matter.id))
          .toList();
      final canAddDraft = _canAddAnotherDraft(allMatters);
      final subjectProgress =
          widget.controller.classSubjectCompletedPercentage.value;
      final saveMessage = widget.controller.saveMessage.value;
      final isBusy = widget.controller.isBusy.value;

      if (isBusy && allMatters.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (allMatters.isEmpty) {
        return Center(child: Text(context.tr.noCurriculumChaptersLinked));
      }

      final encodedNote = widget.controller.sessionNote.value;
      final structured = logbook.decodeStructuredSessionNote(encodedNote);
      if (_sessionNoteController.text != structured.content) {
        _sessionNoteController.text = structured.content;
        _objectivesController.text = structured.objectives.join('\n');
        _homeworkController.text = structured.homework ?? '';
        _familySummaryController.text = structured.familySummary ?? '';
      }

      return ListView(
        children: [
          if (_draftRestored) ...[
            Text(
              context.tr.logbookDraftRestored,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (saveMessage.isNotEmpty) ...[
            Text(
              saveMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            context.tr.curriculumProgressTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            context.tr.curriculumProgressDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (subjectProgress != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: subjectProgress / 100,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr.subjectProgressSummary(subjectProgress),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          for (final entry in _draftEntries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProgressDraftCard(
                matterChoices: _matterChoicesForDraft(entry, allMatters),
                draft: entry,
                selectedMatter: _matterById(allMatters, entry.matterId),
                onMatterChanged: (value) {
                  setState(() {
                    entry.matterId = value;
                    final matter = _matterById(allMatters, value);
                    if (matter != null && !entry.isEditingExisting) {
                      entry.progressController.text =
                          '${matter.cumulativePercentage}';
                      entry.notesController.clear();
                    }
                  });
                },
                onRemove: () => _removeDraftEntry(entry),
              ),
            ),
          FilledButton.icon(
            onPressed: canAddDraft ? () => _addDraftEntry() : null,
            icon: const Icon(Icons.add),
            label: Text(
              _draftEntries.isEmpty
                  ? context.tr.addCurriculumProgress
                  : context.tr.addAnotherCurriculumProgress,
            ),
          ),
          if (!canAddDraft && recordedMatters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.tr.allMattersRecordedForSession,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
          if (recordedMatters.isEmpty && _draftEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                context.tr.noRecordedMatterProgress,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final matter in recordedMatters)
              _MatterProgressCard(
                matter: matter,
                onEdit: _draftMatterIds.contains(matter.id)
                    ? null
                    : () => _addDraftEntry(matter: matter),
              ),
          const SizedBox(height: 20),
          Text(
            context.tr.objectivesLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _objectivesController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: context.tr.objectivesLabel,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr.homeworkLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _homeworkController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: context.tr.homeworkLabel,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr.familyVisibleSummaryLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _familySummaryController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: context.tr.familyVisibleSummaryLabel,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text(context.tr.familyVisiblePreviewLabel),
              subtitle: Text(
                logbook.composeFamilyVisiblePreview(_structuredContent()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr.sessionNotesLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            context.tr.sessionNotesDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sessionNoteController,
            decoration: InputDecoration(
              hintText: context.tr.sessionNotesHint,
              border: const OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _saveLogbook,
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
    });
  }

  Future<void> _saveLogbook() async {
    final progressEntries = <LogbookProgressDraft>[];

    for (final draft in _draftEntries) {
      final matterId = draft.matterId;
      if (matterId == null) {
        widget.controller.saveMessage(context.tr.pickSubjectMatterTitle);
        return;
      }
      final completedPercentage = int.tryParse(
        draft.progressController.text.trim(),
      );
      if (completedPercentage == null) {
        widget.controller.saveMessage(context.tr.progressPercentLabel);
        return;
      }
      progressEntries.add(
        LogbookProgressDraft(
          matterId: matterId,
          completedPercentage: completedPercentage,
          notes: draft.notesController.text,
        ),
      );
    }

    setState(() => _saving = true);
    final savedMessage = context.tr.logbookSaved;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await widget.controller.saveLogbook(
      structuredContent: _structuredContent(),
      progressEntries: progressEntries,
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        await SessionLogbookDraftStorage.clear(widget.controller.session.id);
        for (final entry in List<_DraftEntryState>.from(_draftEntries)) {
          _removeDraftEntry(entry);
        }
        messenger.showSnackBar(SnackBar(content: Text(savedMessage)));
      }
    }
  }

  logbook.StructuredLogbookContent _structuredContent() {
    return logbook.StructuredLogbookContent(
      content: _sessionNoteController.text,
      objectives: _objectivesController.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(),
      homework: _homeworkController.text,
      familySummary: _familySummaryController.text,
    );
  }
}

class _DraftEntryState {
  _DraftEntryState({
    required this.matterId,
    required int completedPercentage,
    required String notes,
    required this.isEditingExisting,
    this.onChanged,
  }) : progressController = TextEditingController(text: '$completedPercentage'),
       notesController = TextEditingController(text: notes) {
    progressController.addListener(_notifyChanged);
    notesController.addListener(_notifyChanged);
  }

  String? matterId;
  final TextEditingController progressController;
  final TextEditingController notesController;
  final bool isEditingExisting;
  final VoidCallback? onChanged;

  void _notifyChanged() => onChanged?.call();

  void dispose() {
    progressController.removeListener(_notifyChanged);
    notesController.removeListener(_notifyChanged);
    progressController.dispose();
    notesController.dispose();
  }
}

class _ProgressDraftCard extends StatelessWidget {
  const _ProgressDraftCard({
    required this.matterChoices,
    required this.draft,
    required this.selectedMatter,
    required this.onMatterChanged,
    required this.onRemove,
  });

  final List<SessionSubjectMatterOption> matterChoices;
  final _DraftEntryState draft;
  final SessionSubjectMatterOption? selectedMatter;
  final ValueChanged<String?> onMatterChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final minimum = selectedMatter == null
        ? 0
        : (selectedMatter!.sessionProgress?.completedPercentage ??
              selectedMatter!.cumulativePercentage);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    draft.isEditingExisting
                        ? context.tr.editMatterProgress
                        : context.tr.addCurriculumProgress,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                  tooltip: context.tr.cancel,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (draft.isEditingExisting && selectedMatter != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(selectedMatter!.name),
                subtitle: Text(
                  context.tr.cumulativeProgressLabel(
                    selectedMatter!.cumulativePercentage,
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: draft.matterId,
                decoration: InputDecoration(
                  labelText: context.tr.pickSubjectMatterTitle,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final matter in matterChoices)
                    DropdownMenuItem(
                      value: matter.id,
                      child: Text(matter.name),
                    ),
                ],
                onChanged: onMatterChanged,
              ),
            if (selectedMatter != null) ...[
              const SizedBox(height: 8),
              Text(
                context.tr.matterProgressMinimum(minimum),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: draft.progressController,
                decoration: InputDecoration(
                  labelText: context.tr.lessonProgressPercentLabel,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: draft.notesController,
                decoration: InputDecoration(
                  labelText: context.tr.matterNotesLabel,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MatterProgressCard extends StatelessWidget {
  const _MatterProgressCard({required this.matter, required this.onEdit});

  final SessionSubjectMatterOption matter;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final sessionProgress = matter.sessionProgress!;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(matter.name, style: theme.textTheme.titleSmall),
                ),
                Chip(
                  label: Text(matter.status.label(context.tr)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr.cumulativeProgressLabel(
                          matter.cumulativePercentage,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: matter.cumulativePercentage / 100,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr.lessonProgressLabel(
                    sessionProgress.completedPercentage,
                  ),
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            if (sessionProgress.notes != null &&
                sessionProgress.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(sessionProgress.notes!, style: theme.textTheme.bodyMedium),
            ],
            if (onEdit != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: onEdit,
                  child: Text(context.tr.editMatterProgress),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
