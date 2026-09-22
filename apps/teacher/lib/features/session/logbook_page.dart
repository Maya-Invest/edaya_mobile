import 'dart:async';

import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';
import 'attendance_page.dart';
import 'live_session_controller.dart';
import 'session_logbook_logic.dart';

class LogbookPage extends StatelessWidget {
  const LogbookPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveLogbookPage(sessionId: sessionId);
    }
    return _MockLogbookPage(sessionId: sessionId);
  }
}

class _MockLogbookPage extends LScopedView<StoreBoundController> {
  const _MockLogbookPage({required this.sessionId});

  final String sessionId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final session = store.sessionById(sessionId);
    if (session == null) {
      return const PrototypeDetailScaffold(
        title: 'Cahier de texte',
        body: EmptyState(title: 'Séance introuvable'),
      );
    }

    final existing = store.getLogbook(sessionId);
    return LogbookForm(
      sessionId: sessionId,
      classLabel: session.classLabel,
      initialContent: existing?.content ?? '',
      initialObjectives: existing?.objectives ?? '',
      initialHomework: existing?.homework ?? '',
      initialFamilySummary: '',
      initialProgress: existing?.progressPercent ?? 50,
      minProgress: 0,
      onSave: (content, objectives, homework, familySummary, progress) async {
        store.saveLogbook(
          sessionId: sessionId,
          content: content,
          objectives: objectives,
          homework: homework,
          progressPercent: progress,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cahier enregistré')));
      },
    );
  }
}

class _LiveLogbookPage extends LScopedView<LiveSessionController> {
  const _LiveLogbookPage({required this.sessionId});

  final String sessionId;

  @override
  LiveSessionController onConfigScope(LevitScope scope) {
    return putLiveSessionController(scope, sessionId);
  }

  @override
  Widget buildView(BuildContext context, LiveSessionController controller) {
    return LWatch(() {
      final session = controller.session.value;
      controller.content.value;
      controller.objectives.value;
      controller.homework.value;
      controller.familySummary.value;
      controller.progressPercent.value;
      controller.subjectMatters.value;
      if (session == null) {
        return const PrototypeDetailScaffold(
          title: 'Cahier de texte',
          body: EmptyState(title: 'Séance introuvable'),
        );
      }
      if (!controller.supportsLogbook) {
        return PrototypeDetailScaffold(
          title: 'Cahier · ${session.classLabel}',
          fallbackRoute: '/session/$sessionId',
          body: const EmptyState(
            title: 'Cahier de texte',
            message: 'Le cahier est réservé aux séances de cours.',
          ),
        );
      }
      return LogbookForm(
        key: ValueKey(
          '${session.id}-${controller.content.value}-${controller.familySummary.value}',
        ),
        sessionId: sessionId,
        classLabel: session.classLabel,
        initialContent: controller.content.value,
        initialObjectives: controller.objectives.value,
        initialHomework: controller.homework.value,
        initialFamilySummary: controller.familySummary.value,
        initialProgress: controller.progressPercent.value,
        minProgress: controller.minProgress,
        chapters: controller.subjectMatters.value,
        selectedChapterId: controller.selectedMatterId.value,
        onChapterSelected: controller.selectMatter,
        onChanged: (content, objectives, homework, familySummary, progress) {
          unawaited(
            controller.persistDraft(
              contentText: content,
              objectivesText: objectives,
              homeworkText: homework,
              familySummaryText: familySummary,
              progress: progress,
            ),
          );
        },
        onSave: (content, objectives, homework, familySummary, progress) async {
          final saved = await controller.saveLogbook(
            contentText: content,
            objectivesText: objectives,
            homeworkText: homework,
            familySummaryText: familySummary,
            progress: progress,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                saved
                    ? (controller.saveMessage.value.isEmpty
                          ? 'Cahier enregistré'
                          : controller.saveMessage.value)
                    : (controller.saveMessage.value.isEmpty
                          ? 'Cahier non enregistré'
                          : controller.saveMessage.value),
              ),
            ),
          );
        },
      );
    });
  }
}

class LogbookForm extends StatefulWidget {
  const LogbookForm({
    super.key,
    required this.sessionId,
    required this.classLabel,
    required this.initialContent,
    required this.initialObjectives,
    required this.initialHomework,
    required this.initialFamilySummary,
    required this.initialProgress,
    required this.minProgress,
    required this.onSave,
    this.onChanged,
    this.chapters = const [],
    this.selectedChapterId,
    this.onChapterSelected,
  });

  final String sessionId;
  final String classLabel;
  final String initialContent;
  final String initialObjectives;
  final String initialHomework;
  final String initialFamilySummary;
  final int initialProgress;
  final int minProgress;
  final List<SessionSubjectMatterOption> chapters;
  final String? selectedChapterId;
  final ValueChanged<String>? onChapterSelected;
  final Future<void> Function(String, String, String, String, int) onSave;
  final void Function(String, String, String, String, int)? onChanged;

  @override
  State<LogbookForm> createState() => _LogbookFormState();
}

class _LogbookFormState extends State<LogbookForm> {
  late final TextEditingController _content;
  late final TextEditingController _objectives;
  late final TextEditingController _homework;
  late final TextEditingController _familySummary;
  late double _progress;
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: widget.initialContent);
    _objectives = TextEditingController(text: widget.initialObjectives);
    _homework = TextEditingController(text: widget.initialHomework);
    _familySummary = TextEditingController(text: widget.initialFamilySummary);
    _progress = widget.initialProgress
        .clamp(widget.minProgress, 100)
        .toDouble();
    for (final controller in [
      _content,
      _objectives,
      _homework,
      _familySummary,
    ]) {
      controller.addListener(_scheduleDraft);
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _content.dispose();
    _objectives.dispose();
    _homework.dispose();
    _familySummary.dispose();
    super.dispose();
  }

  void _scheduleDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _emitDraft);
  }

  void _emitDraft() {
    widget.onChanged?.call(
      _content.text,
      _objectives.text,
      _homework.text,
      _familySummary.text,
      _progress.round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final min = widget.minProgress.toDouble().clamp(0, 100).toDouble();
    return PrototypeDetailScaffold(
      title: 'Cahier · ${widget.classLabel}',
      fallbackRoute: '/session/${widget.sessionId}',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          if (widget.chapters.length > 1)
            DropdownButtonFormField<String>(
              initialValue: widget.selectedChapterId ?? widget.chapters.first.id,
              decoration: const InputDecoration(labelText: 'Chapitre'),
              items: [
                for (final chapter in widget.chapters)
                  DropdownMenuItem(value: chapter.id, child: Text(chapter.name)),
              ],
              onChanged: (value) {
                if (value != null) {
                  widget.onChapterSelected?.call(value);
                }
              },
            ),
          if (widget.chapters.length > 1)
            const SizedBox(height: PrototypeSpacing.md),
          TextField(
            controller: _content,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Contenu abordé',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          TextField(
            controller: _objectives,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Objectifs',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          TextField(
            controller: _homework,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Devoirs',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          TextField(
            controller: _familySummary,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Synthèse familles',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          Text('Progression programme · ${_progress.round()} %'),
          Slider(
            value: _progress.clamp(min, 100).toDouble(),
            min: min,
            max: 100,
            divisions: ((100 - min) / 5).round().clamp(1, 20),
            onChanged: (v) {
              setState(() => _progress = v);
              _scheduleDraft();
            },
          ),
          const SizedBox(height: PrototypeSpacing.md),
          FilledButton(
            onPressed: () => widget.onSave(
              _content.text,
              _objectives.text,
              _homework.text,
              _familySummary.text,
              _progress.round(),
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
