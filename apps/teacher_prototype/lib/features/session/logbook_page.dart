import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../calendar/live_calendar_controller.dart';
import '../context/academic_year_controller.dart';
import '../context/store_bound_controller.dart';
import 'live_session_controller.dart';

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
      initialProgress: existing?.progressPercent ?? 50,
      onSave: (content, objectives, homework, progress) async {
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
    return scope.put(
      () => LiveSessionController(
        sessionId: sessionId,
        calendar: scope.find<LiveCalendarController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, LiveSessionController controller) {
    return LWatch(() {
      final session = controller.session.value;
      controller.content.value;
      controller.objectives.value;
      controller.homework.value;
      controller.progressPercent.value;
      if (session == null) {
        return const PrototypeDetailScaffold(
          title: 'Cahier de texte',
          body: EmptyState(title: 'Séance introuvable'),
        );
      }
      return LogbookForm(
        key: ValueKey(
          '${session.id}-${controller.content.value}-${controller.objectives.value}',
        ),
        sessionId: sessionId,
        classLabel: session.classLabel,
        initialContent: controller.content.value,
        initialObjectives: controller.objectives.value,
        initialHomework: controller.homework.value,
        initialProgress: controller.progressPercent.value,
        onSave: (content, objectives, homework, progress) async {
          final saved = await controller.saveLogbook(
            contentText: content,
            objectivesText: objectives,
            homeworkText: homework,
            progress: progress,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                saved
                    ? 'Cahier enregistré'
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
    required this.initialProgress,
    required this.onSave,
  });

  final String sessionId;
  final String classLabel;
  final String initialContent;
  final String initialObjectives;
  final String initialHomework;
  final int initialProgress;
  final Future<void> Function(String, String, String, int) onSave;

  @override
  State<LogbookForm> createState() => _LogbookFormState();
}

class _LogbookFormState extends State<LogbookForm> {
  late final TextEditingController _content;
  late final TextEditingController _objectives;
  late final TextEditingController _homework;
  late double _progress;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: widget.initialContent);
    _objectives = TextEditingController(text: widget.initialObjectives);
    _homework = TextEditingController(text: widget.initialHomework);
    _progress = widget.initialProgress.toDouble();
  }

  @override
  void dispose() {
    _content.dispose();
    _objectives.dispose();
    _homework.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrototypeDetailScaffold(
      title: 'Cahier · ${widget.classLabel}',
      fallbackRoute: '/session/${widget.sessionId}',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
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
          Text('Progression programme · ${_progress.round()} %'),
          Slider(
            value: _progress,
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: (v) => setState(() => _progress = v),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          FilledButton(
            onPressed: () => widget.onSave(
              _content.text,
              _objectives.text,
              _homework.text,
              _progress.round(),
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
