import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../app/shell_tabs.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../context/student_context_controller.dart';
import 'inbox_controller.dart';
import 'inbox_routes.dart';

class InboxPage extends LScopedView<InboxController> {
  const InboxPage({super.key});

  @override
  InboxController onConfigScope(LevitScope scope) {
    return scope.put(
      () => InboxController(
        session: scope.find<AppSessionController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
        studentContext: scope.find<StudentContextController>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, InboxController controller) {
    final path = GoRouterState.of(context).uri.path;
    final hubPath = GuardianShellScope.maybeOf(context)?.hubPath ?? path;
    final inboxPath = path.startsWith('/inbox') ? path : hubPath;
    final showingAvis = inboxPath.startsWith('/inbox/avis');
    final selectedId =
        GoRouterState.of(context).pathParameters['id'] ??
        GoRouterState.of(context).pathParameters['campaignId'];

    if (controller.dataStatus == DataStatus.loading) {
      return const AdaptiveContent(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.dataStatus == DataStatus.error) {
      return AdaptiveContent(
        child: EmptyState(title: controller.errorMessage.value),
      );
    }

    return AdaptiveContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Messages')),
                ButtonSegment(value: true, label: Text('Avis')),
              ],
              selected: {showingAvis},
              onSelectionChanged: (value) {
                context.go(value.first ? '/inbox/avis' : '/inbox');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              showingAvis
                  ? '${controller.openCampaignCount} ouvert(s)'
                  : '${controller.unreadCount} non lu(s)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: showingAvis
                ? _CampaignList(controller: controller, selectedId: selectedId)
                : _MessageList(controller: controller, selectedId: selectedId),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.controller, required this.selectedId});

  final InboxController controller;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final deliveries = controller.deliveries.value;
    if (deliveries.isEmpty) {
      return EmptyState(title: controller.emptyMessage);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(PrototypeSpacing.md),
      itemCount: deliveries.length,
      separatorBuilder: (_, _) => const SizedBox(height: PrototypeSpacing.xs),
      itemBuilder: (context, i) {
        final m = deliveries[i];
        final selected = selectedId == m.id;
        final sentAt = m.sortDate;
        return ListRow(
          title: m.title,
          subtitle: m.body.length > 80 ? '${m.body.substring(0, 80)}…' : m.body,
          unread: m.isUnread,
          selected: selected,
          badge: m.isUnread
              ? 'Nouveau'
              : sentAt == null
              ? 'Lu'
              : 'Lu · ${formatDate(sentAt)}',
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: m.isUnread
                  ? PrototypeColors.primaryContainer
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.mail_outline,
              size: 20,
              color: m.isUnread
                  ? PrototypeColors.primary
                  : PrototypeColors.onSurfaceVariant,
            ),
          ),
          onTap: () => context.push(inboxMessagePath(m.id), extra: m),
          trailing: Icon(
            Icons.chevron_right,
            color: selected
                ? PrototypeColors.primary
                : PrototypeColors.onSurfaceVariant,
          ),
        );
      },
    );
  }
}

class _CampaignList extends StatelessWidget {
  const _CampaignList({required this.controller, required this.selectedId});

  final InboxController controller;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final campaigns = controller.campaigns.value;
    if (campaigns.isEmpty) {
      return EmptyState(title: context.tr.familyFeedbackEmpty);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(PrototypeSpacing.md),
      itemCount: campaigns.length,
      separatorBuilder: (_, _) => const SizedBox(height: PrototypeSpacing.xs),
      itemBuilder: (context, i) {
        final item = campaigns[i];
        final selected = selectedId == item.campaignId;
        final title = item.context?.subjectName.isNotEmpty == true
            ? '${item.context!.subjectName} · ${item.context!.teacherName}'
            : context.tr.familyFeedbackTitle;
        final subtitle =
            item.slotState == 'completed' ||
                item.slotState == 'already_completed'
            ? context.tr.familyFeedbackSlotCompleted
            : item.slotState == 'open'
            ? context.tr.familyFeedbackSlotOpen
            : context.tr.familyFeedbackClosed;
        return ListRow(
          title: title,
          subtitle: subtitle,
          unread: item.slotState == 'open',
          selected: selected,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PrototypeColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.campaign_outlined, size: 20),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              context.push('/inbox/avis/${item.campaignId}', extra: item),
        );
      },
    );
  }
}
