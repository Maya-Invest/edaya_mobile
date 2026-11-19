import 'dart:async';
import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/features/messaging/conversation_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

class NoAuth implements AuthClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class NoPush implements PushNotificationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class Session extends AppSessionController {
  Future<void>? selectionGate;
  Session()
    : super(
        authClient: NoAuth(),
        sessionStorage: AuthSessionStorage(),
        pushNotifications: NoPush(),
        routerRefresh: EdayaRouterRefresh(),
        validateGrants: (_) => null,
        unauthorizedProfileMessage: () => 'Denied',
      ) {
    user(const AuthUser(id: 'login', email: 'parent@example.test'));
    grants(profile('g1', 's1'));
  }
  @override
  Future<String?> selectProfile(SchoolAuthorizationProfile selected) async {
    final gate = selectionGate;
    if (gate != null) await gate;
    grants(profile(selected.actorId, selected.schoolId));
    return null;
  }
}

api.EffectiveGrantsResponse profile(String id, String school) =>
    api.EffectiveGrantsResponse(
      kind: 'guardian',
      actorId: id,
      schoolId: school,
      assuranceLevel: 'verified',
      grants: const [],
    );
Map<String, dynamic> thread({bool reply = true, int version = 1}) => {
  'conversation': {
    'id': 'thread',
    'schoolName': 'Oak School',
    'guardianName': 'Sam Parent',
    'teacherName': 'Ada Teacher',
    'studentName': 'Robin',
    'subject': 'Homework',
    'destination': 'teacher',
    'version': version,
    'unread': true,
    'allowedActions': {'reply': reply},
  },
  'messages': [
    {
      'id': 'm1',
      'sequence': 1,
      'authorKind': 'guardian',
      'authorId': 'g1',
      'authorName': 'Sam Parent',
      'body': 'Which exercise?',
      'createdAt': '2026-10-04T12:00:00Z',
    },
  ],
  'hasMore': false,
};

