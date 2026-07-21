import 'package:edaya_teacher/features/report_cards/report_card_comment_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractWritableReportCardCommentFields', () {
    test('includes homeroom comment for homeroom teachers', () {
      final fields = extractWritableReportCardCommentFields(
        result: {
          'status': 'draft',
          'teacherComment': 'Existing',
          'sectionResults': [],
        },
        classGroupId: 'cg-7a',
        homeroomClassGroupIds: {'cg-7a'},
        taughtClassSubjectIds: const {},
      );

      expect(fields.single.sectionId, '__homeroom__');
      expect(fields.single.initialComment, 'Existing');
    });

    test('includes subject comments only for assigned class subjects', () {
      final fields = extractWritableReportCardCommentFields(
        result: {
          'status': 'draft',
          'sectionResults': [
            {
              'sectionId': 'subject-math',
              'sectionKind': 'subject',
              'name': 'Mathematics',
              'classSubjectId': 'cs-math',
              'comment': 'Good',
            },
            {
              'sectionId': 'subject-french',
              'sectionKind': 'subject',
              'name': 'French',
              'classSubjectId': 'cs-french',
            },
          ],
        },
        classGroupId: 'cg-7a',
        homeroomClassGroupIds: const {},
        taughtClassSubjectIds: {'cs-math'},
      );

      expect(fields, hasLength(1));
      expect(fields.single.sectionId, 'subject-math');
    });

    test('returns no fields for published report cards', () {
      final fields = extractWritableReportCardCommentFields(
        result: {
          'status': 'published',
          'teacherComment': 'Locked',
          'sectionResults': [],
        },
        classGroupId: 'cg-7a',
        homeroomClassGroupIds: {'cg-7a'},
        taughtClassSubjectIds: const {},
      );

      expect(fields, isEmpty);
    });
  });

  group('applyReportCardCommentUpdates', () {
    test('updates homeroom and nested section comments', () {
      final updated = applyReportCardCommentUpdates(
        {
          'teacherComment': 'Before',
          'sectionResults': [
            {
              'sectionId': 'group-1',
              'comment': 'Group before',
              'subResults': [
                {
                  'sectionId': 'subject-math',
                  'comment': 'Math before',
                },
              ],
            },
          ],
        },
        commentsBySectionId: {
          '__homeroom__': 'After',
          'group-1': 'Group after',
          'subject-math': 'Math after',
        },
      );

      expect(updated['teacherComment'], 'After');
      final group = (updated['sectionResults'] as List).first as Map;
      expect(group['comment'], 'Group after');
      final subject = (group['subResults'] as List).first as Map;
      expect(subject['comment'], 'Math after');
    });
  });
}
