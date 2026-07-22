import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/formatters.dart';
import '../design/colors.dart';
import '../design/components/components.dart';
import '../design/spacing.dart';
import '../mock/mock_store.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store});

  final MockStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final reportCard = store.currentPeriodReportCard;

        return ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            Text(
              formatFullDate(DateTime.now()),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: PrototypeSpacing.xl),
            if (store.overdueFeeCount > 0)
              AttentionCard(
                title: 'Frais en retard',
                subtitle:
                    '${store.overdueFeeCount} ligne(s) · Solde ${formatMoney(store.feeBalance, 'EUR')}',
                actionLabel: 'Voir les frais',
                icon: Icons.payments_outlined,
                onAction: () => context.go('/fees'),
              ),
            if (reportCard != null) ...[
              if (store.overdueFeeCount > 0) const SizedBox(height: PrototypeSpacing.sm),
              SurfaceCard(
                onTap: () => context.go('/scolarite/notes'),
                tint: PrototypeColors.primaryContainer,
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, color: Colors.blue),
                    const SizedBox(width: PrototypeSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bulletin disponible',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '${reportCard.period} · Moyenne ${reportCard.average}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],
            if (store.unreadCount > 0) ...[
              if (store.overdueFeeCount > 0 || reportCard != null)
                const SizedBox(height: PrototypeSpacing.sm),
              SurfaceCard(
                onTap: () => context.go('/inbox'),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PrototypeColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.mail_outline, color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: PrototypeSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nouveaux messages',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '${store.unreadCount} non lu(s)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],
            const SizedBox(height: PrototypeSpacing.xl),
            _HomeDaySection(
              store: store,
              title: 'Aujourd\'hui',
              dayOffset: 0,
              onOpenCalendar: () => _openCalendar(context, 0),
            ),
            if (store.hasHomeDayPlan(1)) ...[
              const SizedBox(height: PrototypeSpacing.xl),
              _HomeDaySection(
                store: store,
                title: 'Demain',
                dayOffset: 1,
                onOpenCalendar: () => _openCalendar(context, 1),
              ),
            ],
            const SizedBox(height: PrototypeSpacing.xl),
            const SectionHeader(title: 'Finances'),
            for (final alert in store.homeFinanceAlerts) ...[
              _FinanceAlertRow(alert: alert, onTap: () => context.go('/fees')),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
            const SizedBox(height: PrototypeSpacing.xl),
            SectionHeader(
              title: 'Dernières notes',
              action: 'Tout voir',
              onAction: () => context.go('/scolarite/notes'),
            ),
            for (final grade in store.latestGrades) ...[
              ListRow(
                title: grade.title,
                subtitle: '${grade.subject} · ${formatDate(grade.date)}',
                trailing: Text(
                  '${grade.score.toInt()}/${grade.maxScore.toInt()}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: PrototypeColors.primary,
                  ),
                ),
                onTap: () => context.go('/scolarite/notes'),
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
          ],
        );
      },
    );
  }

  void _openCalendar(BuildContext context, int dayOffset) {
    store.selectCalendarDayOffset(dayOffset);
    context.go('/calendar');
  }
}

class _HomeDaySection extends StatelessWidget {
  const _HomeDaySection({
    required this.store,
    required this.title,
    required this.dayOffset,
    required this.onOpenCalendar,
  });

  final MockStore store;
  final String title;
  final int dayOffset;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final noSchoolDay = store.noSchoolDayForOffset(dayOffset);
    final schoolEvents = store.schoolEventsForDayOffset(dayOffset);
    final timetableSummary = store.timetableSummaryForDayOffset(dayOffset);
    final hasContent = store.hasHomeDayPlan(dayOffset);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        if (!hasContent)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: PrototypeSpacing.xs),
            child: Text(
              'Rien de prévu',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else ...[
          if (noSchoolDay != null) ...[
            NoSchoolDayBanner(event: noSchoolDay),
            const SizedBox(height: PrototypeSpacing.sm),
          ],
          for (final event in schoolEvents) ...[
            SchoolEventRow(event: event),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
          if (noSchoolDay == null)
            TimetableSummaryCard(
              summary: timetableSummary,
              onTap: onOpenCalendar,
            ),
        ],
      ],
    );
  }
}

class _FinanceAlertRow extends StatelessWidget {
  const _FinanceAlertRow({required this.alert, this.onTap});

  final HomeFinanceAlert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = alert.isOverdue ? 'En retard' : 'À venir';
    final badgeTone = alert.isOverdue ? SemanticTone.error : SemanticTone.neutral;

    return ListRow(
      title: alert.label,
      subtitle: 'Échéance ${formatDate(alert.dueDate)}',
      badge: badgeLabel,
      badgeTone: badgeTone,
      onTap: onTap,
      trailing: Text(
        formatMoney(alert.amount, alert.currency),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: alert.isOverdue ? PrototypeColors.error : null,
        ),
      ),
    );
  }
}
