import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_teacher/features/session/session_logbook_logic.dart';

void main() {
  test('complete attendance only fills unmarked rows', () {
    const unmarked = [null, AttendanceFill.absent, null];
    final filled = [
      for (final status in unmarked) status ?? AttendanceFill.present,
    ];
    expect(filled, [
      AttendanceFill.present,
      AttendanceFill.absent,
      AttendanceFill.present,
    ]);
  });

  test('session note completeness ignores empty logbooks', () {
    expect(sessionNoteIndicatesComplete(null), isFalse);
    expect(sessionNoteIndicatesComplete(''), isFalse);
    expect(sessionNoteIndicatesComplete('Fractions'), isTrue);
    expect(
      sessionNoteIndicatesComplete(
        encodeStructuredSessionNote(
          const StructuredLogbookContent(content: 'Fractions'),
        ),
      ),
      isTrue,
    );
  });
}

enum AttendanceFill { present, absent }
