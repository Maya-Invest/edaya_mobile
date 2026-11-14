import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../live/entity_queries.dart';
import 'inbox_delivery.dart';

class LiveInboxController extends LevitController with LevitReactiveTasksMixin {
  LiveInboxController({
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
  }) : _session = session,
       _schoolClient = schoolClient;

  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;

  int _generation = 0;
  String? _loadedKey;
  bool _closed = false;

  final conversationUnread = LxVar(0);
  final deliveries = LxVar<List<InboxDelivery>>(const []);
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
    autoDispose(errorMessage);
    autoDispose(_session.user.stream.listen((_) => unawaited(loadInbox())));
    autoDispose(_session.grants.stream.listen((_) => unawaited(loadInbox())));
    unawaited(loadInbox());
  }

  @override
  void onClose() {
    _closed = true;
    _generation++;
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
      deliveries.value
          .where(
            (delivery) =>
                delivery.isUnread &&
                delivery.eventKey != 'conversation.message',
          )
          .length +
      conversationUnread.value;

  InboxDelivery? deliveryById(String id) {
    for (final delivery in deliveries.value) {
      if (delivery.id == id) {
        return delivery;
      }
    }
    return null;
  }

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
    if (subjectId == null || grants == null || grants.kind != 'teacher') {
      return null;
    }
    return '$subjectId|${grants.kind}|${grants.actorId}|${grants.schoolId}';
  }

  Future<void> loadInbox() async {
    if (_closed) {
      return;
    }
    final generation = ++_generation;
    final key = _inboxKey();
    if (key != _loadedKey) {
      _loadedKey = key;
      conversationUnread(0);
      deliveries(const []);
    }
    if (key == null) {
      if (_closed) {
        return;
      }
      conversationUnread(0);
      deliveries(const []);
      errorMessage('');
      return;
    }
    final grants = _session.grants.value!;
    final subjectId = _session.user.value!.id;

    errorMessage('');
    final rowsFuture = _schoolClient().messageDeliveries.listAll(
      deliveriesForTeacher(
        subjectId: subjectId,
        teacherId: grants.actorId,
        schoolId: grants.schoolId,
      ),
    );
    if (generation != _generation || key != _inboxKey()) {
      return;
    }
    try {
      final rows = await rowsFuture;
      if (_closed || generation != _generation || key != _inboxKey()) {
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
    } on api.ApiError catch (error) {
      if (_closed || generation != _generation || key != _inboxKey()) {
        return;
      }
      errorMessage(systemL10n().couldNotLoadInbox(error.toString()));
      deliveries(const []);
    } on Object catch (error) {
      if (_closed || generation != _generation || key != _inboxKey()) {
        return;
      }
      errorMessage(systemL10n().couldNotLoadInbox(error.toString()));
      deliveries(const []);
    }
  }
}
