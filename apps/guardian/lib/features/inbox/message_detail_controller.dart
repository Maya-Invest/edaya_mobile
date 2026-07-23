import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'models/inbox_delivery.dart';

class MessageDetailController extends LevitController
    with LevitReactiveTasksMixin {
  MessageDetailController({
    required this.messageId,
    required SchoolClientFactory schoolClient,
    this.onDeliveryUpdated,
  }) : _schoolClient = schoolClient;

  final String messageId;
  final SchoolClientFactory _schoolClient;
  final void Function(InboxDelivery updated)? onDeliveryUpdated;

  final delivery = LxVar<InboxDelivery?>(null);
  final isMarkingRead = LxVar(false);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(delivery);
    autoDispose(isMarkingRead);
    autoDispose(errorMessage);
    unawaited(loadAndMarkRead());
  }

  Future<void> loadAndMarkRead() async {
    await runTask(() async {
      try {
        final client = _schoolClient();
        final row = await client.messageDeliveries.get(messageId);
        var parsed = InboxDelivery.fromJson(row);
        delivery(parsed);

        if (parsed.isUnread) {
          isMarkingRead(true);
          try {
            final result = await client.markDeliveryRead({
              'deliveryId': parsed.id,
            });
            parsed = InboxDelivery.fromJson(result);
            delivery(parsed);
            onDeliveryUpdated?.call(parsed);
          } on api.ApiError catch (error) {
            errorMessage(
              systemL10n().couldNotMarkMessageRead(error.toString()),
            );
          } on Object catch (error) {
            errorMessage(
              systemL10n().couldNotMarkMessageRead(error.toString()),
            );
          } finally {
            isMarkingRead(false);
          }
        }
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadInbox(error.toString()));
        delivery(null);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadInbox(error.toString()));
        delivery(null);
      }
    }, id: 'load-message-detail');
  }
}
