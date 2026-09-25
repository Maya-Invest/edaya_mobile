import 'package:edaya_api_client/edaya_api_client.dart';

import 'account_profile_models.dart';

List<Map<String, dynamic>> buildGuardianContactMethods({
  required String email,
  required String phone,
}) {
  return [
    if (email.isNotEmpty)
      {
        'type': 'email',
        'value': email,
        'label': 'Email',
        'isPrimary': true,
        'allowsNotifications': true,
      },
    if (phone.isNotEmpty)
      {
        'type': 'phone',
        'value': phone,
        'label': 'Phone',
        'isPrimary': email.isEmpty,
        'allowsNotifications': true,
      },
  ];
}

Future<AccountContactProfile> loadAccountContactProfile(
  SchoolClient client, {
  required String kind,
  required String actorId,
}) async {
  switch (kind) {
    case 'guardian':
      final guardian = await client.guardians.get(actorId);
      return AccountContactProfile(
        id: actorId,
        firstName: guardian['firstName'] as String? ?? '',
        lastName: guardian['lastName'] as String? ?? '',
        email: guardian['email'] as String?,
        phone: guardian['phone'] as String?,
        photoUrl: guardian['photoUrl'] as String?,
        hasAccess: guardian['hasAccess'] as bool? ?? true,
      );
    case 'staff':
      final staff = await client.staffMembers.get(actorId);
      return AccountContactProfile(
        id: actorId,
        firstName: staff['firstName'] as String? ?? '',
        lastName: staff['lastName'] as String? ?? '',
        email: staff['email'] as String?,
        photoUrl: staff['photoUrl'] as String?,
      );
    case 'teacher':
      final teacher = await client.teachers.get(actorId);
      return AccountContactProfile(
        id: actorId,
        firstName: teacher['firstName'] as String? ?? '',
        lastName: teacher['lastName'] as String? ?? '',
        email: teacher['email'] as String?,
        phone: teacher['phone'] as String?,
        photoUrl: teacher['photoUrl'] as String?,
      );
    default:
      throw UnsupportedError('Unsupported profile kind: $kind');
  }
}

Future<void> saveAccountContactProfile(
  SchoolClient client, {
  required String kind,
  required AccountContactProfile profile,
}) async {
  final firstName = profile.firstName.trim();
  final lastName = profile.lastName.trim();
  final email = profile.email?.trim() ?? '';
  final phone = profile.phone?.trim() ?? '';

  switch (kind) {
    case 'guardian':
      await client.updateGuardianContactMethods({
        'guardianId': profile.id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email.isEmpty ? null : email,
        'phone': phone.isEmpty ? null : phone,
        'contactMethods': buildGuardianContactMethods(
          email: email,
          phone: phone,
        ),
        'hasAccess': profile.hasAccess,
        if (profile.photoUrl != null) 'photoUrl': profile.photoUrl,
      });
      return;
    case 'staff':
      await client.updateStaffMemberProfile({
        'staffId': profile.id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email.isEmpty ? null : email,
        if (profile.photoUrl != null) 'photoUrl': profile.photoUrl,
      });
      return;
    case 'teacher':
      await client.updateTeacherSelfProfile({
        'firstName': firstName,
        'lastName': lastName,
        'email': email.isEmpty ? null : email,
        'phone': phone.isEmpty ? null : phone,
      });
      return;
    default:
      throw UnsupportedError('Unsupported profile kind: $kind');
  }
}
