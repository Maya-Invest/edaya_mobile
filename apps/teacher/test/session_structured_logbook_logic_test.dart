import 'package:edaya_teacher/features/session/session_logbook_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodeStructuredSessionNote treats plain text as content', () {
    const raw = 'Covered fractions today';
    final decoded = decodeStructuredSessionNote(raw);
    expect(decoded.content, raw);
    expect(decoded.objectives, isEmpty);
  });

  test('encode and decode structured session note round trip', () {
    const content = StructuredLogbookContent(
      content: 'Lesson narrative',
      objectives: ['Understand fractions', 'Apply to word problems'],
      homework: 'Workbook p.12',
      familySummary: 'We studied fractions today.',
    );

    final encoded = encodeStructuredSessionNote(content);
    final decoded = decodeStructuredSessionNote(encoded);

    expect(decoded.content, 'Lesson narrative');
    expect(decoded.objectives, content.objectives);
    expect(decoded.homework, 'Workbook p.12');
    expect(decoded.familySummary, 'We studied fractions today.');
  });

  test('composeFamilyVisiblePreview prefers family summary', () {
    const content = StructuredLogbookContent(
      content: 'Lesson narrative',
      familySummary: 'Family-facing recap',
    );

    expect(
      composeFamilyVisiblePreview(content),
      'Family-facing recap',
    );
  });
}
