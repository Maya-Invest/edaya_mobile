import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import 'message_detail_controller.dart';

class MessageDetailPage extends LScopedView<MessageDetailController> {
  const MessageDetailPage({super.key, required this.messageId});

  final String messageId;

  @override
  MessageDetailController onConfigScope(LevitScope scope) {
    return scope.put(
      () => MessageDetailController(
        scope.find<MockStore>(),
        messageId: messageId,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, MessageDetailController controller) {
        controller.storeTick.value;
    final store = controller.store;
    final embedded = PrototypeBreakpoints.detailDrawerActive(context);
    final message = store.messageById(controller.messageId);
    if (message == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/inbox',
        title: 'Message',
        embedded: embedded,
        body: const EmptyState(title: 'Message introuvable'),
      );
    }
    return PrototypeDetailScaffold(
      fallbackRoute: '/inbox',
      title: 'Message',
      embedded: embedded,
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
