import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../../common/utils/entity_filters.dart';
import 'models/inbox_delivery.dart';

class InboxController extends LevitController with LevitReactiveTasksMixin {
  InboxController({
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
  }) : _session = session,
       _schoolClient = schoolClient;

  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;

  final deliveries = LxVar<List<InboxDelivery>>(const []);
  final errorMessage = LxVar('');
  int _loadVersion = 0;

  ({String subjectId, String guardianId, String schoolId})? get _recipient {
    final subjectId = _session.user.value?.id;
    final profile = _session.grants.value;
    if (subjectId == null ||
        subjectId.isEmpty ||
        profile == null ||
        profile.kind != 'guardian' ||
        profile.actorId.isEmpty ||
        profile.schoolId.isEmpty) {
      return null;
    }
    return (
      subjectId: subjectId,
      guardianId: profile.actorId,
      schoolId: profile.schoolId,
    );
  }

  @override
  void onInit() {
    super.onInit();
    autoDispose(deliveries);
    autoDispose(errorMessage);

    autoDispose(_session.user.stream.listen((_) => unawaited(loadInbox())));
    autoDispose(_session.grants.stream.listen((_) => unawaited(loadInbox())));

    unawaited(loadInbox());
  }

  @override
  void onClose() {
    _loadVersion++;
    super.onClose();
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

  String get emptyMessage => systemL10n().noMessagesInInbox;

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
    final version = ++_loadVersion;
    final recipient = _recipient;
    deliveries(const []);
    if (recipient == null) {
      errorMessage('');
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final rows = await _schoolClient().messageDeliveries.list(
          deliveriesForGuardian(
            subjectId: recipient.subjectId,
            guardianId: recipient.guardianId,
            schoolId: recipient.schoolId,
          ),
        );
        if (version != _loadVersion || recipient != _recipient) return;
        final parsed = rows.map(InboxDelivery.fromJson).toList()
          ..sort((a, b) {
            final aTime = a.sortDate?.millisecondsSinceEpoch ?? 0;
            final bTime = b.sortDate?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });
        deliveries(parsed);
      } on api.ApiError catch (error) {
        if (version != _loadVersion || recipient != _recipient) return;
        errorMessage(systemL10n().couldNotLoadInbox(error.toString()));
        deliveries(const []);
      } on Object catch (error) {
        if (version != _loadVersion || recipient != _recipient) return;
        errorMessage(systemL10n().couldNotLoadInbox(error.toString()));
        deliveries(const []);
      }
    });
  }
}
