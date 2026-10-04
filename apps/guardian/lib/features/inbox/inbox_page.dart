import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../app/shell_tabs.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';
import '../context/student_context_controller.dart';
import 'inbox_controller.dart';
import 'inbox_routes.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveInboxPage();
    }
    return const _MockInboxPage();
  }
}

class _MockInboxPage extends LScopedView<StoreBoundController> {
  const _MockInboxPage();

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final path = GoRouterState.of(context).uri.path;
    final hubPath = GuardianShellScope.maybeOf(context)?.hubPath ?? path;
    final inboxPath = path.startsWith('/inbox') ? path : hubPath;
    final showingAvis = inboxPath.startsWith('/inbox/avis');
    final selectedId =
        GoRouterState.of(context).pathParameters['id'] ??
        GoRouterState.of(context).pathParameters['campaignId'];
    final messages = store.messages;

    return AdaptiveContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
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
              showingAvis ? '0 ouvert(s)' : '${store.unreadCount} non lu(s)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: showingAvis
                ? EmptyState(title: context.tr.familyFeedbackEmpty)
                : messages.isEmpty
                ? const EmptyState(title: 'Aucun message')
                : ListView.separated(
                    padding: const EdgeInsets.all(PrototypeSpacing.md),
                    itemCount: messages.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: PrototypeSpacing.xs),
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final selected = selectedId == m.id;
                      return ListRow(
                        title: m.title,
                        subtitle: m.body.length > 80
                            ? '${m.body.substring(0, 80)}…'
                            : m.body,
                        unread: !m.read,
                        selected: selected,
                        badge: m.read
                            ? 'Lu · ${formatDate(m.sentAt)}'
                            : 'Nouveau',
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: m.read
                                ? const Color(0xFFF1F5F9)
                                : PrototypeColors.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.mail_outline,
                            size: 20,
                            color: m.read
                                ? PrototypeColors.onSurfaceVariant
                                : PrototypeColors.primary,
                          ),
                        ),
                        onTap: () => context.push(inboxMessagePath(m.id)),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: selected
                              ? PrototypeColors.primary
                              : PrototypeColors.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LiveInboxPage extends LScopedView<InboxController> {
  const _LiveInboxPage();

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
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
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
          if (showingAvis)
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
    return LWatch(() {
      final student = context.levit
          .find<StudentContextController>()
          .activeStudent
          .value;
      return MessagingInbox(
        guardian: true,
        studentId: student?.id,
        studentName: student?.fullName,
        notices: [
          for (final m in controller.deliveries.value.where(
            (m) => m.eventKey != 'conversation.message',
          ))
            MessagingNotice(
              id: m.id,
              title: m.title,
              body: m.body,
              unread: m.isUnread,
              at: m.sortDate,
            ),
        ],
        onNotice: (id) => context.push(inboxMessagePath(id)),
      );
    });
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
