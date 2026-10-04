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

  int _generation = 0;

  final conversationUnread = LxVar(0);
  final deliveries = LxVar<List<InboxDelivery>>(const []);
  final campaigns = LxVar<List<GuardianFamilyFeedbackCampaign>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(conversationUnread);
    autoDispose(
      conversationCountsChanged.stream.listen((_) => unawaited(loadInbox())),
    );
    autoDispose(
      messagingRefreshEvents.stream.listen((_) => unawaited(loadInbox())),
    );
    autoDispose(deliveries);
    autoDispose(campaigns);
    autoDispose(errorMessage);

    autoDispose(_session.user.stream.listen((_) => unawaited(loadInbox())));
    autoDispose(_session.grants.stream.listen((_) => unawaited(loadInbox())));
    autoDispose(
      _studentContext.activeStudent.stream.listen(
        (_) => unawaited(loadInbox()),
      ),
    );

    unawaited(loadInbox());
  }

  @override
  void onClose() { _generation++; super.onClose(); }

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
      deliveries.value
          .where(
            (delivery) =>
                delivery.isUnread &&
                delivery.eventKey != 'conversation.message',
          )
          .length +
      conversationUnread.value;

  int get openCampaignCount =>
      campaigns.value.where((item) => item.slotState == 'open').length;

  void applyDeliveryUpdate(InboxDelivery updated) {
    deliveries(
      deliveries.value
          .map((delivery) => delivery.id == updated.id ? updated : delivery)
          .toList(),
    );
  }

  String? _inboxKey() {
    final subjectId = _session.user.value?.id;
    final grants = _session.grants.value;
    if (subjectId == null || grants == null || grants.kind != 'guardian') {
      return null;
    }
    return '$subjectId|${grants.kind}|${grants.actorId}|${grants.schoolId}';
  }

  Future<void> loadInbox() async {
    final generation = ++_generation;
    final key = _inboxKey();
    if (key == null) {
      conversationUnread(0);
      deliveries(const []);
      campaigns(const []);
      errorMessage('');
      return;
    }
    final grants = _session.grants.value!;
    final subjectId = _session.user.value!.id;

    errorMessage('');
    final rowsFuture = _schoolClient().messageDeliveries.listAll(
      deliveriesForGuardian(
        subjectId: subjectId,
        guardianId: grants.actorId,
        schoolId: grants.schoolId,
      ),
    );
    if (generation != _generation || key != _inboxKey()) {
      return;
    }
    try {
      final rows = await rowsFuture;
      if (generation != _generation || key != _inboxKey()) {
        return;
      }
      final parsed = rows.map(InboxDelivery.fromJson).toList()
        ..sort((a, b) {
          final aTime = a.sortDate?.millisecondsSinceEpoch ?? 0;
          final bTime = b.sortDate?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });
      deliveries(parsed);
      try {
        final page = await _schoolClient().runQuery('list-conversations', {
          'limit': 1,
        });
        if (generation == _generation && key == _inboxKey()) {
          conversationUnread((page['unreadCount'] as num).toInt());
        }
      } on Object {
        if (generation == _generation && key == _inboxKey()) {
          conversationUnread(0);
        }
      }
      try {
        final items = await listGuardianFamilyFeedbackCampaigns(
          _schoolClient(),
        );
        if (generation != _generation || key != _inboxKey()) {
          return;
        }
        final studentId = _studentContext.activeStudentId;
        campaigns(
          studentId == null
              ? items
              : items.where((item) => item.studentId == studentId).toList(),
        );
      } on Object {
        if (generation == _generation && key == _inboxKey()) {
          campaigns(const []);
        }
      }
    } on api.ApiError catch (error) {
      if (generation != _generation || key != _inboxKey()) {
        return;
      }
      errorMessage(systemL10n().couldNotLoadInbox(error.toString()));
      deliveries(const []);
      campaigns(const []);
    } on Object catch (error) {
      if (generation != _generation || key != _inboxKey()) {
        return;
      }
      errorMessage(systemL10n().couldNotLoadInbox(error.toString()));
      deliveries(const []);
      campaigns(const []);
    }
  }
}
