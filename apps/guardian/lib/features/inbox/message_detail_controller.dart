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
    this.initialDelivery,
    this.onDeliveryUpdated,
  }) : _schoolClient = schoolClient;

  final String messageId;
  final SchoolClientFactory _schoolClient;
  final InboxDelivery? initialDelivery;
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
    if (initialDelivery != null && initialDelivery!.id == messageId) {
      delivery(initialDelivery);
    }
    unawaited(loadAndMarkRead());
  }

  Future<void> loadAndMarkRead() async {
    await runTask(() async {
      try {
        final client = _schoolClient();
        var parsed = delivery.value;
        if (parsed == null) {
          // POST /one keeps `:` / `%3A` in the JSON body. GET /:id decodes
          // `%3A` in the path and 404s for notification delivery ids.
          final row = await client.messageDeliveries.one({'id': messageId});
          parsed = InboxDelivery.fromJson(row);
          delivery(parsed);
        }

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
        if (delivery.value == null) delivery(null);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadInbox(error.toString()));
        if (delivery.value == null) delivery(null);
      }
    }, id: 'load-message-detail');
  }
}
