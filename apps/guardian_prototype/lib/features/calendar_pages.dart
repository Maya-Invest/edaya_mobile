import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/formatters.dart';
import '../design/colors.dart';
import '../design/components/components.dart';
import '../design/session_category.dart';
import '../design/spacing.dart';
import '../mock/mock_store.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key, required this.store});

  final MockStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PrototypeSpacing.md,
                PrototypeSpacing.sm,
                PrototypeSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  _CalendarDatePicker(store: store),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.push('/attendance'),
                    icon: const Icon(Icons.list_alt_outlined, size: 18),
                    label: const Text('Toutes les présences'),
                  ),
                ],
              ),
            ),
            _WeekSelector(store: store),
            Expanded(child: _MergedDayList(store: store)),
          ],
        );
      },
    );
  }
}

class _CalendarDatePicker extends StatelessWidget {
  const _CalendarDatePicker({required this.store});

  final MockStore store;

  Future<void> _pickDate(BuildContext context) async {
    final selected = store.selectedCalendarDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2018),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      store.selectCalendarDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _pickDate(context),
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(formatDate(store.selectedCalendarDate)),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({required this.store});
  final MockStore store;

  static const _dayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  bool _showsMonthLabel(List<DateTime> weekDates, int index) {
    if (index == 0) return true;
    final current = weekDates[index];
    final previous = weekDates[index - 1];
    return current.month != previous.month;
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = List.generate(7, store.dateForWeekDay);
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 9,
      height: 1,
      color: PrototypeColors.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: PrototypeSpacing.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Semaine précédente',
            onPressed: store.goToPreviousWeek,
            icon: const Icon(Icons.chevron_left),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: SizedBox(
                          height: 12,
                          child: _showsMonthLabel(weekDates, i)
                              ? Text(
                                  formatMonthAbbrev(weekDates[i]),
                                  textAlign: TextAlign.center,
                                  style: labelStyle,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: PrototypeSpacing.xxs),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: store.selectedDayIndex == i
                                  ? PrototypeColors.primary
                                  : PrototypeColors.surface,
                              foregroundColor: store.selectedDayIndex == i
                                  ? Colors.white
                                  : PrototypeColors.onBackground,
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            onPressed: () => store.selectDay(i),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _dayLabels[i],
                                  style: const TextStyle(fontSize: 10),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatDayOfMonth(weekDates[i]),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Semaine suivante',
            onPressed: store.goToNextWeek,
            icon: const Icon(Icons.chevron_right),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _MergedDayList extends StatelessWidget {
  const _MergedDayList({required this.store});

  final MockStore store;

  @override
  Widget build(BuildContext context) {
    final noSchoolDay = store.noSchoolDayForSelectedDay;
    final schoolEvents = store.schoolEventsForSelectedDay;
    final sessions = store.sessionsForSelectedDay;
    final hasContent =
        noSchoolDay != null || schoolEvents.isNotEmpty || sessions.isNotEmpty;

    if (!hasContent) {
      return const EmptyState(title: 'Rien de prévu ce jour');
    }

    return ListView(
      padding: const EdgeInsets.all(PrototypeSpacing.md),
      children: [
        if (noSchoolDay != null) ...[
          NoSchoolDayBanner(event: noSchoolDay),
          if (schoolEvents.isNotEmpty || sessions.isNotEmpty)
            const SizedBox(height: PrototypeSpacing.sm),
        ],
        for (var i = 0; i < schoolEvents.length; i++) ...[
          if (i > 0) const SizedBox(height: PrototypeSpacing.xs),
          SchoolEventRow(event: schoolEvents[i]),
        ],
        if (schoolEvents.isNotEmpty && sessions.isNotEmpty)
          const SizedBox(height: PrototypeSpacing.sm),
        if (sessions.isNotEmpty && (noSchoolDay != null || schoolEvents.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: PrototypeSpacing.xs),
            child: Text(
              'Emploi du temps',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: PrototypeColors.onSurfaceVariant,
              ),
            ),
          ),
        for (var i = 0; i < sessions.length; i++) ...[
          if (i > 0) const SizedBox(height: PrototypeSpacing.xs),
          ListRow(
            title: sessions[i].subject,
            subtitle:
                '${formatTimeRange(sessions[i].startHour, sessions[i].endHour)} · ${sessions[i].teacher}',
            leading: SessionCategoryIcon(category: sessions[i].category),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/session/${sessions[i].id}'),
          ),
        ],
      ],
    );
  }
}

class AttendanceListPage extends StatelessWidget {
  const AttendanceListPage({super.key, required this.store});
  final MockStore store;

  @override
  Widget build(BuildContext context) {
    return PrototypeDetailScaffold(
      fallbackRoute: '/calendar',
      title: 'Présences',
      body: ListView.separated(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        itemCount: store.attendance.length,
        separatorBuilder: (_, _) => const SizedBox(height: PrototypeSpacing.xs),
        itemBuilder: (context, i) {
          final a = store.attendance[i];
          final tone = a.status == 'Absent'
              ? SemanticTone.error
              : a.status == 'Retard'
              ? SemanticTone.warning
              : SemanticTone.success;
          return ListRow(
            title: a.subject,
            subtitle: formatDate(a.date),
            badge: a.status,
            badgeTone: tone,
          );
        },
      ),
    );
  }
}

class SessionDetailPage extends StatelessWidget {
  const SessionDetailPage({super.key, required this.store, required this.sessionId});

  final MockStore store;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final session = store.sessionById(sessionId);
    if (session == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/calendar',
        title: 'Séance',
        body: const EmptyState(title: 'Séance introuvable'),
      );
    }

    final logbook = store.logbookForSession(sessionId);
    final assessment = store.assessmentForSession(sessionId);
    final activity = store.activityForSession(sessionId);
    final textTheme = Theme.of(context).textTheme;

    return PrototypeDetailScaffold(
      fallbackRoute: '/calendar',
      titleWidget: Row(
        children: [
          SessionCategoryIcon(category: session.category, size: 18, padding: 6),
          const SizedBox(width: PrototypeSpacing.xs),
          Expanded(
            child: Text(
              session.subject,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(
                      label: session.category.label,
                      tone: _categoryTone(session.category),
                    ),
                    const Spacer(),
                    StatusChip(
                      label: session.attendance,
                      tone: _attendanceTone(session.attendance),
                    ),
                  ],
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Enseignant', style: textTheme.labelSmall),
                          Text(session.teacher),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Horaire', style: textTheme.labelSmall),
                        Text(formatTimeRange(session.startHour, session.endHour)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          switch (session.category) {
            HomeDayCategory.lesson => _LessonDetailSection(logbook: logbook),
            HomeDayCategory.assessment => _AssessmentDetailSection(
              assessment: assessment,
            ),
            HomeDayCategory.activity => _ActivityDetailSection(activity: activity),
          },
        ],
      ),
    );
  }
}

class _LessonDetailSection extends StatelessWidget {
  const _LessonDetailSection({required this.logbook});

  final MockLogbookEntry? logbook;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Cahier de textes'),
        SurfaceCard(
          child: logbook == null
              ? Text(
                  'Aucune entrée de cahier de textes pour cette séance.',
                  style: textTheme.bodyMedium,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      logbook!.chapter,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: PrototypeSpacing.xs),
                    Text(logbook!.content, style: textTheme.bodyMedium),
                    if (logbook!.homework != null) ...[
                      const SizedBox(height: PrototypeSpacing.xs),
                      Text(
                        'Devoirs : ${logbook!.homework}',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: PrototypeSpacing.xs),
                    Text(
                      'Progression : ${logbook!.progress} %',
                      style: textTheme.bodySmall?.copyWith(
                        color: PrototypeColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AssessmentDetailSection extends StatelessWidget {
  const _AssessmentDetailSection({required this.assessment});

  final MockAssessmentDetail? assessment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (assessment == null) {
      return SurfaceCard(
        child: Text(
          'Aucun détail disponible pour cette évaluation.',
          style: textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Évaluation'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assessment!.title,
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (assessment!.period != null) ...[
                const SizedBox(height: PrototypeSpacing.xs),
                Text(
                  assessment!.period!,
                  style: textTheme.bodySmall?.copyWith(
                    color: PrototypeColors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: PrototypeSpacing.sm),
              Text(assessment!.description, style: textTheme.bodyMedium),
              const SizedBox(height: PrototypeSpacing.sm),
              Text('Consignes', style: textTheme.labelSmall),
              const SizedBox(height: PrototypeSpacing.xxs),
              Text(assessment!.instructions, style: textTheme.bodyMedium),
              if (assessment!.coefficient != null) ...[
                const SizedBox(height: PrototypeSpacing.sm),
                Text(
                  'Coefficient : ${assessment!.coefficient!.toStringAsFixed(0)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: PrototypeColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (assessment!.hasMark) ...[
          const SizedBox(height: PrototypeSpacing.md),
          const SectionHeader(title: 'Note de l\'élève'),
          SurfaceCard(
            child: Row(
              children: [
                Text(
                  '${assessment!.score!.toStringAsFixed(0)}/${assessment!.maxScore!.toStringAsFixed(0)}',
                  style: textTheme.headlineSmall?.copyWith(
                    color: PrototypeColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                StatusChip(label: 'Publiée', tone: SemanticTone.success),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: PrototypeSpacing.md),
          SurfaceCard(
            child: Text(
              'La note n\'est pas encore publiée pour cette évaluation.',
              style: textTheme.bodyMedium?.copyWith(
                color: PrototypeColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActivityDetailSection extends StatelessWidget {
  const _ActivityDetailSection({required this.activity});

  final MockActivityDetail? activity;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (activity == null) {
      return SurfaceCard(
        child: Text(
          'Aucun commentaire partagé pour cette activité.',
          style: textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Commentaire de l\'équipe'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity!.staffName,
                style: textTheme.labelLarge,
              ),
              const SizedBox(height: PrototypeSpacing.xxs),
              Text(
                formatDateTime(activity!.sharedAt),
                style: textTheme.bodySmall?.copyWith(
                  color: PrototypeColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: PrototypeSpacing.sm),
              Text(activity!.staffComment, style: textTheme.bodyMedium),
            ],
          ),
        ),
        if (activity!.photos.isNotEmpty) ...[
          const SizedBox(height: PrototypeSpacing.md),
          const SectionHeader(title: 'Photos partagées'),
          for (final photo in activity!.photos) ...[
            _ActivityPhotoCard(photo: photo),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
        ],
      ],
    );
  }
}

class _ActivityPhotoCard extends StatelessWidget {
  const _ActivityPhotoCard({required this.photo});

  final MockActivityPhoto photo;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PrototypeRadii.md),
            ),
            child: AspectRatio(
              aspectRatio: 3 / 2,
              child: Image.network(
                photo.url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: PrototypeColors.primaryContainer,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(PrototypeSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusChip(
                        label: photo.isGroup ? 'Groupe' : 'Individuelle',
                        tone: photo.isGroup ? SemanticTone.info : SemanticTone.neutral,
                      ),
                      const SizedBox(height: PrototypeSpacing.xs),
                      Text(photo.caption, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Partager',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Partage de « ${photo.caption} »')),
                    );
                  },
                  icon: const Icon(Icons.ios_share_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

SemanticTone _categoryTone(HomeDayCategory category) {
  return switch (category) {
    HomeDayCategory.lesson => SemanticTone.info,
    HomeDayCategory.activity => SemanticTone.neutral,
    HomeDayCategory.assessment => SemanticTone.warning,
  };
}

SemanticTone _attendanceTone(String status) {
  return switch (status) {
    'Absent' => SemanticTone.error,
    'Retard' => SemanticTone.warning,
    _ => SemanticTone.success,
  };
}
