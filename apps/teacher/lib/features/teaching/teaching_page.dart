import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../calendar/models/teacher_session.dart';
import 'models/teaching_models.dart';
import 'teaching_controller.dart';

class TeachingPage extends LView<TeachingController> {
  const TeachingPage({super.key});

  @override
  Widget buildView(BuildContext context, TeachingController controller) {
    return LWatch(
      () => DataState(
        status: controller.dataStatus,
        errorMessage: controller.errorMessage.value,
        emptyMessage: controller.emptyMessage,
        onRetry: controller.loadTeachingData,
        child: RefreshIndicator(
          onRefresh: controller.loadTeachingData,
          child: _TeachingBody(controller: controller),
        ),
      ),
    );
  }
}

class _TeachingBody extends StatelessWidget {
  const _TeachingBody({required this.controller});

  final TeachingController controller;

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final tab = controller.selectedTab.value;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _TeachingScopeSelectors(controller: controller),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.favorite_outline),
              title: Text(context.tr.familyFeedbackEntry),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/teaching/family-feedback'),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<TeachingDetailTab>(
              segments: [
                ButtonSegment(
                  value: TeachingDetailTab.progress,
                  label: Text(context.tr.teachingProgressTab),
                  icon: const Icon(Icons.insights_outlined),
                ),
                ButtonSegment(
                  value: TeachingDetailTab.logbook,
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
            child: tab == TeachingDetailTab.progress
                ? _TeachingProgressTab(controller: controller)
                : _TeachingLogbookTab(controller: controller),
          ),
        ],
      );
    });
  }
}

class _TeachingScopeSelectors extends StatelessWidget {
  const _TeachingScopeSelectors({required this.controller});

  final TeachingController controller;

  @override
  Widget build(BuildContext context) {
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
  }
}

class _TeachingProgressTab extends StatelessWidget {
  const _TeachingProgressTab({required this.controller});

  final TeachingController controller;

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

      if (overview.matters.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(context.tr.noCurriculumChaptersLinked)),
            ),
          ],
        );
      }

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.tr.subjectProgressSummary(
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
          for (final matter in overview.matters)
            _TeachingMatterCard(matter: matter),
        ],
      );
    });
  }
}

class _TeachingMatterCard extends StatelessWidget {
  const _TeachingMatterCard({required this.matter});

  final TeachingMatterProgress matter;

  @override
  Widget build(BuildContext context) {
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
              context.tr.cumulativeProgressLabel(matter.completedPercentage),
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

  String _matterStatusLabel(BuildContext context, TeachingMatterStatus status) {
    return switch (status) {
      TeachingMatterStatus.notStarted => context.tr.matterStatusNotStarted,
      TeachingMatterStatus.inProgress => context.tr.matterStatusInProgress,
      TeachingMatterStatus.completed => context.tr.matterStatusCompleted,
    };
  }
}

class _TeachingLogbookTab extends StatelessWidget {
  const _TeachingLogbookTab({required this.controller});

  final TeachingController controller;

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final entries = controller.logbookEntries.value;
      if (entries.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DocumentActionButton(
                  label: context.tr.exportLogbookPdf,
                  run: controller.generateLogbookPdf,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(context.tr.noTeachingLogEntries)),
            ),
          ],
        );
      }

      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: entries.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Align(
              alignment: Alignment.centerLeft,
              child: DocumentActionButton(
                label: context.tr.exportLogbookPdf,
                run: controller.generateLogbookPdf,
              ),
            );
          }
          final entry = entries[index - 1];
          return _TeachingLogbookCard(
            entry: entry,
            onTap: () => _openSession(context, entry),
          );
        },
      );
    });
  }

  void _openSession(BuildContext context, TeachingLogEntry entry) {
    context.push(
      '/calendar/session-details',
      extra: TeacherSession(
        id: entry.lessonSessionId,
        title: entry.displayLabel,
        kind: 'lesson',
        startsAt: entry.startsAt,
        endsAt: entry.endsAt,
        classGroupId: entry.classGroupId,
        classLabel: entry.classLabel,
        subjectLabel: entry.subjectLabel,
        classSubjectId: entry.classSubjectId,
      ),
    );
  }
}

class _TeachingLogbookCard extends StatelessWidget {
  const _TeachingLogbookCard({required this.entry, required this.onTap});

  final TeachingLogEntry entry;
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
