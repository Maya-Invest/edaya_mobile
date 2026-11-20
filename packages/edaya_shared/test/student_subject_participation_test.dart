import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'period selections respect activation and future boundaries without duplicates',
    () {
      final selection = StudentSubjectParticipation(
        [
          {
            'classSubjectId': 'music',
            'scope': 'periods',
            'enrolledAt': '2026-10-24T12:00:00Z',
            'endedAt': '2027-07-01T00:00:00Z',
            'periods': [
              {
                'periodId': 'current',
                'activatedAt': '2026-10-24T12:00:00Z',
                'startsAt': '2026-09-01T00:00:00Z',
                'endsAt': '2027-01-01T00:00:00Z',
              },
              {
                'periodId': 'future',
                'activatedAt': '2026-10-24T12:00:00Z',
                'startsAt': '2027-02-01T00:00:00Z',
                'endsAt': '2027-06-01T00:00:00Z',
              },
            ],
          },
        ],
        [
          {'id': 'music'},
        ],
      );
      expect(
        selection.includes('music', DateTime.parse('2026-10-24T11:59:59Z')),
        false,
      );
      expect(selection.currentSubjects(DateTime.parse('2026-11-01')).length, 1);
      expect(selection.includes('music', DateTime.parse('2027-01-01')), false);
      expect(selection.includes('music', DateTime.parse('2027-02-01')), true);
      expect(selection.includes('music', DateTime.parse('2027-06-01')), false);
    },
  );

  test(
    'selected children have independent subjects with half-open current selections',
    () {
      final first = StudentSubjectParticipation(
        [
          {
            'classSubjectId': 'music',
            'enrolledAt': '2026-09-01T04:00:00Z',
            'endedAt': '2026-10-01T04:00:00Z',
          },
          {
            'classSubjectId': 'painting',
            'enrolledAt': '2026-09-01T04:00:00Z',
            'deletedAt': '2026-09-02T04:00:00Z',
          },
          {'classSubjectId': 'music', 'enrolledAt': '2026-11-01T04:00:00Z'},
        ],
        [
          {'id': 'music'},
          {'id': 'painting'},
        ],
      );
      final sibling = StudentSubjectParticipation(
        [
          {'classSubjectId': 'painting', 'enrolledAt': '2026-09-01T04:00:00Z'},
        ],
        [
          {'id': 'music'},
          {'id': 'painting'},
        ],
      );
      final start = DateTime.parse('2026-09-01T04:00:00Z');
      expect(first.includes('music', start), isTrue);
      expect(
        first.includes('music', start.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(
        first.includes('music', DateTime.parse('2026-10-01T04:00:00Z')),
        isFalse,
      );
      expect(
        first.includes('music', DateTime.parse('2026-11-01T04:00:00Z')),
        isTrue,
      );
      expect(first.currentSubjects(start).map((row) => row['id']), ['music']);
      expect(sibling.currentSubjects(start).map((row) => row['id']), [
        'painting',
      ]);
    },
  );
}
