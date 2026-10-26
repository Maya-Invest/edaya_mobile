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
  Future<void> Function()? beforeResponse;
  final bodies = <Object?>[];

  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    expect(method, 'POST');
    expect(path, contains('update-guardian-profile'));
    writes++;
    bodies.add(options?.body);
    await beforeResponse?.call();
    if (failure != null) throw failure!;
    return <String, dynamic>{} as T;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'single-token guardians can save without a first name; teachers still require one',
    () async {
      final session = ProfileSession();
      final transport = ProfileTransport();
      final controller = AccountProfileController(
        session: session,
        schoolClient: () => createSchoolClient(transport),
      );
      controller.profile(
        const AccountContactProfile(
          id: 'guardian-a',
          firstName: '',
          lastName: 'Koné',
        ),
      );
      controller.lastNameController.text = 'Koné';
      expect(controller.canSave, isTrue);
      expect(await controller.saveProfile(), isTrue);
      expect(controller.profile.value!.firstName, '');
      expect(transport.writes, 1);
      controller.lastNameController.text = ' ';
      expect(controller.canSave, isFalse);
      controller.lastNameController.text = 'Koné';
      session.grants(
        const EffectiveGrantsResponse(
          kind: 'teacher',
          actorId: 'teacher-a',
          schoolId: 'school-a',
          assuranceLevel: 'standard',
          grants: [],
        ),
      );
      expect(controller.canSave, isFalse);
      controller.onClose();
    },
  );

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
        expect(controller.profile.value!.firstName, 'Before');
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
  test(
    'guardian contacts and channel opt-outs save without identity or account fields',
    () async {
      final session = ProfileSession();
      final transport = ProfileTransport();
      final controller = AccountProfileController(
        session: session,
        schoolClient: () => createSchoolClient(transport),
      );
      controller.profile(
        const AccountContactProfile(
          id: 'guardian-a',
          firstName: 'Original',
          lastName: 'Name',
          phone: '+22501020304',
          alternativePhone: '+22505060708',
          emailNotificationsEnabled: false,
          smsNotificationsEnabled: false,
          pushNotificationsEnabled: false,
        ),
      );
      controller.firstNameController.text = 'Cannot change';
      controller.lastNameController.text = 'Name';
      controller.alternativePhoneController.text = '+22505060708';
      controller.emailNotificationsEnabled(false);
      controller.smsNotificationsEnabled(false);
      controller.pushNotificationsEnabled(false);
      expect(controller.isDirty, isTrue);
      expect(await controller.saveProfile(), isTrue);
      final body = transport.bodies.single as Map;
      expect(body['phone'], isNull);
      expect(body['alternativePhone'], '+22505060708');
      expect(body['smsNotificationsEnabled'], isFalse);
      expect(body['emailNotificationsEnabled'], isFalse);
      expect(body['pushNotificationsEnabled'], isFalse);
      expect(body.containsKey('hasAccess'), isFalse);
      expect(body.containsKey('firstName'), isFalse);
      expect(body.containsKey('contactMethods'), isFalse);
      expect(controller.profile.value!.firstName, 'Original');
      expect(controller.isDirty, isFalse);
      controller.onClose();
    },
  );

  test(
    'a late save response cannot update a different selected profile',
    () async {
      final session = ProfileSession();
      final transport = ProfileTransport();
      final controller = AccountProfileController(
        session: session,
        schoolClient: () => createSchoolClient(transport),
      );
      controller.profile(
        const AccountContactProfile(
          id: 'guardian-a',
          firstName: 'Original',
          lastName: 'Name',
        ),
      );
      controller.lastNameController.text = 'Name';
      controller.phoneController.text = '+22501020304';
      transport.beforeResponse = () async {
        session.grants(
          const EffectiveGrantsResponse(
            kind: 'guardian',
            actorId: 'guardian-b',
            schoolId: 'school-b',
            assuranceLevel: 'standard',
            grants: [],
          ),
        );
      };
      expect(await controller.saveProfile(), isFalse);
      expect(controller.profile.value!.phone, isNull);
      expect(controller.saveMessage.value, isEmpty);
      controller.onClose();
    },
  );
}
