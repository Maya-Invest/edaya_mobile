import 'package:edaya_teacher/common/utils/academic_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currentAcademicPeriodId picks period containing date', () {
    final periodId = currentAcademicPeriodId(const [
      {'id': '2025-t1', 'startDate': '2025-09-01', 'endDate': '2025-12-19'},
      {'id': '2025-t3', 'startDate': '2026-04-20', 'endDate': '2026-07-03'},
    ], onDate: DateTime(2026, 6, 27));

    expect(periodId, '2025-t3');
  });
}
