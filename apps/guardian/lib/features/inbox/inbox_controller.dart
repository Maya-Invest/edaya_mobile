import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../../common/utils/entity_filters.dart';
import '../context/student_context_controller.dart';
import 'models/inbox_delivery.dart';

class InboxController extends LevitController with LevitReactiveTasksMixin {
  InboxController({
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
    required StudentContextController studentContext,
  }) : _session = session,
       _schoolClient = schoolClient,
       _studentContext = studentContext;

  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;
  final StudentContextController _studentContext;

  final deliveries = LxVar<List<InboxDelivery>>(const []);
  final campaigns = LxVar<List<GuardianFamilyFeedbackCampaign>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(deliveries);
    autoDispose(campaigns);
    autoDispose(errorMessage);

    autoDispose(_session.user.stream.listen((_) => unawaited(loadInbox())));
    autoDispose(
      _studentContext.activeStudent.stream.listen((_) => unawaited(loadInbox())),
    );

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

  String get emptyMessage => systemL10n().noMessagesInInbox;

  int get unreadCount =>
      deliveries.value.where((delivery) => delivery.isUnread).length;

  int get openCampaignCount =>
      campaigns.value.where((item) => item.slotState == 'open').length;

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
        final rows = await _schoolClient().messageDeliveries.list(
          deliveriesForSubject(subjectId),
        );
        final parsed = rows.map(InboxDelivery.fromJson).toList()
          ..sort((a, b) {
            final aTime = a.sortDate?.millisecondsSinceEpoch ?? 0;
            final bTime = b.sortDate?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });
        deliveries(parsed);
        try {
          final items = await listGuardianFamilyFeedbackCampaigns(
            _schoolClient(),
          );
          final studentId = _studentContext.activeStudentId;
          campaigns(
            studentId == null
                ? items
                : items.where((item) => item.studentId == studentId).toList(),
          );
        } on Object {
          campaigns(const []);
        }
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadInbox(error.toString()));
        deliveries(const []);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadInbox(error.toString()));
        deliveries(const []);
      }
    });
  }
}
