import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import 'home_controller.dart';

class HomePage extends LScopedView<HomeController> {
  const HomePage({super.key});

  @override
  HomeController onConfigScope(LevitScope scope) {
    return scope.put(() => HomeController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, HomeController controller) {
        controller.storeTick.value;
    final store = controller.store;
    final reportCard = store.currentPeriodReportCard;

    final attentionCards = <Widget>[
      if (store.overdueFeeCount > 0)
        AttentionCard(
          tone: AttentionTone.important,
          title: 'Frais en retard',
          subtitle:
              '${store.overdueFeeCount} ligne(s) · Solde ${formatMoney(store.feeBalance, 'EUR')}',
          icon: Icons.payments_outlined,
          onTap: () => context.go('/fees'),
        ),
      if (reportCard != null)
        AttentionCard(
          tone: AttentionTone.normal,
          title: 'Bulletin disponible',
          subtitle: '${reportCard.period} · Moyenne ${reportCard.average}',
          icon: Icons.description_outlined,
          onTap: () => context.go('/scolarite/notes'),
        ),
      if (store.unreadCount > 0)
        AttentionCard(
          tone: AttentionTone.message,
          title: 'Nouveaux messages',
          subtitle: '${store.unreadCount} non lu(s)',
          icon: Icons.mail_outline,
          onTap: () => context.go('/inbox'),
        ),
    ];

    return AdaptiveContent(
      child: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          Text(
            formatFullDate(DateTime.now()),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: PrototypeSpacing.xl),
          _AttentionBand(cards: attentionCards),
          const SizedBox(height: PrototypeSpacing.xl),
          _HomeDaySection(
            store: store,
            title: 'Aujourd\'hui',
            dayOffset: 0,
            onOpenCalendar: () {
              controller.openCalendarDay(0);
              context.go('/calendar');
            },
          ),
          if (store.hasHomeDayPlan(1)) ...[
            const SizedBox(height: PrototypeSpacing.xl),
            _HomeDaySection(
              store: store,
              title: 'Demain',
              dayOffset: 1,
              onOpenCalendar: () {
                controller.openCalendarDay(1);
                context.go('/calendar');
              },
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
      ),
    );
  }
}

class _AttentionBand extends StatelessWidget {
  const _AttentionBand({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final multiCol =
            constraints.maxWidth >= PrototypeBreakpoints.compact && cards.length > 1;
        if (!multiCol) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: PrototypeSpacing.sm),
                cards[i],
              ],
            ],
          );
        }

        return Wrap(
          spacing: PrototypeSpacing.sm,
          runSpacing: PrototypeSpacing.sm,
          children: [
            for (final card in cards)
              SizedBox(
                width: (constraints.maxWidth - PrototypeSpacing.sm) / 2,
                child: card,
              ),
          ],
        );
      },
    );
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
    final badgeTone =
        alert.isOverdue ? SemanticTone.error : SemanticTone.neutral;

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
