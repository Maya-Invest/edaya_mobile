import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds student year account and attendance source ids', () {
    expect(
      studentYearAccountSourceId(
        schoolId: 'sch-1',
        studentId: 'stu-1',
        academicYearId: 'year-1',
        currency: 'XOF',
      ),
      'sya:sch-1:stu-1:year-1:XOF',
    );
    expect(
      attendanceSheetSourceId('cls-1', DateTime.utc(2026, 9, 15)),
      'cls-1:2026-09-15',
    );
  });

  test('unwraps issuance maps and lists', () {
    expect(unwrapIssuance({'id': 'iss-1', 'status': 'ready'})['id'], 'iss-1');
    expect(
      unwrapIssuance({
        'issuance': {'id': 'iss-2', 'status': 'failed'},
      })['id'],
      'iss-2',
    );
    expect(
      unwrapIssuanceList([
        {'id': 'a'},
        {'id': 'b'},
      ]).map((row) => row['id']),
      ['a', 'b'],
    );
    expect(
      unwrapIssuanceList({
        'items': [
          {'id': 'c'},
        ],
      }).single['id'],
      'c',
    );
  });
}
