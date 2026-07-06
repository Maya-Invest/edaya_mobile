import 'package:edaya_guardian/common/utils/academic_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currentAcademicPeriodId picks trimester 3 in July 2026 for demo-ci', () {
    final periodId = currentAcademicPeriodId(
      const [
        {
          'id': 'ci-2025-t1',
          'startDate': '2025-09-15',
          'endDate': '2025-12-19',
        },
        {
          'id': 'ci-2025-t2',
          'startDate': '2026-01-05',
          'endDate': '2026-03-27',
        },
        {
          'id': 'ci-2025-t3',
          'startDate': '2026-04-14',
          'endDate': '2026-07-10',
        },
      ],
      onDate: DateTime(2026, 7, 6),
    );

    expect(periodId, 'ci-2025-t3');
  });
}
