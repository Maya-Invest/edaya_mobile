import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'inbox_controller.dart';
import 'models/inbox_delivery.dart';
import 'widgets/inbox_delivery_tile.dart';

class InboxPage extends LScopedView<InboxController> {
  const InboxPage({super.key});

  @override
  InboxController onConfigScope(LevitScope scope) {
    return scope.put(
      () => InboxController(
        session: scope.find<AppSessionController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, InboxController controller) {
    return LWatch(
      () {
        final status = controller.dataStatus;

        return DataState(
          status: status,
          errorMessage: controller.errorMessage.value,
          emptyMessage: controller.emptyMessage,
          onRetry: controller.loadInbox,
          child: RefreshIndicator(
            onRefresh: controller.loadInbox,
            child: _InboxBody(controller: controller),
          ),
        );
      },
    );
  }
}

class _InboxBody extends StatelessWidget {
  const _InboxBody({required this.controller});

  final InboxController controller;

  @override
  Widget build(BuildContext context) {
    final deliveries = controller.deliveries.value;
    final unreadCount = controller.unreadCount;

    if (deliveries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 48),
          Center(child: Text(controller.emptyMessage)),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (unreadCount > 0) ...[
          Text(
            context.tr.unreadCount(unreadCount),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
        ],
        for (final delivery in deliveries) ...[
          InboxDeliveryTile(
            delivery: delivery,
            onTap: () => _openMessageDetails(context, delivery),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Future<void> _openMessageDetails(
    BuildContext context,
    InboxDelivery delivery,
  ) async {
    final updated = await context.push<InboxDelivery>(
      '/inbox/message',
      extra: delivery,
    );
    if (updated != null) {
      controller.applyDeliveryUpdate(updated);
    }
  }
}
