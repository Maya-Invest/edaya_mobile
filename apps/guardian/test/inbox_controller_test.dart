import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_guardian/features/inbox/inbox_controller.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class _Session implements AppSessionController {
  @override
  final user = LxVar<AuthUser?>(
    const AuthUser(id: 'person', email: 'person@example.test'),
  );
  @override
  final grants = LxVar<api.EffectiveGrantsResponse?>(profile('guardian-a'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

api.EffectiveGrantsResponse profile(
  String id, {
  String kind = 'guardian',
  String school = 'school',
}) => api.EffectiveGrantsResponse(
  kind: kind,
  actorId: id,
  schoolId: school,
  assuranceLevel: 'verified',
  grants: const [],
);

class _Transport implements api.Transport {
  final queries = <Object?>[];
  final pending = <Completer<List<Map<String, dynamic>>>>[];
  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    queries.add(options?.body);
    final response = Completer<List<Map<String, dynamic>>>();
    pending.add(response);
    return await response.future as T;
  }
}

Map<String, dynamic> delivery(String id) => {
  'id': id,
  'subjectId': 'person',
  'status': 'sent',
  'title': 'Message',
  'body': 'Private body',
};

Future<void> until(bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Inbox operation did not finish');
}

void main() {
  test(
    'personal inbox sends the selected guardian and school with the login',
    () async {
      final session = _Session();
      final transport = _Transport();
      final controller = InboxController(
        session: session,
        schoolClient: () => api.createSchoolClient(transport),
      );
      controller.onInit();
      addTearDown(controller.onClose);
      await until(() => transport.pending.length == 1);
      expect(transport.queries.single, {
        'subjectId': 'person',
        'recipientKind': 'guardian',
        'recipientId': 'guardian-a',
        'schoolId': 'school',
      });
      transport.pending.single.complete([delivery('a')]);
      await until(() => controller.deliveries.value.isNotEmpty);
      expect(controller.deliveries.value.single.id, 'a');
    },
  );

  test(
    'late responses cannot repopulate a switched profile or signed-out inbox',
    () async {
      final session = _Session();
      final transport = _Transport();
      final controller = InboxController(
        session: session,
        schoolClient: () => api.createSchoolClient(transport),
      );
      controller.onInit();
      addTearDown(controller.onClose);
      await until(() => transport.pending.length == 1);
      session.grants(profile('guardian-b'));
      await until(() => transport.pending.length == 2);
      transport.pending[1].complete([delivery('b')]);
      await until(() => controller.deliveries.value.isNotEmpty);
      transport.pending[0].complete([delivery('a')]);
      await until(() => !controller.isBusy.value);
      expect(controller.deliveries.value.map((row) => row.id), ['b']);
      final third = controller.loadInbox();
      await until(() => transport.pending.length == 3);
      session.user(null);
      await until(() => controller.deliveries.value.isEmpty);
      transport.pending[2].complete([delivery('b')]);
      await third;
      expect(controller.deliveries.value, isEmpty);
    },
  );

  test('another profile kind cannot issue a guardian inbox request', () async {
    final session = _Session()..grants(profile('staff', kind: 'staff'));
    final transport = _Transport();
    final controller = InboxController(
      session: session,
      schoolClient: () => api.createSchoolClient(transport),
    );
    controller.onInit();
    addTearDown(controller.onClose);
    await controller.loadInbox();
    expect(transport.queries, isEmpty);
    expect(controller.deliveries.value, isEmpty);
  });
}
