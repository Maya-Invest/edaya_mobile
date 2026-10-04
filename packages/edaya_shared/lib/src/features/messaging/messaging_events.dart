import 'dart:async';

final messagingRefreshEvents = StreamController<void>.broadcast();
final conversationCountsChanged = StreamController<void>.broadcast();
