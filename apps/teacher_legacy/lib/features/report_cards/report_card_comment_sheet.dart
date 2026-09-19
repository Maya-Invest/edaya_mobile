import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/teacher_context_controller.dart';
import 'models/report_card_roster_models.dart';
import 'report_card_comment_controller.dart';
import 'report_card_comment_logic.dart';

class ReportCardCommentSheet extends LScopedView<ReportCardCommentController> {
  const ReportCardCommentSheet({
    super.key,
    required this.rosterArgs,
    required this.student,
  });

  final ReportCardRosterArgs rosterArgs;
  final ReportCardStudentRow student;

  @override
  ReportCardCommentController onConfigScope(LevitScope scope) {
    return scope.put(
      () => ReportCardCommentController(
        args: rosterArgs,
        student: student,
        teacherContext: scope.find<TeacherContextController>(),
        session: scope.find<AppSessionController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    ReportCardCommentController controller,
  ) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: _ReportCardCommentForm(
            controller: controller,
            student: student,
            scrollController: scrollController,
          ),
        );
      },
    );
  }
}

class _ReportCardCommentForm extends StatefulWidget {
  const _ReportCardCommentForm({
    required this.controller,
    required this.student,
    required this.scrollController,
  });

  final ReportCardCommentController controller;
  final ReportCardStudentRow student;
  final ScrollController scrollController;

  @override
  State<_ReportCardCommentForm> createState() => _ReportCardCommentFormState();
}

class _ReportCardCommentFormState extends State<_ReportCardCommentForm> {
  final _controllers = <String, TextEditingController>{};
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(ReportCardCommentField field) {
    return _controllers.putIfAbsent(
      field.sectionId,
      () => TextEditingController(text: field.initialComment),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final fields = widget.controller.fields.value;
      final readOnly = widget.controller.isReadOnly.value;
      final loading =
          widget.controller.isBusy.value &&
          fields.isEmpty &&
          widget.controller.errorMessage.value.isEmpty;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.student.studentName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(context.tr.reportCardCommentsTitle),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: DataState(
              status: loading ? DataStatus.loading : widget.controller.dataStatus,
              errorMessage: widget.controller.errorMessage.value,
              emptyMessage: widget.controller.emptyMessage,
              onRetry: widget.controller.load,
              child: ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (readOnly) ...[
                    Text(
                      context.tr.reportCardCommentsReadOnly,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final field in fields) ...[
                    Text(
                      _fieldLabel(context, field),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controllerFor(field),
                      readOnly: readOnly,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: context.tr.reportCardCommentHint,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.controller.saveMessage.value.isNotEmpty) ...[
                    Text(
                      widget.controller.saveMessage.value,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!readOnly && fields.isNotEmpty)
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.tr.save),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  String _fieldLabel(BuildContext context, ReportCardCommentField field) {
    if (field.isHomeroom) {
      return context.tr.homeroomComment;
    }
    if (field.isSubject) {
      return context.tr.subjectComment(field.label);
    }
    return field.label;
  }

  Future<void> _save() async {
    final comments = <String, String>{
      for (final field in widget.controller.fields.value)
        field.sectionId: _controllerFor(field).text.trim(),
    };

    setState(() => _saving = true);
    final saved = await widget.controller.save(comments);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    if (saved) {
      context.pop(true);
    }
  }
}
