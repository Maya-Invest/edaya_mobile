import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/academic_year_controller.dart';
import '../context/staff_context_controller.dart';
import 'evaluations_controller.dart';
import 'widgets/academic_period_picker.dart';

class EvaluationCreateSheet extends LScopedView<EvaluationCreateController> {
  const EvaluationCreateSheet({super.key});

  @override
  EvaluationCreateController onConfigScope(LevitScope scope) {
    return scope.put(
      () => EvaluationCreateController(
        staffContext: scope.find<StaffContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        evaluations: scope.find<EvaluationsController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, EvaluationCreateController controller) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: _EvaluationCreateForm(controller: controller),
        ),
      ),
    );
  }
}

class _EvaluationCreateForm extends StatefulWidget {
  const _EvaluationCreateForm({required this.controller});

  final EvaluationCreateController controller;

  @override
  State<_EvaluationCreateForm> createState() => _EvaluationCreateFormState();
}

class _EvaluationCreateFormState extends State<_EvaluationCreateForm> {
  final _titleController = TextEditingController();
  final _maxScoreController = TextEditingController(text: '20');
  String? _classSubjectId;
  String? _periodId;
  String _kind = 'quiz';
  bool _saving = false;
  String? _error;

  static const _kinds = ['quiz', 'homework', 'project', 'other'];

  @override
  void dispose() {
    _titleController.dispose();
    _maxScoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LWatch(
      () {
        final subjects = widget.controller.classSubjects.value;
        final periods = widget.controller.periods.value;
        final evaluations = context.levit.find<EvaluationsController>();
        _classSubjectId ??= subjects.isNotEmpty ? subjects.first.id : null;
        _periodId ??=
            evaluations.selectedPeriodId.value ??
            widget.controller.defaultPeriodId() ??
            (periods.isNotEmpty ? periods.first['id'] as String : null);
        final selectedSubject = subjects.cast<ClassSubjectOption?>().firstWhere(
          (entry) => entry?.id == _classSubjectId,
          orElse: () => null,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr.newEvaluation,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (widget.controller.isBusy.value && subjects.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (subjects.isEmpty)
              Expanded(
                child: Center(
                  child: Text(context.tr.noSubjectsAssignedForYear),
                ),
              )
            else ...[
              if (periods.isNotEmpty) ...[
                AcademicPeriodPicker(
                  periods: periods,
                  selectedPeriodId: _periodId,
                  onPeriodSelected: (periodId) {
                    setState(() => _periodId = periodId);
                  },
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                initialValue: _classSubjectId,
                decoration: InputDecoration(
                  labelText: context.tr.classSubjectLabel,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final subject in subjects)
                    DropdownMenuItem(
                      value: subject.id,
                      child: Text(subject.label),
                    ),
                ],
                onChanged: (value) => setState(() => _classSubjectId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: context.tr.titleLabel,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _maxScoreController,
                decoration: InputDecoration(
                  labelText: context.tr.outOfLabel,
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: InputDecoration(
                  labelText: context.tr.kindLabel,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final kind in _kinds)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(_kindLabel(kind, context.tr)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _kind = value);
                  }
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _saving ||
                        selectedSubject == null ||
                        _periodId == null
                    ? null
                    : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr.createEvaluation),
              ),
            ],
          ],
        );
      },
    );
  }

  String _kindLabel(String kind, AppLocalizations l10n) => switch (kind) {
    'quiz' => l10n.evaluationKindQuiz,
    'homework' => l10n.evaluationKindHomework,
    'project' => l10n.evaluationKindProject,
    _ => l10n.evaluationKindOther,
  };

  Future<void> _submit() async {
    final subjects = widget.controller.classSubjects.value;
    final subject = subjects.cast<ClassSubjectOption?>().firstWhere(
      (entry) => entry?.id == _classSubjectId,
      orElse: () => null,
    );
    if (subject == null || _periodId == null) {
      return;
    }

    final maxScore = double.tryParse(_maxScoreController.text.trim());
    if (maxScore == null) {
      setState(() => _error = context.tr.enterValidMaxScore);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await widget.controller.createEvaluation(
      classGroupId: subject.classGroupId,
      classSubjectId: subject.id,
      periodId: _periodId!,
      title: _titleController.text,
      maxScore: maxScore,
      kind: _kind,
    );

    if (!mounted) {
      return;
    }

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    context.pop();
  }
}
