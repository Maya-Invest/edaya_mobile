import 'dart:async';
import 'dart:math' as math;
import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';
import '../../access/school_client.dart';
import '../../common/widgets/data_state.dart';
import '../../l10n/l10n_lookup.dart';
import '../auth/app_session_controller.dart';
import 'inbox_delivery.dart';
import 'messaging_events.dart';

typedef _Recipient = ({
  String school,
  String kind,
  String actor,
  String account,
});

/// Owns the currently signed-in recipient's notice pages and the two unread counts.
class RecipientInboxController extends LevitController
    with LevitReactiveTasksMixin {
  RecipientInboxController({
    required this.session,
    required this.schoolClient,
    required this.kind,
  });
  final AppSessionController session;
  final SchoolClientFactory schoolClient;
  final String kind;
  final deliveries = LxVar<List<InboxDelivery>>(const []);
  final conversationUnread = LxVar(0);
  final _noticeUnread = LxVar(0);
  final loadingNotices = LxVar(false);
  final loadingMore = LxVar(false);
  final hasMore = LxVar(false);
  final errorMessage = LxVar('');
  String? _cursor;
  int _pageGeneration = 0, _countGeneration = 0;
  _Recipient? _loaded;
  bool _closed = false;

  _Recipient? get _recipient {
    final user = session.user.value;
    final grants = session.grants.value;
    if (user == null || grants == null || grants.kind != kind) return null;
    return (
      school: grants.schoolId,
      kind: kind,
      actor: grants.actorId,
      account: user.id,
    );
  }

  bool get hasRecipient => !_closed && _recipient != null;
  Stream<int> get noticeUnreadChanges => _noticeUnread.stream;
  int get unreadCount => _noticeUnread.value + conversationUnread.value;
  DataStatus get dataStatus {
    if (deliveries.value.isEmpty && loadingNotices.value)
      return DataStatus.loading;
    if (deliveries.value.isEmpty && errorMessage.value.isNotEmpty)
      return DataStatus.error;
    return DataStatus.ready;
  }

  @override
  void onInit() {
    super.onInit();
    autoDispose(deliveries);
    autoDispose(conversationUnread);
    autoDispose(_noticeUnread);
    autoDispose(loadingNotices);
    autoDispose(loadingMore);
    autoDispose(hasMore);
    autoDispose(errorMessage);
    autoDispose(
      conversationCountsChanged.stream.listen((_) {
        final recipient = _recipient;
        if (recipient != null) unawaited(_readCount(recipient, schoolClient()));
      }),
    );
    autoDispose(
      messagingRefreshEvents.stream.listen((_) => unawaited(loadInbox())),
    );
    autoDispose(session.user.stream.listen((_) => unawaited(loadInbox())));
    autoDispose(session.grants.stream.listen((_) => unawaited(loadInbox())));
    unawaited(loadInbox());
  }

  /// Guardian overrides this to load feedback independently of the delivery history.
  Future<void> refreshRelated() async {}

  Future<void> loadInbox() async {
    if (_closed) return;
    final recipient = _recipient;
    if (recipient != _loaded || recipient == null) {
      _loaded = recipient;
      _pageGeneration++;
      _countGeneration++;
      deliveries(const []);
      _noticeUnread(0);
      conversationUnread(0);
      _cursor = null;
      hasMore(false);
      loadingMore(false);
      loadingNotices(false);
      errorMessage('');
    }
    if (recipient == null) return refreshRelated();
    final client = schoolClient();
    await Future.wait([
      _readPage(recipient, client),
      _readCount(recipient, client),
      refreshRelated(),
    ]);
  }

  Future<void> _readCount(_Recipient recipient, api.SchoolClient client) async {
    final generation = ++_countGeneration;
    bool current() =>
        !_closed && _recipient == recipient && generation == _countGeneration;
    try {
      int count;
      try {
        count = (await client.getUnreadConversationCount({}))['count'] as int;
      } on api.ApiError catch (e) {
        if (e.status != 404 && e.status != 405) rethrow;
        if (!current()) return;
        count =
            (await client.runQuery('list-conversations', {
                  'limit': 1,
                }))['unreadCount']
                as int;
      }
      if (current()) conversationUnread(count);
    } catch (_) {
      if (current()) conversationUnread(0);
    }
  }

  Future<void> loadMore() async {
    final recipient = _recipient;
    if (recipient == null ||
        recipient != _loaded ||
        _cursor == null ||
        loadingNotices.value ||
        loadingMore.value)
      return;
    await _readPage(recipient, schoolClient(), cursor: _cursor);
  }

  Future<void> _readPage(
    _Recipient recipient,
    api.SchoolClient client, {
    String? cursor,
  }) async {
    final generation = ++_pageGeneration;
    bool current() =>
        !_closed && _recipient == recipient && generation == _pageGeneration;
    loadingNotices(cursor == null);
    loadingMore(cursor != null);
    errorMessage('');
    try {
      List<InboxDelivery> items;
      int unread;
      String? next;
      try {
        final page = await client.getDeliveryInbox({
          if (cursor != null) 'cursor': cursor,
        });
        items = (page['items'] as List)
            .map(
              (row) => InboxDelivery.fromPreview(
                Map<String, dynamic>.from(row as Map),
                recipient.account,
              ),
            )
            .toList();
        unread = page['unreadCount'] as int;
        next = page['nextCursor'] as String?;
      } on api.ApiError catch (e) {
        if (cursor != null || (e.status != 404 && e.status != 405)) rethrow;
        if (!current()) return;
        final rows = await client.messageDeliveries.listAll({
          'subjectId': recipient.account,
          'recipientKind': kind,
          'recipientId': recipient.actor,
          'schoolId': recipient.school,
        });
        items =
            rows
                .where((row) => row['eventKey'] != 'conversation.message')
                .map(InboxDelivery.fromJson)
                .toList()
              ..sort((a, b) {
                final time = (b.sortDate?.microsecondsSinceEpoch ?? 0)
                    .compareTo(a.sortDate?.microsecondsSinceEpoch ?? 0);
                return time != 0 ? time : b.id.compareTo(a.id);
              });
        unread = items.where((item) => item.isUnread).length;
      }
      if (!current()) return;
      deliveries(
        cursor == null
            ? items
            : {
                for (final item in [...deliveries.value, ...items])
                  item.id: item,
              }.values.toList(),
      );
      _noticeUnread(unread);
      _cursor = next;
      hasMore(next != null);
    } catch (error) {
      if (!current()) return;
      errorMessage(systemL10n().couldNotLoadInbox(error.toString()));
      if (error is api.ApiError &&
          (error.status == 401 || error.status == 403)) {
        deliveries(const []);
        _noticeUnread(0);
        _cursor = null;
        hasMore(false);
      }
    } finally {
      if (current()) {
        loadingNotices(false);
        loadingMore(false);
      }
    }
  }

  InboxDelivery? deliveryById(String id) =>
      deliveries.value.where((item) => item.id == id).firstOrNull;

  /// Reconcile a notice after a detail route with a separate controller scope closes.
  Future<void> refreshNotice(String id) async {
    final recipient = _recipient;
    if (recipient == null ||
        recipient != _loaded ||
        deliveryById(id)?.isUnread != true)
      return;
    try {
      final row = await schoolClient().messageDeliveries.one({'id': id});
      if (!_closed && _recipient == recipient)
        applyDeliveryUpdate(InboxDelivery.fromJson(row));
    } catch (_) {
      if (!_closed && _recipient == recipient)
        await _readPage(recipient, schoolClient());
    }
  }

  void applyDeliveryUpdate(InboxDelivery updated) {
    final recipient = _recipient;
    if (recipient == null ||
        recipient != _loaded ||
        updated.subjectId != recipient.account)
      return;
    final previous = deliveryById(updated.id);
    if (previous == null || loadingNotices.value || loadingMore.value) {
      unawaited(_readPage(recipient, schoolClient()));
      return;
    }
    if (previous.isUnread != updated.isUnread) {
      _noticeUnread(
        math.max(0, _noticeUnread.value + (updated.isUnread ? 1 : -1)),
      );
    }
    deliveries([
      for (final item in deliveries.value)
        if (item.id == updated.id) updated else item,
    ]);
  }

  @override
  void onClose() {
    _closed = true;
    super.onClose();
  }
}
