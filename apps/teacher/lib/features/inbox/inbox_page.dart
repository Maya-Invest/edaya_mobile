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
      controller.isBusy.value;
      final selectedId = GoRouterState.of(context).pathParameters['id'];
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
      final deliveries = controller.deliveries.value;
      if (deliveries.isEmpty) {
        return AdaptiveContent(
          child: EmptyState(title: controller.emptyMessage),
        );
      }
      return AdaptiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                context.tr.unreadCount(controller.unreadCount),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(PrototypeSpacing.md),
                itemCount: deliveries.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: PrototypeSpacing.xs),
                itemBuilder: (context, i) {
                  final m = deliveries[i];
                  final selected = selectedId == m.id;
                  return ListRow(
                    title: m.title,
                    subtitle: m.body.length > 80
                        ? '${m.body.substring(0, 80)}…'
                        : m.body,
                    unread: m.isUnread,
                    selected: selected,
                    badge: m.status.label(context.tr),
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
                    onTap: () => context.go(inboxMessagePath(m.id)),
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
    });
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

    return AdaptiveContent(
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
                  badge: m.read ? context.tr.inboxStatusRead : context.tr.inboxStatusNew,
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
                  onTap: () => context.go(inboxMessagePath(m.id)),
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
                ? context.tr.missingMessageDetailsRouteData
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
            if (controller.isMarkingRead.value)
              const LinearProgressIndicator(),
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
        body: EmptyState(title: context.tr.missingMessageDetailsRouteData),
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
