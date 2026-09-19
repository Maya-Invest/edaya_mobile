import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogQuery applies the school API max list limit', () {
    expect(
      catalogQuery(studentScope('stu-1')),
      {
        'studentId': 'stu-1',
        r'$limit': catalogListPageSize,
      },
    );
    expect(catalogListPageSize, 500);
  });
}
