import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'profile selection uses the saved short name independently of school name',
    () {
      for (final name in ['Original school', 'Renamed school']) {
        final profile = SchoolAuthorizationProfile(
          kind: 'teacher',
          actorId: 'teacher',
          schoolId: 'school',
          schoolName: name,
          schoolShortName: 'Saved name',
        );
        expect(profile.label, 'Saved name');
      }
      const legacy = SchoolAuthorizationProfile(
        kind: 'guardian',
        actorId: 'guardian',
        schoolId: 'school',
        schoolName: 'Older school',
        schoolShortName: '',
      );
      expect(legacy.label, 'Older school');
    },
  );
}