class Transport implements api.Transport {
  final commands = <Map<String, dynamic>>[];
  bool failSend = false, canReply = true;
  Completer<Map<String, dynamic>>? pending;
  int reads = 0;
  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    if (path.endsWith('get-conversation')) {
      reads++;
      return (pending == null ? thread(reply: canReply) : await pending!.future)
          as T;
    }
    if (path.endsWith('list-conversation-recipients')) {
      return {
            'schoolName': 'Oak School',
            'schoolAvailable': true,
            'teachers': [],
          }
          as T;
    }
    if (path.endsWith('list-conversations')) {
      return {'items': [], 'total': 0, 'unreadCount': 0} as T;
    }
    if (path.endsWith('mark-conversation-read')) {
      commands.add(Map<String, dynamic>.from(options!.body as Map));
      return {'success': true} as T;
    }
    if (path.endsWith('reply-conversation') ||
        path.endsWith('start-conversation')) {
      commands.add(Map<String, dynamic>.from(options!.body as Map));
      if (failSend) throw api.ApiError(503, {'error': 'disconnected'});
      return {'id': 'thread'} as T;
    }
    throw StateError('Unexpected request $path');
  }
}

Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'failed sends retain retry identifiers; changing destination creates a new identifier',
    () async {
      final session = Session(), transport = Transport()..failSend = true;
      final controller = ConversationController(
        session: session,
        client: () => api.createSchoolClient(transport),
      );
      controller.onInit();
      addTearDown(controller.onClose);
      await flush();
      final input = {
        'destination': 'school',
        'subject': 'Opening hours',
        'body': 'When do you open?',
      };
      expect(await controller.send(input, start: true), isNull);
      transport.failSend = false;
      expect(await controller.send(input, start: true), 'thread');
      expect(
        transport.commands[0]['requestId'],
        transport.commands[1]['requestId'],
      );
      await controller.send({
        ...input,
        'teacherId': 't1',
        'destination': 'teacher',
        'studentId': 'child',
      }, start: true);
      expect(
        transport.commands.last['requestId'],
        isNot(transport.commands.first['requestId']),
      );
    },
  );
  test('a late thread response cannot leak into a different profile', () async {
    final session = Session(), transport = Transport()..pending = Completer();
    final controller = ConversationController(
      session: session,
      client: () => api.createSchoolClient(transport),
      conversationId: 'thread',
    );
    controller.onInit();
    addTearDown(controller.onClose);
    await flush();
    session.grants(null);
    await flush();
    transport.pending!.complete(thread());
    await flush();
    expect(controller.detail.value, isNull);
    expect(transport.commands, isEmpty);
  });
  test(
    'push waits through sign-in and selects the addressed school/profile before opening',
    () async {
      final session = Session()
        ..user(null)
        ..grants(null);
      final navigation = ConversationNotificationNavigation();
      addTearDown(navigation.clear);
      final paths = <String>[];
      navigation.handle(
        const RemoteMessage(
          data: {
            'conversationId': 'thread',
            'schoolId': 's2',
            'recipientId': 'g2',
          },
        ),
        session: session,
        kind: 'guardian',
        onReady: (path) {
          expect(session.grants.value?.schoolId, 's2');
          expect(session.grants.value?.actorId, 'g2');
          paths.add(path);
        },
      );
      await flush();
      expect(paths, isEmpty);
      session.user(const AuthUser(id: 'login', email: 'parent@example.test'));
      session.availableProfiles(const [
        SchoolAuthorizationProfile(
          kind: 'guardian',
          actorId: 'g2',
          schoolId: 's2',
          schoolName: 'Other',
          schoolShortName: '',
        ),
      ]);
      await flush();
      expect(paths, ['/inbox/conversation/thread']);
    },
  );

  test('a second alert survives an earlier pending school selection', () async {
    final session = Session();
    session.availableProfiles(const [
      SchoolAuthorizationProfile(
        kind: 'guardian',
        actorId: 'g2',
        schoolId: 's2',
        schoolName: 'Two',
        schoolShortName: '',
      ),
      SchoolAuthorizationProfile(
        kind: 'guardian',
        actorId: 'g3',
        schoolId: 's3',
        schoolName: 'Three',
        schoolShortName: '',
      ),
    ]);
    final gate = Completer<void>();
    session.selectionGate = gate.future;
    final navigation = ConversationNotificationNavigation();
    addTearDown(navigation.clear);
    final paths = <String>[];
    navigation.handle(
      const RemoteMessage(
        data: {
          'conversationId': 'older',
          'schoolId': 's2',
          'recipientId': 'g2',
        },
      ),
      session: session,
      kind: 'guardian',
      onReady: paths.add,
    );
    await flush();
    navigation.handle(
      const RemoteMessage(
        data: {
          'conversationId': 'newer',
          'schoolId': 's3',
          'recipientId': 'g3',
        },
      ),
      session: session,
      kind: 'guardian',
      onReady: paths.add,
    );
    session.selectionGate = null;
    gate.complete();
    await flush();
    expect(paths, ['/inbox/conversation/newer']);
    expect(session.grants.value?.actorId, 'g3');
  });
  testWidgets(
    'guardian composes a school enquiry without a child and retries a failed send without losing the draft',
    (tester) async {
      final session = Session(), transport = Transport()..failSend = true;
      final router = GoRouter(
        initialLocation: '/inbox',
        routes: [
          GoRoute(
            path: '/inbox',
            builder: (_, _) => Scaffold(
              body: MessagingInbox(
                guardian: true,
                notices: const [],
                onNotice: (_) {},
              ),
            ),
          ),
          GoRoute(
            path: '/inbox/conversation/:id',
            builder: (_, state) =>
                ConversationPage(conversationId: state.pathParameters['id']!),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        LScope(
          name: 'compose-test',
          dependencyFactory: (scope) {
            scope.put<AppSessionController>(() => session);
            scope.put<AppSettingsController>(() => AppSettingsController());
            scope.put<SchoolClientFactory>(
              () =>
                  () => api.createSchoolClient(transport),
            );
          },
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New conversation'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Subject',
        ),
        'Opening hours',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Message',
        ),
        'When do you open?',
      );
      await tester.ensureVisible(find.text('Send'));
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.text('When do you open?'), findsOneWidget);
      transport.failSend = false;
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      final attempts = transport.commands
          .where((r) => r.containsKey('subject'))
          .toList();
      expect(attempts, hasLength(2));
      expect(attempts.first['studentId'], isNull);
      expect(attempts.first['requestId'], attempts.last['requestId']);
      expect(find.byType(ConversationPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'historical thread remains readable without a composer at mobile and tablet sizes',
    (tester) async {
      final session = Session(), transport = Transport()..canReply = false;
      final router = GoRouter(
        initialLocation: '/inbox/conversation/thread',
        routes: [
          GoRoute(
            path: '/inbox/conversation/:id',
            builder: (_, state) =>
                ConversationPage(conversationId: state.pathParameters['id']!),
          ),
        ],
      );
      addTearDown(router.dispose);
      final widget = LScope(
        name: 'messaging-test',
        dependencyFactory: (scope) {
          scope.put<AppSessionController>(() => session);
          scope.put<AppSettingsController>(() => AppSettingsController());
          scope.put<SchoolClientFactory>(
            () =>
                () => api.createSchoolClient(transport),
          );
        },
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      for (final size in [const Size(390, 844), const Size(900, 1000)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();
        expect(find.text('Which exercise?'), findsOneWidget);
        expect(
          tester
              .widget<ConversationMessageBubble>(
                find.byType(ConversationMessageBubble),
              )
              .outgoing,
          isTrue,
        );
        expect(find.textContaining('2026-10-04T'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(tester.takeException(), isNull);
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
