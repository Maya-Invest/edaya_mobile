import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart' show TimetableDaySummary;
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import '../fees/models/fee_formatting.dart' as fees;
import 'home_controller.dart';

class HomePage extends LScopedView<HomeController> {
  const HomePage({super.key});

  @override
  HomeController onConfigScope(LevitScope scope) {
    return scope.put(
      () => HomeController(
        studentContext: scope.find<StudentContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        session: scope.find<AppSessionController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, HomeController controller) {
    final reportCard = controller.latestBulletin.value;

    final attentionCards = <Widget>[
      if (controller.overdueFeeCount.value > 0)
        AttentionCard(
          tone: AttentionTone.important,
          title: 'Frais en retard',
          subtitle:
              '${controller.overdueFeeCount.value} ligne(s) · Solde ${fees.formatMoney(controller.feeBalance.value, controller.feeCurrency.value)}',
          icon: Icons.payments_outlined,
          onTap: () => context.go('/fees'),
        ),
      if (controller.openCampaigns.value.isNotEmpty)
        AttentionCard(
          tone: AttentionTone.message,
          title: 'Avis de l\'école',
          subtitle: controller.openCampaigns.value.length == 1
              ? (controller.openCampaigns.value.first.context?.summary ??
                    'Questionnaire à remplir')
              : '${controller.openCampaigns.value.length} campagnes ouvertes',
          icon: Icons.campaign_outlined,
          onTap: () {
            final open = controller.openCampaigns.value;
            if (open.length == 1) {
              context.push(
                '/inbox/avis/${open.first.campaignId}',
                extra: open.first,
              );
            } else {
              context.go('/inbox/avis');
            }
          },
        ),
      if (controller.photoNeedsAttention.value)
        AttentionCard(
          tone: AttentionTone.important,
          title: 'Photo de l\'élève',
          subtitle: 'Une action est demandée sur la photo',
          icon: Icons.photo_camera_outlined,
          onTap: () => context.push('/child'),
        ),
      if (controller.leftoverPapers.value.isNotEmpty)
        AttentionCard(
          tone: AttentionTone.normal,
          title: 'Document disponible',
          subtitle: leftoverFamilyPaperLabel(
            controller.leftoverPapers.value.first.templateKey,
          ),
          icon: Icons.description_outlined,
          onTap: () => context.push('/child'),
        ),
      if (reportCard != null)
        AttentionCard(
          tone: AttentionTone.normal,
          title: 'Bulletin disponible',
          subtitle:
              '${reportCard.periodName} · Moyenne ${reportCard.overallAverage == null ? '—' : reportCard.overallAverage!.toStringAsFixed(1).replaceAll('.', ',')}',
          icon: Icons.menu_book_outlined,
          onTap: () => context.push('/report-card/${reportCard.id}'),
        ),
      if (controller.unreadCount.value > 0)
        AttentionCard(
          tone: AttentionTone.message,
          title: 'Nouveaux messages',
          subtitle: '${controller.unreadCount.value} non lu(s)',
          icon: Icons.mail_outline,
          onTap: () => context.go('/inbox'),
        ),
    ];

    final today = controller.todayPlan.value;
    final tomorrow = controller.tomorrowPlan.value;

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
            title: 'Aujourd\'hui',
            plan: today,
            onOpenCalendar: () {
              controller.openCalendarDay(0);
              context.go('/calendar');
            },
          ),
          if (tomorrow != null && tomorrow.hasContent) ...[
            const SizedBox(height: PrototypeSpacing.xl),
            _HomeDaySection(
              title: 'Demain',
              plan: tomorrow,
              onOpenCalendar: () {
                controller.openCalendarDay(1);
                context.go('/calendar');
              },
            ),
          ],
          const SizedBox(height: PrototypeSpacing.xl),
          const SectionHeader(title: 'Finances'),
          for (final alert in controller.financeAlerts.value) ...[
            _FinanceAlertRow(alert: alert, onTap: () => context.go('/fees')),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
          if (controller.financeAlerts.value.isEmpty)
            Text(
              'Aucune échéance à surveiller',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: PrototypeSpacing.xl),
          SectionHeader(
            title: 'Dernières notes',
            action: 'Tout voir',
            onAction: () => context.go('/scolarite/notes'),
          ),
          for (final grade in controller.latestGrades.value) ...[
            ListRow(
              title: grade.title,
              subtitle:
                  '${grade.subjectName} · ${grade.date == null ? grade.periodName : formatDate(grade.date!)}',
              trailing: Text(
                grade.score == null
                    ? '—'
                    : '${grade.score!.toInt()}/${grade.maxScore.toInt()}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: PrototypeColors.primary,
                ),
              ),
              onTap: () => context.push('/grade/${grade.id}'),
            ),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
          if (controller.latestGrades.value.isEmpty)
            Text(
              'Aucune note pour le moment',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
            constraints.maxWidth >= PrototypeBreakpoints.compact &&
            cards.length > 1;
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
    required this.title,
    required this.plan,
    required this.onOpenCalendar,
  });

  final String title;
  final HomeDayPlan? plan;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final hasContent = plan?.hasContent ?? false;
    final summary = TimetableDaySummary(
      lessonCount: plan?.lessonCount ?? 0,
      activityCount: plan?.activityCount ?? 0,
      assessmentCount: plan?.assessmentCount ?? 0,
    );

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
          if (plan!.noSchoolDay != null) ...[
            SurfaceCard(
              tint: PrototypeColors.errorContainer.withValues(alpha: 0.45),
              child: Text(plan!.noSchoolDay!.title),
            ),
            const SizedBox(height: PrototypeSpacing.sm),
          ],
          for (final event in plan!.events) ...[
            ListRow(
              title: event.title,
              subtitle: event.kind,
              leading: const Icon(Icons.event_outlined),
            ),
            const SizedBox(height: PrototypeSpacing.xs),
          ],
          if (plan!.noSchoolDay == null)
            TimetableSummaryCard(summary: summary, onTap: onOpenCalendar),
          if (plan!.sessions.isNotEmpty) ...[
            const SizedBox(height: PrototypeSpacing.xs),
            for (final session in plan!.sessions.take(3)) ...[
              ListRow(
                title: session.subjectLabel ?? session.title,
                subtitle:
                    '${DateFormat('HH:mm', 'fr_FR').format(session.startsAt)} – ${DateFormat('HH:mm', 'fr_FR').format(session.endsAt)}',
                onTap: () => context.push('/session/${session.id}'),
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
          ],
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
    final badgeTone = alert.isOverdue
        ? SemanticTone.error
        : SemanticTone.neutral;

    return ListRow(
      title: alert.label,
      subtitle: 'Échéance ${formatDate(alert.dueDate)}',
      badge: badgeLabel,
      badgeTone: badgeTone,
      onTap: onTap,
      trailing: Text(
        fees.formatMoney(alert.amount, alert.currency),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: alert.isOverdue ? PrototypeColors.error : null,
        ),
      ),
    );
  }
}
