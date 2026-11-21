import '../../design/workspace_layout.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';
import '../context/teacher_context_controller.dart';
import '../classes/workspace_classes.dart';
import 'inbox_delivery.dart';
import 'inbox_routes.dart';
import 'live_inbox_controller.dart';
import 'message_detail_controller.dart';

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

class _LiveInboxPage extends LView<LiveInboxController> {
  const _LiveInboxPage();

  @override
  Widget buildView(BuildContext context, LiveInboxController controller) {
    return LWatch(() {
      controller.deliveries.value;
      controller.errorMessage.value;
      controller.loadingNotices.value;
      return _ThreadGroups(inbox: controller);
    });
  }
}

class _ThreadGroups extends LScopedView<ConversationController> {
  const _ThreadGroups({required this.inbox});
  final LiveInboxController inbox;
  @override
  ConversationController onConfigScope(LevitScope scope) => scope.put(
    () => ConversationController(
      session: scope.find<AppSessionController>(),
      client: scope.find<SchoolClientFactory>(),
      visible: false,
    ),
  );
  @override
  Widget buildView(BuildContext context, ConversationController threads) {
    final tc = context.levit.find<TeacherContextController>();
    String? group(Map row) {
      final ids = (row['assignmentIds'] as List? ?? [])
          .map((id) => tc.classByAssignmentId.value[id])
          .whereType<String>()
          .toSet();
      return ids.length == 1 ? ids.single : null;
    }

    Widget? date(DateTime? time) => time == null
        ? null
        : Text(
            MaterialLocalizations.of(context).formatShortDate(time.toLocal()),
          );
    Widget thread(Map row) {
      final lastActivity = DateTime.tryParse(
        '${row['updatedAt'] ?? row['createdAt']}',
      );
      final guardian = row['guardianName'] as String? ?? '';
      final preview = row['lastMessage'] as String? ?? '';
      void open() => context.push('/inbox/conversation/${row['id']}');
      return ResponsiveRosterTile(
        cells: [
          row['subject'] as String,
          guardian,
          preview,
          lastActivity == null
              ? ''
              : MaterialLocalizations.of(
                  context,
                ).formatShortDate(lastActivity.toLocal()),
        ],
        compact: ListTile(
          title: Text(row['subject'] as String),
          subtitle: Text(
            '$guardian · $preview',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: date(lastActivity),
          leading: Icon(
            row['unread'] == true
                ? Icons.mark_email_unread_outlined
                : Icons.mail_outline,
          ),
          onTap: open,
        ),
      );
    }

    return ConversationActivity(
      controller: threads,
      child: LWatch(
        () => WorkspaceTabs(
          values: const ['conversations', 'notifications'],
          labels: [
            context.tr.messagingConversations,
            context.tr.workspaceNotifications,
          ],
          children: [
            FeatureActionPanel(
              actions: [
                FeatureAction(
                  context.tr.newConversation,
                  Icons.edit_outlined,
                  () => context.push('/inbox/new'),
                ),
              ],
              child: RefreshIndicator(
                onRefresh: threads.refresh,
                child: ListView(
                  key: const PageStorageKey('teacher-conversations'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (threads.busy.value) const LinearProgressIndicator(),
                    if (threads.error.value.isNotEmpty)
                      Text(threads.error.value),

                    if (!phoneActions(context))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.push('/inbox/new'),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(context.tr.newConversation),
                        ),
                      ),
                    ClassSections(
                      builder: (c) => LWatch(() {
                        final rows = threads.rows.value.where(
                          (r) => group(r) == c.id,
                        );
                        return Column(
                          children: [
                            if (rows.isEmpty)
                              ListTile(title: Text(context.tr.messagingEmpty)),
                            for (final row in rows) thread(row),
                          ],
                        );
                      }),
                    ),
                    if (tc.activeAssignment == null) ...[
                      if (threads.rows.value.any((r) => group(r) == null))
                        ExpansionTile(
                          title: Text(context.tr.noClassSpecified),
                          children: [
                            for (final row in threads.rows.value.where(
                              (r) => group(r) == null,
                            ))
                              thread(row),
                          ],
                        ),
                    ],
                    if (threads.rows.value.length < threads.total.value)
                      TextButton(
                        onPressed: () => threads.refresh(more: true),
                        child: Text(context.tr.showMore),
                      ),
                  ],
                ),
              ),
            ),
            RefreshIndicator(
              onRefresh: inbox.loadInbox,
              child: ListView(
                key: const PageStorageKey('teacher-notifications'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (inbox.loadingNotices.value)
                    const LinearProgressIndicator(),
                  if (inbox.errorMessage.value.isNotEmpty)
                    Text(inbox.errorMessage.value),

                  for (final m in inbox.deliveries.value.where(
                    (m) => m.eventKey != 'conversation.message',
                  ))
                    ListTile(
                      leading: Icon(
                        m.isUnread
                            ? Icons.mark_email_unread_outlined
                            : Icons.notifications_outlined,
                      ),
                      title: Text(
                        m.title,
                        style: TextStyle(
                          fontWeight: m.isUnread ? FontWeight.bold : null,
                        ),
                      ),
                      subtitle: Text(
                        m.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: date(m.sortDate),
                      onTap: () async {
                        await context.push(inboxMessagePath(m.id));
                        if (context.mounted) await inbox.refreshNotice(m.id);
                      },
                    ),
                  if (inbox.hasMore.value)
                    TextButton(
                      onPressed: inbox.loadingMore.value
                          ? null
                          : inbox.loadMore,
                      child: Text(context.tr.messagingLoadMore),
                    ),
                  if (!inbox.loadingNotices.value &&
                      inbox.errorMessage.value.isEmpty &&
                      !inbox.deliveries.value.any(
                        (m) => m.eventKey != 'conversation.message',
                      ))
                    ListTile(title: Text(context.tr.noSchoolNotices)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    final selectedId = GoRouterState.of(context).pathParameters['id'];

    final notifications = AdaptiveContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              context.tr.unreadCount(store.unreadCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(PrototypeSpacing.md),
              itemCount: store.messages.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: PrototypeSpacing.xs),
              itemBuilder: (context, i) {
                final m = store.messages[i];
                final selected = selectedId == m.id;
                return ListRow(
                  title: m.title,
                  subtitle: m.body.length > 80
                      ? '${m.body.substring(0, 80)}…'
                      : m.body,
                  unread: !m.read,
                  selected: selected,
                  badge: m.read
                      ? context.tr.inboxStatusRead
                      : context.tr.inboxStatusNew,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: m.read
                          ? const Color(0xFFF1F5F9)
                          : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.mail_outline,
                      size: 20,
                      color: m.read
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  onTap: () => context.go(inboxMessagePath(m.id)),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
    return WorkspaceTabs(
      values: const ['conversations', 'notifications'],
      labels: [
        context.tr.messagingConversations,
        context.tr.workspaceNotifications,
      ],
      children: [
        RefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [Text(context.tr.messagingEmpty)],
          ),
        ),
        notifications,
      ],
    );
  }
}

class MessageDetailPage extends StatelessWidget {
  const MessageDetailPage({super.key, required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveMessageDetailPage(messageId: messageId);
    }
    return _MockMessageDetailPage(messageId: messageId);
  }
}

class _LiveMessageDetailPage extends LScopedView<MessageDetailController> {
  const _LiveMessageDetailPage({required this.messageId});

  final String messageId;

  @override
  MessageDetailController onConfigScope(LevitScope scope) {
    InboxDelivery? initial;
    try {
      initial = scope.find<LiveInboxController>().deliveryById(messageId);
    } on Object {
      initial = null;
    }
    return scope.put(
      () => MessageDetailController(
        messageId: messageId,
        initialDelivery: initial,
        schoolClient: scope.find<SchoolClientFactory>(),
        onDeliveryUpdated: (updated) {
          try {
            scope.find<LiveInboxController>().applyDeliveryUpdate(updated);
          } on Object {
            // Inbox list may not be mounted.
          }
        },
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, MessageDetailController controller) {
    return LWatch(() {
      controller.delivery.value;
      controller.errorMessage.value;
      controller.isBusy.value;
      controller.isMarkingRead.value;
      if (controller.isBusy.value && controller.delivery.value == null) {
        return PrototypeDetailScaffold(
          fallbackRoute: '/inbox',
          title: context.tr.navInbox,
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      final message = controller.delivery.value;
      if (message == null) {
        return PrototypeDetailScaffold(
          fallbackRoute: '/inbox',
          title: context.tr.navInbox,
          body: EmptyState(
            title: controller.errorMessage.value.isEmpty
                ? context.tr.messageNotFound
                : controller.errorMessage.value,
          ),
        );
      }

      final sentAt = message.sortDate;
      return PrototypeDetailScaffold(
        fallbackRoute: '/inbox',
        title: context.tr.navInbox,
        body: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            if (controller.isMarkingRead.value) const LinearProgressIndicator(),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: PrototypeSpacing.sm),
                  if (sentAt != null)
                    StatusChip(
                      label: formatDate(sentAt),
                      tone: SemanticTone.neutral,
                    ),
                  const SizedBox(height: PrototypeSpacing.md),
                  Text(
                    message.body,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _MockMessageDetailPage extends LScopedView<StoreBoundController> {
  const _MockMessageDetailPage({required this.messageId});

  final String messageId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final message = store.messageById(messageId);
    if (message == null) {
      return PrototypeDetailScaffold(
        title: context.tr.navInbox,
        body: EmptyState(title: context.tr.messageNotFound),
      );
    }

    if (!message.read) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        store.markRead(messageId);
      });
    }

    return PrototypeDetailScaffold(
      title: message.title,
      fallbackRoute: '/inbox',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          Text(
            formatDateTime(message.sentAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: PrototypeSpacing.md),
          SurfaceCard(
            child: Text(
              message.body,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
