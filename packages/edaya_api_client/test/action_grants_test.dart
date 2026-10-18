import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every scope grain survives JSON round trips without path conversion',
    () {
      final scopes = [
        {'kind': 'school'},
        for (final grain in GrantGrain.values)
          {'kind': 'all', 'grain': grain.value},
        {'kind': 'class_group', 'classGroupId': 'class'},
        {'kind': 'subject', 'gradeLevelId': 'grade', 'classGroupId': 'class'},
        {
          'kind': 'subject', 'gradeLevelId': 'grade',
          'classGroupId': 'class',
          'subjectId': 'subject',
        },
        {'kind': 'grade_level', 'gradeLevelId': 'grade'},
        {'kind': 'subject', 'gradeLevelId': 'grade'},
        {
          'kind': 'subject',
          'gradeLevelId': 'grade',
          'subjectId': 'subject',
        },
        {'kind': 'activity', 'activityId': 'activity'},
        {'kind': 'activity', 'classGroupId': 'class'},
        {'kind': 'activity', 'classGroupId': 'class', 'activityId': 'activity'},
        {'kind': 'student', 'studentId': 'student'},
      ];
      for (final scope in scopes) {
        expect(GrantScope.fromJson(scope).toJson(), scope);
      }
    },
  );
  test(
    'rejects unknown and incomplete targets instead of widening a grant',
    () {
      for (final scope in [
        {'kind': 'legacy'},
        {'kind': 'class_subject', 'classGroupId': 'class'},
        {'kind': 'all', 'grain': 'class_subject'},
        {'kind': 'class_subject'},
        {'kind': 'class_group', 'classGroupId': ''},
        {'kind': 'activity'},
        {'kind': 'all', 'grain': 'platform'},
        {
          'kind': 'subject', 'gradeLevelId': 'grade',
          'classGroupId': 'class',
          'subjectId': null,
        },
        {'kind': 'school', 'classGroupId': 'class'},
      ]) {
        expect(() => GrantScope.fromJson(scope), throwsFormatException);
      }
    },
  );
  test(
    'retains action, provenance, academic year and validity in one grant',
    () {
      final grant = ActionGrant.fromJson({
        'permission': 'GRADE_MANAGE',
        'source': 'manual',
        'academicYearId': 'year',
        'scopes': [
          {
            'kind': 'subject', 'gradeLevelId': 'grade',
            'classGroupId': 'class',
            'subjectId': 'subject',
          },
        ],
        'startsAt': '2026-01-01T00:00:00Z',
        'endsAt': '2026-12-31T00:00:00Z',
      });
      final roundTrip = ActionGrant.fromJson(grant.toJson());
      expect(roundTrip.permission, 'GRADE_MANAGE');
      expect(roundTrip.source, GrantSource.manual);
      expect(roundTrip.academicYearId, 'year');
      expect(roundTrip.startsAt, DateTime.utc(2026));
      expect(roundTrip.endsAt, DateTime.utc(2026, 12, 31));
      expect(
        (roundTrip.scopes.single as SubjectGrantScope).subjectId,
        'subject',
      );
    },
  );
  test('does not accept the removed authorization snapshot contract', () {
    expect(
      () => EffectiveGrantsResponse.fromJson({
        'kind': 'teacher',
        'actorId': 'teacher',
        'schoolId': 'school',
        'assuranceLevel': 'standard',
      }),
      throwsA(isA<TypeError>()),
    );
  });
}
