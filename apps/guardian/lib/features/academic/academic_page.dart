import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../calendar/models/calendar_session.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'academic_controller.dart';
import 'models/curriculum_scope_models.dart';

class AcademicPage extends LScopedView<AcademicController> {
  const AcademicPage({super.key});

  @override
  AcademicController onConfigScope(LevitScope scope) {
    return scope.put(
      () => AcademicController(
        studentContext: scope.find<StudentContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, AcademicController controller) {
    return LWatch(
      () => DataState(
        status: controller.dataStatus,
        errorMessage: controller.errorMessage.value,
        emptyMessage: controller.emptyMessage,
        onRetry: controller.loadAcademicData,
        child: RefreshIndicator(
          onRefresh: controller.loadAcademicData,
          child: _AcademicBody(controller: controller),
        ),
      ),
    );
  }
}

class _AcademicBody extends StatelessWidget {
  const _AcademicBody({required this.controller});

  final AcademicController controller;

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final tab = controller.selectedTab.value;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(context.tr.documentsEntry),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/documents'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.favorite_outline),
              title: Text(context.tr.familyFeedbackEntry),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/academic/family-feedback'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _SubjectSelector(controller: controller),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<AcademicDetailTab>(
              segments: [
                ButtonSegment(
                  value: AcademicDetailTab.progress,
                  label: Text(context.tr.teachingProgressTab),
                  icon: const Icon(Icons.insights_outlined),
                ),
                ButtonSegment(
                  value: AcademicDetailTab.logbook,
                  label: Text(context.tr.teachingLogbookTab),
                  icon: const Icon(Icons.menu_book_outlined),
                ),
              ],
              selected: {tab},
              onSelectionChanged: (selection) {
                controller.selectTab(selection.first);
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: tab == AcademicDetailTab.progress
                ? _ProgressTab(controller: controller)
                : _LogbookTab(controller: controller),
          ),
        ],
      );
    });
  }
}

class _SubjectSelector extends StatelessWidget {
  const _SubjectSelector({required this.controller});

  final AcademicController controller;

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final subjects = controller.classSubjectOptions.value;
      final selectedSubjectId = controller.selectedClassSubjectId.value;

      return DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: selectedSubjectId,
        decoration: InputDecoration(labelText: context.tr.classSubjectLabel),
        items: [
          for (final subject in subjects)
            DropdownMenuItem(
              value: subject.id,
              child: Text(subject.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: subjects.isEmpty ? null : controller.selectSubject,
      );
    });
  }
}

class _ProgressTab extends StatelessWidget {
  const _ProgressTab({required this.controller});

  final AcademicController controller;

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final overview = controller.progressOverview.value;
      if (overview == null) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(controller.emptyMessage)),
            ),
          ],
        );
      }

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.tr.percentComplete(
              overview.classSubjectCompletedPercentage,
            ),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: overview.classSubjectCompletedPercentage / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 16),
          if (overview.matters.isEmpty)
            Text(controller.emptyMessage)
          else
            for (final matter in overview.matters) ...[
              _MatterCard(matter: matter),
              const SizedBox(height: 8),
            ],
        ],
      );
    });
  }
}

class _MatterCard extends StatelessWidget {
  const _MatterCard({required this.matter});

  final CurriculumMatterProgress matter;

  @override
  Widget build(BuildContext context) {
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
                    matter.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Chip(
                  label: Text(_matterStatusLabel(context, matter.status)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr.percentComplete(matter.completedPercentage),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: matter.completedPercentage / 100,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
            ),
            if (matter.notes != null && matter.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(matter.notes!),
            ],
          ],
        ),
      ),
    );
  }

  String _matterStatusLabel(
    BuildContext context,
    CurriculumMatterStatus status,
  ) {
    return switch (status) {
      CurriculumMatterStatus.notStarted => context.tr.matterStatusNotStarted,
      CurriculumMatterStatus.inProgress => context.tr.matterStatusInProgress,
      CurriculumMatterStatus.completed => context.tr.matterStatusCompleted,
    };
  }
}

class _LogbookTab extends StatelessWidget {
  const _LogbookTab({required this.controller});

  final AcademicController controller;

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final entries = controller.logbookEntries.value;
      if (entries.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(controller.emptyMessage)),
            ),
          ],
        );
      }

      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _LogbookCard(
            entry: entry,
            onTap: () => _openSession(context, entry),
          );
        },
      );
    });
  }

  void _openSession(BuildContext context, CurriculumLogEntry entry) {
    context.push(
      '/calendar/session-details',
      extra: CalendarSession(
        id: entry.lessonSessionId,
        title: entry.displayLabel,
        kind: 'lesson',
        startsAt: entry.startsAt,
        endsAt: entry.endsAt,
        classSubjectId: entry.classSubjectId,
        subjectLabel: entry.subjectLabel,
      ),
    );
  }
}

class _LogbookCard extends StatelessWidget {
  const _LogbookCard({required this.entry, required this.onTap});

  final CurriculumLogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.formatLongDate(entry.startsAt),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                entry.displayLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (entry.sessionNote != null &&
                  entry.sessionNote!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  entry.sessionNote!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (entry.matterSnapshots.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final snapshot in entry.matterSnapshots)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${snapshot.matterName} · ${snapshot.completedPercentage}%'
                      '${snapshot.notes == null || snapshot.notes!.isEmpty ? '' : ' — ${snapshot.notes}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
              if (!entry.hasContent) ...[
                const SizedBox(height: 8),
                Text(
                  context.tr.noLogbookEntryForSession,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
