import 'package:edaya_teacher_legacy/features/report_cards/report_card_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reportCardHasComment', () {
    test('detects homeroom comment', () {
      expect(
        reportCardHasComment({'teacherComment': 'Good term'}),
        isTrue,
      );
    });

    test('detects nested section comment', () {
      expect(
        reportCardHasComment({
          'sectionResults': [
            {
              'subResults': [
                {'comment': 'Solid work'},
              ],
            },
          ],
        }),
        isTrue,
      );
    });

    test('returns false when no comments exist', () {
      expect(reportCardHasComment({'sectionResults': []}), isFalse);
    });
  });

  group('reportCardIsGenerated', () {
    test('accepts draft and published statuses', () {
      expect(reportCardIsGenerated({'status': 'draft'}), isTrue);
      expect(reportCardIsGenerated({'status': 'published'}), isTrue);
      expect(reportCardIsGenerated({'status': 'generated'}), isFalse);
    });
  });
}
