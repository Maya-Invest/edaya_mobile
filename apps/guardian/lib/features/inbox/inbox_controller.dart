import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import '../../common/utils/entity_filters.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'models/inbox_delivery.dart';

class InboxController extends LevitController with LevitReactiveTasksMixin {
  InboxController({required AppSessionController session}) : _session = session;

  final AppSessionController _session;

  final deliveries = LxVar<List<InboxDelivery>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(deliveries);
    autoDispose(errorMessage);

    autoDispose(_session.user.stream.listen((_) => unawaited(loadInbox())));

    unawaited(loadInbox());
  }

  DataStatus get dataStatus {
    if (isBusy.value && deliveries.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && deliveries.value.isEmpty) {
      return DataStatus.error;
    }
    return DataStatus.ready;
  }

  String get emptyMessage => 'No messages in your inbox yet.';

  int get unreadCount =>
      deliveries.value.where((delivery) => delivery.isUnread).length;

  void applyDeliveryUpdate(InboxDelivery updated) {
    deliveries(
      deliveries.value
          .map((delivery) => delivery.id == updated.id ? updated : delivery)
          .toList(),
    );
  }

  Future<void> loadInbox() async {
    final subjectId = _session.user.value?.id;
    if (subjectId == null) {
      deliveries(const []);
      errorMessage('');
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final rows = await AppRuntime.schoolClient().messageDeliveries.list(
          deliveriesForSubject(subjectId),
        );
        final parsed = rows.map(InboxDelivery.fromJson).toList()
          ..sort((a, b) {
            final aTime = a.sortDate?.millisecondsSinceEpoch ?? 0;
            final bTime = b.sortDate?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });
        deliveries(parsed);
      } on api.ApiError catch (error) {
        errorMessage('Could not load inbox: $error');
        deliveries(const []);
      } on Object catch (error) {
        errorMessage('Could not load inbox: $error');
        deliveries(const []);
      }
    });
  }
}
