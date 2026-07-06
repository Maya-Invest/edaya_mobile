import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assessmentResultPayload uses deterministic result id', () {
    expect(
      assessmentResultPayload(
        assessmentId: 'asm-1',
        studentId: 'stu-1',
        score: 14.5,
        createdAt: DateTime.utc(2026, 4, 1, 12),
      ),
      {
        'id': 'ar-asm-1-stu-1',
        'studentId': 'stu-1',
        'assessmentId': 'asm-1',
        'score': 14.5,
        'createdAt': '2026-04-01T12:00:00.000Z',
      },
    );
  });

  test('createAssessmentPayload adds in-class timing for quiz assessments', () {
    final payload = createAssessmentPayload(
      id: 'asm-1',
      classGroupId: 'cg-1',
      classSubjectId: 'cs-1',
      periodId: 'p-1',
      title: 'Quiz 1',
      maxScore: 20,
      createdAt: DateTime.utc(2026, 4, 1),
      assessmentDate: DateTime.utc(2026, 4, 15),
    );

    expect(payload['startsAt'], '2026-04-15T09:00:00.000Z');
    expect(payload['endsAt'], '2026-04-15T10:00:00.000Z');
    expect(payload.containsKey('dueAt'), isFalse);
  });
}
