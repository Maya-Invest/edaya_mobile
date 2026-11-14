import 'dart:convert';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher_v2/features/account/teacher_portrait.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  SchoolAuthorizationProfile profile(String school) =>
      SchoolAuthorizationProfile(
        kind: 'teacher',
        schoolId: school,
        actorId: 'teacher-$school',
        schoolName: school,
        schoolShortName: school,
      );
  test(
    'the same account portrait uses its owning grant across schools and is isolated on account change',
    () async {
      final schools = <String?>[];
      final source = TeacherPortraitSource(
        AuthClient(
          baseUrl: ApiBaseUrlConfig.baseUrl,
          client: MockClient((request) async {
            final school = request.headers['x-school-id'];
            schools.add(school);
            expect(request.headers['x-actor-id'], 'teacher-$school');
            return http.Response(
              jsonEncode({
                'id': 'teacher-$school',
                if (school == 'B') 'photoUrl': '/core/files/b-photo/content',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      final first = await source.resolve('account-1', null, [
        profile('B'),
        profile('A'),
      ]);
      expect(first?.url, '/core/files/b-photo/content');
      expect(schools, ['A', 'B']);
      final second = await source.resolve('account-1', null, [
        profile('A'),
        profile('B'),
      ]);
      expect(second?.client, same(first?.client));
      expect(schools, ['A', 'B']);
      expect(await source.resolve('account-2', null, [profile('A')]), isNull);
      expect(schools, ['A', 'B', 'A']);
      expect(
        (await source.resolve('account-2', 'https://example.test/account.jpg', [
          profile('A'),
        ]))?.url,
        'https://example.test/account.jpg',
      );
      expect(schools, ['A', 'B', 'A']);
    },
  );
}
