import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import '../../common/utils/date_time_parse.dart';
import 'models/inbox_delivery.dart';

class MessageDetailsController extends LevitController
    with LevitReactiveTasksMixin {
  MessageDetailsController({required InboxDelivery delivery})
    : delivery = LxVar(delivery);

  final LxVar<InboxDelivery> delivery;
  final isMarkingRead = LxVar(false);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(delivery);
    autoDispose(isMarkingRead);
    autoDispose(errorMessage);
    unawaited(markAsReadIfNeeded());
  }

  Future<void> markAsReadIfNeeded() async {
    if (!delivery.value.isUnread || isMarkingRead.value) {
      return;
    }

    isMarkingRead(true);
    errorMessage('');
    try {
      final result = await AppRuntime.schoolClient().markDeliveryRead({
        'deliveryId': delivery.value.id,
      });
      delivery(InboxDelivery.fromJson(result));
    } on api.ApiError catch (error) {
      errorMessage('Could not mark message as read: $error');
    } on Object catch (error) {
      errorMessage('Could not mark message as read: $error');
    } finally {
      isMarkingRead(false);
    }
  }
}

class MessageDetailsDialog extends LScopedView<MessageDetailsController> {
  const MessageDetailsDialog({super.key, required this.initialDelivery});

  final InboxDelivery initialDelivery;

  @override
  MessageDetailsController onConfigScope(LevitScope scope) {
    return scope.put(
      () => MessageDetailsController(delivery: initialDelivery),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    MessageDetailsController controller,
  ) {
    return LWatch(
      () {
        final delivery = controller.delivery.value;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Message',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.pop(controller.delivery.value),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  delivery.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    delivery.status.label,
                    if (delivery.sortDate != null)
                      formatLongDate(delivery.sortDate!),
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (controller.isMarkingRead.value) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (controller.errorMessage.value.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    controller.errorMessage.value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(delivery.body),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
