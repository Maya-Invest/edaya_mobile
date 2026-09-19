import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacherLogbookIdempotencyKey scopes note and matter entries', () {
    expect(
      teacherLogbookIdempotencyKey(lessonSessionId: 'ls-1'),
      'logbook:ls-1:note',
    );
    expect(
      teacherLogbookIdempotencyKey(
        lessonSessionId: 'ls-1',
        matterId: 'matter-1',
      ),
      'logbook:ls-1:matter-1',
    );
  });

  test('buildTeacherOutboxEntry stores pending state', () {
    final entry = buildTeacherOutboxEntry(
      id: 'mark-1',
      kind: TeacherOutboxKind.mark,
      idempotencyKey: teacherMarkIdempotencyKey(
        assessmentId: 'asm-1',
        studentId: 'stu-1',
      ),
      payload: markOutboxPayload(
        assessmentId: 'asm-1',
        studentId: 'stu-1',
        score: 12,
      ),
    );

    expect(entry.state, TeacherOutboxState.pending);
    expect(entry.kind, TeacherOutboxKind.mark);
  });
}
