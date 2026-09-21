import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/store_bound_controller.dart';
import 'inbox_controller.dart';
import 'message_detail_controller.dart';
import 'models/inbox_delivery.dart';

class MessageDetailPage extends StatelessWidget {
  const MessageDetailPage({
    super.key,
    required this.messageId,
    this.initialDelivery,
  });

  final String messageId;
  final InboxDelivery? initialDelivery;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveMessageDetailPage(
        messageId: messageId,
        initialDelivery: initialDelivery,
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
    final message = controller.store.messageById(messageId);
    if (message == null) {
      return const PrototypeDetailScaffold(
        fallbackRoute: '/inbox',
        title: 'Message',
        body: EmptyState(title: 'Message introuvable'),
      );
    }
    return PrototypeDetailScaffold(
      fallbackRoute: '/inbox',
      title: 'Message',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                StatusChip(
                  label: formatDate(message.sentAt),
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
  }
}

class _LiveMessageDetailPage extends LScopedView<MessageDetailController> {
  const _LiveMessageDetailPage({
    required this.messageId,
    this.initialDelivery,
  });

  final String messageId;
  final InboxDelivery? initialDelivery;

  @override
  MessageDetailController onConfigScope(LevitScope scope) {
    return scope.put(
      () => MessageDetailController(
        messageId: messageId,
        initialDelivery: initialDelivery,
        schoolClient: scope.find<SchoolClientFactory>(),
        onDeliveryUpdated: (updated) {
          try {
            scope.find<InboxController>().applyDeliveryUpdate(updated);
          } on Object {
            // Inbox list may not be mounted.
          }
        },
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, MessageDetailController controller) {
    if (controller.isBusy.value && controller.delivery.value == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/inbox',
        title: 'Message',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final message = controller.delivery.value;
    if (message == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/inbox',
        title: 'Message',
        body: EmptyState(
          title: controller.errorMessage.value.isEmpty
              ? 'Message introuvable'
              : controller.errorMessage.value,
        ),
      );
    }

    final sentAt = message.sortDate;

    return PrototypeDetailScaffold(
      fallbackRoute: '/inbox',
      title: 'Message',
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
  }
}
