import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';
import '../auth/app_session_controller.dart';
import '../../access/school_client.dart';
import 'messaging_events.dart';

String messagingRequestId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class ConversationController extends LevitController {
  ConversationController({
    required this.session,
    required this.client,
    this.conversationId,
  });
  final AppSessionController session;
  final SchoolClientFactory client;
  final String? conversationId;
  final rows = LxVar<List<Map<String, dynamic>>>(const []);
  final detail = LxVar<Map<String, dynamic>?>(null);
  final error = LxVar('');
  final busy = LxVar(false);
  final sending = LxVar(false);
  final unreadCount = LxVar(0);
  final total = LxVar(0);
  final identity = LxVar('');
  bool visible = true;
  bool foreground = true;
  bool _closed = false;
  int _generation = 0;
  Timer? _timer;
  String? _retryDigest;
  String? _retryId;
  String get sessionKey {
    final grants = session.grants.value;
    return '${session.user.value?.id}|${grants?.schoolId}|${grants?.kind}|${grants?.actorId}';
  }

  @override
  void onInit() {
    super.onInit();
    autoDispose(rows);
    autoDispose(detail);
    autoDispose(error);
    autoDispose(busy);
    autoDispose(sending);
    autoDispose(unreadCount);
    autoDispose(total);
    autoDispose(identity);
    identity(sessionKey);
    void changed() {
      if (identity.value != sessionKey) {
        _generation++;
        busy(false);
        sending(false);
        rows(const []);
        detail(null);
        unreadCount(0);
        total(0);
        error('');
        identity(sessionKey);
        _retryDigest = null;
        _retryId = null;
        unawaited(refresh());
      }
    }

    autoDispose(session.grants.stream.listen((_) => changed()));
    autoDispose(session.user.stream.listen((_) => changed()));
    autoDispose(
      messagingRefreshEvents.stream.listen((_) {
        if (visible && foreground) unawaited(refresh());
      }),
    );
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (visible && foreground) unawaited(refresh());
    });
    unawaited(refresh());
  }

  @override
  void onClose() {
    _closed = true;
    _generation++;
    _timer?.cancel();
    super.onClose();
  }

  Future<void> refresh({bool more = false}) async {
    if (_closed || session.grants.value == null || (busy.value && !more)) {
      return;
    }
    final key = sessionKey;
    final generation = ++_generation;
    busy(true);
    try {
      final id = conversationId;
      if (id == null) {
        final response = await client().runQuery('list-conversations', {
          'offset': more ? rows.value.length : 0,
          'limit': more ? 25 : min(100, max(25, rows.value.length)),
        });
        if (_closed || key != sessionKey || generation != _generation) return;
        final items = (response['items'] as List)
            .cast<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        rows(more ? [...rows.value, ...items] : items);
        unreadCount((response['unreadCount'] as num).toInt());
        total((response['total'] as num).toInt());
      } else {
        final existingMessages = detail.value?['messages'] as List?;
        final before =
            more && existingMessages != null && existingMessages.isNotEmpty
            ? (existingMessages.first as Map)['sequence']
            : null;
        final response = await client().runQuery('get-conversation', {
          'conversationId': id,
          'beforeSequence': ?before,
          'limit': 50,
        });
        if (_closed || key != sessionKey || generation != _generation) return;
        if (more) {
          response['messages'] = [
            ...response['messages'] as List,
            ...?detail.value?['messages'] as List?,
          ];
        }
        if (!more && existingMessages != null && existingMessages.isNotEmpty) {
          final fresh = response['messages'] as List;
          if (fresh.isNotEmpty) {
            final firstSequence = (fresh.first as Map)['sequence'] as num;
            final retained = existingMessages
                .where((m) => (m['sequence'] as num) < firstSequence)
                .toList();
            if (retained.isNotEmpty) {
              response['messages'] = [...retained, ...fresh];
              response['hasMore'] = detail.value?['hasMore'] ?? false;
            }
          }
        }
        detail(response);
        final messages = response['messages'] as List;
        if (messages.isNotEmpty) {
          await client().runCommand('mark-conversation-read', {
            'conversationId': id,
            'throughSequence': (messages.last as Map)['sequence'],
          });
          if ((response['conversation'] as Map)['unread'] == true) {
            conversationCountsChanged.add(null);
          }
        }
      }
      if (!_closed && key == sessionKey && generation == _generation) error('');
    } catch (e) {
      if (!_closed && key == sessionKey && generation == _generation) {
        error(e.toString());
        // Do not retain content after the server revokes access.
        if (e is api.ApiError && (e.status == 403 || e.status == 404)) {
          rows(const []);
          detail(null);
          unreadCount(0);
        }
      }
    } finally {
      if (!_closed && generation == _generation) busy(false);
    }
  }

  Future<Map<String, dynamic>> recipients(String? studentId) => client()
      .runQuery('list-conversation-recipients', {'studentId': ?studentId});
  Future<String?> send(Map<String, dynamic> input, {bool start = false}) async {
    if (sending.value) return null;
    final key = sessionKey;
    final digest = jsonEncode(input);
    if (_retryDigest != digest) {
      _retryDigest = digest;
      _retryId = messagingRequestId();
    }
    sending(true);
    error('');
    try {
      final response = await client().runCommand(
        start ? 'start-conversation' : 'reply-conversation',
        {...input, 'requestId': _retryId},
      );
      if (_closed || key != sessionKey) return null;
      _retryDigest = null;
      _retryId = null;
      conversationCountsChanged.add(null);
      await refresh();
      if (_closed || key != sessionKey) return null;
      return response['id'] as String;
    } catch (e) {
      if (!_closed && key == sessionKey) {
        if (e is api.ApiError &&
            jsonEncode(e.body).contains('CONVERSATION_CHANGED')) {
          await refresh();
          if (!_closed && key == sessionKey) error('CONVERSATION_CHANGED');
        } else {
          error('SEND_FAILED');
        }
      }
      return null;
    } finally {
      if (!_closed && key == sessionKey) sending(false);
    }
  }
}
