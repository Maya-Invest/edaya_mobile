import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import 'inbox_controller.dart';
import 'message_detail_controller.dart';

class MessageDetailPage extends LScopedView<MessageDetailController> {
  const MessageDetailPage({super.key, required this.messageId});

  final String messageId;

  @override
  MessageDetailController onConfigScope(LevitScope scope) {
    return scope.put(
      () => MessageDetailController(
        messageId: messageId,
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
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);

    if (controller.isBusy.value && controller.delivery.value == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/inbox',
        title: 'Message',
        embedded: embedded,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final message = controller.delivery.value;
    if (message == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/inbox',
        title: 'Message',
        embedded: embedded,
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
      embedded: embedded,
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
  }
}
