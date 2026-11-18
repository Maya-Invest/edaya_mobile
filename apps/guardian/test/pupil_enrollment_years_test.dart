import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_guardian_v2/features/context/pupil_enrollment_years.dart';

void main() {
  test(
    'pupil years include closed enrollments but exclude other pupils and unearned years',
    () {
      final years = [
        {'id': 'future', 'startDate': '2027-09-01', 'status': 'draft'},
        {'id': 'current', 'startDate': '2026-09-01', 'status': 'published'},
        {'id': 'old', 'startDate': '2025-09-01', 'status': 'archived'},
      ];
      final enrollments = [
        {'studentId': 'child', 'academicYearId': 'current', 'status': 'active'},
        {'studentId': 'child', 'academicYearId': 'old', 'status': 'closed'},
        {
          'studentId': 'another',
          'academicYearId': 'future',
          'status': 'active',
        },
      ];
      final available = pupilEnrollmentYears(years, enrollments, 'child');
      expect(available.map((r) => r['id']), ['current', 'old']);
      expect(defaultPupilYear(available), 'current');
      final closedOnly = pupilEnrollmentYears(
        years,
        enrollments.skip(1),
        'child',
      );
      expect(closedOnly, hasLength(1));
      expect(defaultPupilYear(closedOnly), 'old');
      expect(
        defaultPupilYear(pupilEnrollmentYears(years, enrollments, 'missing')),
        isNull,
      );
    },
  );
}
