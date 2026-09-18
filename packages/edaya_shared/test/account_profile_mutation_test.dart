import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/src/features/account/account_profile_controller.dart';
import 'package:edaya_shared/src/features/account/account_profile_models.dart';
import 'package:edaya_shared/src/features/auth/app_session_controller.dart';
import 'package:edaya_shared/src/l10n/l10n_lookup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class ProfileSession implements AppSessionController {
  @override
  final grants = LxVar<EffectiveGrantsResponse?>(
    const EffectiveGrantsResponse(
      kind: 'guardian',
      actorId: 'guardian-a',
      schoolId: 'school-a',
      assuranceLevel: 'standard',
      grants: [],
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ProfileTransport implements Transport {
  int writes = 0;
  Object? failure;
  final bodies = <Object?>[];

  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    expect(method, 'POST');
    expect(path, contains('update-guardian-contact-methods'));
    writes++;
    bodies.add(options?.body);
    if (failure != null) throw failure!;
    return <String, dynamic>{} as T;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final rejected in [false, true]) {
    test(
      rejected
          ? 'profile conflict preserves the draft and does not retry'
          : 'saved guardian profile survives a failed display callback',
      () async {
        final session = ProfileSession();
        final transport = ProfileTransport();
        if (rejected) transport.failure = ApiError(409, {});
        final controller = AccountProfileController(
          session: session,
          schoolClient: () => createSchoolClient(transport),
          onProfileSaved: (_) async {
            throw StateError('display refresh failed');
          },
        );
        controller.profile(
          const AccountContactProfile(
            id: 'guardian-a',
            firstName: 'Before',
            lastName: 'Name',
          ),
        );
        controller.firstNameController.text = 'After';
        controller.lastNameController.text = 'Name';
        final saved = await controller.saveProfile();
        expect(saved, !rejected);
        expect(transport.writes, 1);
        expect((transport.bodies.single as Map)['guardianId'], 'guardian-a');
        expect(
          controller.profile.value!.firstName,
          rejected ? 'Before' : 'After',
        );
        expect(controller.firstNameController.text, 'After');
        expect(controller.isSaving.value, isFalse);
        expect(
          controller.saveMessage.value,
          rejected
              ? systemL10n().mutationConflict
              : systemL10n().mutationSavedRefreshFailed,
        );
        controller.onClose();
      },
    );
  }
}
