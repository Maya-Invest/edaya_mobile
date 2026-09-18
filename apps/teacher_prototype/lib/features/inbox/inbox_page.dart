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

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const AdaptiveContent(
        child: EmptyState(
          title: 'Aucun message',
          message: 'La messagerie live n\'est pas encore branchée.',
        ),
      );
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
    final selectedId = GoRouterState.of(context).pathParameters['id'];

    return AdaptiveContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '${store.unreadCount} non lu(s)',
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
                  badge: m.read ? 'Lu · ${formatDate(m.sentAt)}' : 'Nouveau',
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
                  onTap: () => context.go('/inbox/message/${m.id}'),
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
      return const PrototypeDetailScaffold(
        title: 'Message',
        fallbackRoute: '/inbox',
        body: EmptyState(title: 'Message introuvable'),
      );
    }
    return _MockMessageDetailPage(messageId: messageId);
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
      return const PrototypeDetailScaffold(
        title: 'Message',
        body: EmptyState(title: 'Message introuvable'),
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
