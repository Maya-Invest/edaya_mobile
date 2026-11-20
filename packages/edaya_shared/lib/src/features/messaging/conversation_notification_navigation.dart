import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../auth/app_session_controller.dart';
import '../push/push_notifications.dart';

/// Pending destinations are held in memory only, and are resolved against current profiles.
class ConversationNotificationNavigation {
  StreamSubscription<dynamic>? _profiles, _grants, _user;
  Map<String, String>? _pending;
  String? _subject;
  bool _opening = false;
  Future<void> Function()? _attempt;
  int _generation = 0;
  bool handle(
    RemoteMessage message, {
    required AppSessionController session,
    required String kind,
    required void Function(String path) onReady,
  }) {
    final data = notificationMessageData(message);
    final id = data['conversationId'];
    if (id == null || id.isEmpty) return false;
    clear();
    _pending = data;
    _subject = session.user.value?.id;
    final generation = _generation;
    Future<void> attempt() async {
      if (_opening ||
          _pending == null ||
          generation != _generation ||
          !session.isAuthenticated) {
        return;
      }
      if (_subject != null && _subject != session.user.value?.id) {
        clear();
        return;
      }
      final schoolId = data['schoolId'];
      if (schoolId == null || schoolId.isEmpty) {
        clear();
        return;
      }
      _opening = true;
      try {
        final grants = session.grants.value;
        if (grants?.schoolId != schoolId ||
            grants?.kind != kind ||
            (data['recipientId'] != null &&
                grants?.actorId != data['recipientId'])) {
          final profiles = session.availableProfiles.value.where(
            (p) =>
                p.schoolId == schoolId &&
                p.kind == kind &&
                (data['recipientId'] == null ||
                    p.actorId == data['recipientId']),
          );
          if (profiles.isEmpty) return;
          final error = await session.selectProfile(profiles.first);
          if (generation != _generation) return;
          if (error != null) {
            clear();
            return;
          }
        }
        final current = session.grants.value;
        if (generation != _generation ||
            current?.schoolId != schoolId ||
            current?.kind != kind ||
            (data['recipientId'] != null &&
                current?.actorId != data['recipientId'])) {
          return;
        }
        _pending = null;
        onReady('/inbox/conversation/${Uri.encodeComponent(id)}');
        clear();
      } catch (_) {
        // Keep the destination pending for a later successful profile refresh.
      } finally {
        _opening = false;
        if (generation != _generation && _pending != null) {
          final next = _attempt;
          if (next != null) unawaited(next());
        }
      }
    }

    _attempt = attempt;
    _profiles = session.availableProfiles.stream.listen(
      (_) => unawaited(attempt()),
    );
    _grants = session.grants.stream.listen((_) => unawaited(attempt()));
    _user = session.user.stream.listen((user) {
      if (_subject != null && user == null) {
        clear();
      } else {
        unawaited(attempt());
      }
    });
    unawaited(attempt());
    return true;
  }

  void clear() {
    _generation++;
    _pending = null;
    _attempt = null;
    unawaited(_profiles?.cancel());
    unawaited(_grants?.cancel());
    unawaited(_user?.cancel());
    _profiles = null;
    _grants = null;
    _user = null;
  }
}
