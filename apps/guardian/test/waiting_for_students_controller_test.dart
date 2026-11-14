import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_guardian_v2/features/waiting/waiting_for_students_controller.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class _Session implements AppSessionController {
  @override
  final user = LxVar<AuthUser?>(
    const AuthUser(id: 'person', email: 'person@example.test'),
  );
  @override
  final isSigningOut = LxVar(false);
  var signedOut = false;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport implements api.Transport {
  _Transport(this.responses);

  final List<Object> responses;
  final requests = <Map<String, Object?>>[];

  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    requests.add({'method': method, 'path': path, 'body': options?.body});
    if (responses.isEmpty) {
      throw StateError('No queued response for $method $path');
    }
    final next = responses.removeAt(0);
    if (next is Exception) {
      throw next;
    }
    return next as T;
  }
}

Future<void> until(bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Waiting controller did not finish');
}

Map<String, dynamic> invitationJson({
  String id = 'inv-1',
  String schoolName = 'Demo School',
  String inviteeName = 'Alice Parent',
}) => {
  'id': id,
  'kind': 'guardian',
  'status': 'pending',
  'schoolName': schoolName,
  'inviteeName': inviteeName,
  'contactChannel': 'email',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads pending invitations without accepting them', () async {
    final transport = _Transport([
      {
        'invitations': [invitationJson()],
      },
    ]);
    var checked = 0;
    final controller = WaitingForStudentsController(
      session: _Session(),
      schoolClient: () => api.createSchoolClient(transport),
      onCheckAgain: () async {
        checked += 1;
      },
    );
    controller.onInit();
    addTearDown(controller.onClose);
    await until(() => controller.loadStatus.value != DataStatus.loading);

    expect(controller.invitations.value.single.id, 'inv-1');
    expect(controller.loadStatus.value, DataStatus.ready);
    expect(checked, 0);
    expect(transport.requests, [
      {'method': 'GET', 'path': '/public/me/invitations', 'body': null},
    ]);
  });

  test('accepts a listed invitation then refreshes the session', () async {
    final transport = _Transport([
      {
        'invitations': [invitationJson()],
      },
      {
        'kind': 'guardian',
        'entity': {'id': 'guardian-1'},
      },
      {'invitations': <Map<String, dynamic>>[]},
    ]);
    var checked = 0;
    final controller = WaitingForStudentsController(
      session: _Session(),
      schoolClient: () => api.createSchoolClient(transport),
      onCheckAgain: () async {
        checked += 1;
      },
    );
    controller.onInit();
    addTearDown(controller.onClose);
    await until(() => controller.invitations.value.isNotEmpty);

    await controller.accept(controller.invitations.value.single);
    expect(checked, 1);
    expect(controller.invitations.value, isEmpty);
    expect(transport.requests.last, {
      'method': 'GET',
      'path': '/public/me/invitations',
      'body': null,
    });
  });

  test('keeps an empty waiting list without auto-accepting', () async {
    final transport = _Transport([
      {'invitations': <Map<String, dynamic>>[]},
    ]);
    final controller = WaitingForStudentsController(
      session: _Session(),
      schoolClient: () => api.createSchoolClient(transport),
      onCheckAgain: () async {},
    );
    controller.onInit();
    addTearDown(controller.onClose);
    await until(() => controller.loadStatus.value != DataStatus.loading);

    expect(controller.invitations.value, isEmpty);
    expect(controller.loadStatus.value, DataStatus.empty);
  });

  test('surfaces accept errors without leaving the waiting screen', () async {
    final transport = _Transport([
      {
        'invitations': [invitationJson()],
      },
      api.ApiError(409, {'code': 'SUBJECT_ALREADY_LINKED'}),
    ]);
    var checked = 0;
    final controller = WaitingForStudentsController(
      session: _Session(),
      schoolClient: () => api.createSchoolClient(transport),
      onCheckAgain: () async {
        checked += 1;
      },
    );
    controller.onInit();
    addTearDown(controller.onClose);
    await until(() => controller.invitations.value.isNotEmpty);

    await controller.accept(controller.invitations.value.single);
    expect(checked, 0);
    expect(controller.errorMessage.value, isNotEmpty);
    expect(controller.loadStatus.value, DataStatus.ready);
  });
}
