import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/formatters.dart';
import '../design/colors.dart';
import '../design/components/components.dart';
import '../design/spacing.dart';
import '../mock/mock_store.dart';

/// Main Scolarité tab — grades and report cards.
class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key, required this.store});

  final MockStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => _ResultsList(store: store),
    );
  }
}

class ProgressOverviewPage extends StatefulWidget {
  const ProgressOverviewPage({super.key, required this.store});

  final MockStore store;

  @override
  State<ProgressOverviewPage> createState() => _ProgressOverviewPageState();
}

class _ProgressOverviewPageState extends State<ProgressOverviewPage> {
  late Set<String> _expandedSubjectIds;

  @override
  void initState() {
    super.initState();
    _expandedSubjectIds = {};
  }

  void _toggleSubject(String subject) {
    setState(() {
      if (_expandedSubjectIds.contains(subject)) {
        _expandedSubjectIds.remove(subject);
      } else {
        _expandedSubjectIds.add(subject);
      }
    });
  }

  void _openLogbook(BuildContext context, String subject) {
    context.push(
      '/scolarite/subject/${MockStore.subjectRouteParam(subject)}/cahier',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final summaries =
            widget.store.subjectProgressSummaries.where((s) => s.hasProgramme).toList();
        final overall = widget.store.overallProgramProgress;

        return PrototypeDetailScaffold(
          fallbackRoute: '/scolarite/notes',
          title: 'Avancement du programme',
          body: ListView(
            padding: const EdgeInsets.all(PrototypeSpacing.md),
            children: [
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(overall * 100).round()} % du programme couvert',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: PrototypeSpacing.xs),
                    PrototypeProgressBar(value: overall),
                    const SizedBox(height: PrototypeSpacing.xs),
                    Text(
                      'Moyenne indicative sur les matières suivies.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: PrototypeColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PrototypeSpacing.xl),
              for (var i = 0; i < summaries.length; i++) ...[
                if (i > 0) const SizedBox(height: PrototypeSpacing.xl),
                _SubjectProgressSectionHeader(
                  summary: summaries[i],
                  expanded: _expandedSubjectIds.contains(summaries[i].subject),
                  onOpenLogbook: () => _openLogbook(context, summaries[i].subject),
                  onToggle: () => _toggleSubject(summaries[i].subject),
                ),
                if (_expandedSubjectIds.contains(summaries[i].subject)) ...[
                  for (final topic
                      in widget.store.topicsForSubject(summaries[i].subject)) ...[
                    const SizedBox(height: PrototypeSpacing.xs),
                    ListRow(
                      title: topic.title,
                      subtitle: topic.status,
                      trailing: Text(
                        '${(topic.progress * 100).round()} %',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: PrototypeColors.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: PrototypeSpacing.sm),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SubjectProgressSectionHeader extends StatelessWidget {
  const _SubjectProgressSectionHeader({
    required this.summary,
    required this.expanded,
    required this.onOpenLogbook,
    required this.onToggle,
  });

  final SubjectProgressSummary summary;
  final bool expanded;
  final VoidCallback onOpenLogbook;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final percentLabel = '${(summary.progress * 100).round()} %';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PrototypeSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpenLogbook,
                borderRadius: BorderRadius.circular(PrototypeRadii.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    summary.subject,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                percentLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: PrototypeColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                summary.status,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(PrototypeRadii.sm),
              child: Padding(
                padding: const EdgeInsets.only(left: PrototypeSpacing.xs),
                child: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: PrototypeColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SubjectLogbookPage extends StatelessWidget {
  const SubjectLogbookPage({
    super.key,
    required this.store,
    required this.subject,
  });

  final MockStore store;
  final String subject;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final progress = store.progressForSubject(subject);
        final entries = store.logbookForSubject(subject);

        return PrototypeDetailScaffold(
          fallbackRoute: '/scolarite/progress',
          title: subject,
          body: ListView(
            padding: const EdgeInsets.all(PrototypeSpacing.md),
            children: [
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cahier de textes',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: PrototypeSpacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${(progress * 100).round()} % du programme couvert',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          store.statusForSubject(subject),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: PrototypeSpacing.sm),
                    PrototypeProgressBar(value: progress),
                  ],
                ),
              ),
              const SizedBox(height: PrototypeSpacing.md),
              const SectionHeader(title: 'Entrées'),
              if (entries.isEmpty)
                const EmptyState(
                  title: 'Aucune entrée pour cette matière',
                  message: 'Le cahier de textes sera affiché ici au fur et à mesure.',
                )
              else
                for (final entry in entries) ...[
                  ListRow(
                    title: entry.chapter,
                    subtitle: '${formatDate(entry.date)} · ${entry.content}',
                  ),
                  const SizedBox(height: PrototypeSpacing.xs),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _ResultsList extends StatefulWidget {
  const _ResultsList({required this.store});
  final MockStore store;

  @override
  State<_ResultsList> createState() => _ResultsListState();
}

class _ResultsListState extends State<_ResultsList> {
  late Set<String> _expandedPeriodIds;

  @override
  void initState() {
    super.initState();
    _expandedPeriodIds = {
      for (final period in widget.store.academicPeriods)
        if (period.status == MockPeriodStatus.open) period.id,
    };
  }

  void _togglePeriod(String periodId) {
    setState(() {
      if (_expandedPeriodIds.contains(periodId)) {
        _expandedPeriodIds.remove(periodId);
      } else {
        _expandedPeriodIds.add(periodId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final periods = widget.store.academicPeriods;
    final overallProgress = widget.store.overallProgramProgress;

    return ListView(
      padding: const EdgeInsets.all(PrototypeSpacing.md),
      children: [
        SurfaceCard(
          onTap: () => context.push('/scolarite/progress'),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PrototypeColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insights_outlined, color: Colors.blue),
              ),
              const SizedBox(width: PrototypeSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Avancement du programme',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${(overallProgress * 100).round()} % couvert · '
                      '${widget.store.subjectsWithProgrammeCount} matières',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: PrototypeSpacing.xs),
                    PrototypeProgressBar(value: overallProgress),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: PrototypeSpacing.xl),
        for (var i = 0; i < periods.length; i++) ...[
          if (i > 0) const SizedBox(height: PrototypeSpacing.xl),
          _PeriodSectionHeader(
            period: periods[i],
            expanded: _expandedPeriodIds.contains(periods[i].id),
            onToggle: () => _togglePeriod(periods[i].id),
          ),
          if (_expandedPeriodIds.contains(periods[i].id)) ...[
            if (widget.store.reportCardForPeriod(periods[i].label)
                case final reportCard?) ...[
              const SizedBox(height: PrototypeSpacing.xs),
              ListRow(
                title: 'Bulletin',
                subtitle: 'Publié le ${formatDate(reportCard.publishedAt)}',
                tint: PrototypeColors.primaryContainer,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PrototypeColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: PrototypeColors.primary,
                  ),
                ),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reportCard.average,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: PrototypeColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Moyenne',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                onTap: () => context.push('/report-card/${reportCard.id}'),
              ),
            ],
            for (final result
                in widget.store.subjectResultsForPeriod(periods[i].label)) ...[
              const SizedBox(height: PrototypeSpacing.xs),
              ListRow(
                title: result.subject,
                subtitle: result.gradeCount == 0
                    ? 'Aucune évaluation'
                    : result.gradeCount == 1
                    ? '1 évaluation'
                    : '${result.gradeCount} évaluations',
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      result.averageLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: result.hasAverage
                            ? PrototypeColors.primary
                            : PrototypeColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      result.state.label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                onTap: () => context.push(
                  '/scolarite/period/${periods[i].id}/subject/${MockStore.subjectRouteParam(result.subject)}',
                ),
              ),
            ],
            const SizedBox(height: PrototypeSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class SubjectGradesPage extends StatelessWidget {
  const SubjectGradesPage({
    super.key,
    required this.store,
    required this.periodId,
    required this.subject,
  });

  final MockStore store;
  final String periodId;
  final String subject;

  @override
  Widget build(BuildContext context) {
    final period = store.periodById(periodId);
    if (period == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/scolarite/notes',
        title: subject,
        body: const EmptyState(title: 'Période introuvable'),
      );
    }

    final results = store.subjectResultsFor(subject, period.label);
    final grades = store.gradesForSubjectAndPeriod(subject, period.label);

    return PrototypeDetailScaffold(
      fallbackRoute: '/scolarite/notes',
      title: subject,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          if (results != null)
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          period.label,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            results.averageLabel,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: results.hasAverage
                                  ? PrototypeColors.primary
                                  : PrototypeColors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            results.state.label,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (results.hasTeacherFeedback) ...[
                    const SizedBox(height: PrototypeSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: PrototypeSpacing.md),
                    if (results.teacherName != null) ...[
                      Text(
                        'Enseignant',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        results.teacherName!,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: PrototypeSpacing.sm),
                    ],
                    if (results.teacherComment != null) ...[
                      Text(
                        'Appréciation',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        results.teacherComment!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          const SizedBox(height: PrototypeSpacing.md),
          const SectionHeader(title: 'Évaluations'),
          if (grades.isEmpty)
            const EmptyState(
              title: 'Aucune évaluation',
              message: 'Les notes de cette matière ne sont pas encore disponibles.',
            )
          else
            for (final grade in grades) ...[
              ListRow(
                title: grade.title,
                subtitle: formatDate(grade.date),
                trailing: Text(
                  '${grade.score.toInt()}/${grade.maxScore.toInt()}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: PrototypeColors.primary,
                  ),
                ),
                onTap: () => context.push('/grade/${grade.id}'),
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
        ],
      ),
    );
  }
}

class _PeriodSectionHeader extends StatelessWidget {
  const _PeriodSectionHeader({
    required this.period,
    required this.expanded,
    required this.onToggle,
  });

  final MockAcademicPeriod period;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(PrototypeRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PrototypeSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  period.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusChip(
                label: period.status == MockPeriodStatus.open
                    ? 'En cours'
                    : 'À venir',
                tone: period.status == MockPeriodStatus.open
                    ? SemanticTone.info
                    : SemanticTone.neutral,
              ),
              const SizedBox(width: PrototypeSpacing.xs),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: PrototypeColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GradeDetailPage extends StatelessWidget {
  const GradeDetailPage({super.key, required this.store, required this.gradeId});
  final MockStore store;
  final String gradeId;

  @override
  Widget build(BuildContext context) {
    final grade = store.gradeById(gradeId);
    if (grade == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/scolarite/notes',
        title: 'Détail de la note',
        body: const EmptyState(title: 'Note introuvable'),
      );
    }
    return PrototypeDetailScaffold(
      fallbackRoute: '/scolarite/notes',
      title: 'Détail de la note',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(grade.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: PrototypeSpacing.sm),
                Text(
                  '${grade.score.toInt()} / ${grade.maxScore.toInt()}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: PrototypeColors.primary,
                  ),
                ),
                const SizedBox(height: PrototypeSpacing.md),
                SummaryMetric(label: 'Matière', value: grade.subject),
                const SizedBox(height: PrototypeSpacing.sm),
                SummaryMetric(label: 'Période', value: grade.period),
                const SizedBox(height: PrototypeSpacing.sm),
                SummaryMetric(
                  label: 'Coefficient',
                  value: grade.coefficient.toString(),
                ),
                const SizedBox(height: PrototypeSpacing.md),
                const StatusChip(
                  label: 'Moyenne provisoire',
                  tone: SemanticTone.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportCardDetailPage extends StatelessWidget {
  const ReportCardDetailPage({super.key, required this.store, required this.reportCardId});
  final MockStore store;
  final String reportCardId;

  @override
  Widget build(BuildContext context) {
    final card = store.reportCardById(reportCardId);
    if (card == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/scolarite/notes',
        title: 'Bulletin',
        body: const EmptyState(title: 'Bulletin introuvable'),
      );
    }
    return PrototypeDetailScaffold(
      fallbackRoute: '/scolarite/notes',
      title: card.period,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Moyenne générale', style: Theme.of(context).textTheme.labelSmall),
                Text(card.average, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: PrototypeSpacing.md),
                Text('Appréciation', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(card.summary, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download_outlined),
            label: const Text('Télécharger le PDF'),
          ),
        ],
      ),
    );
  }
}
