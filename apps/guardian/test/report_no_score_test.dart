import 'package:edaya_guardian/features/scolarite/models/report_card_summary.dart';
import 'package:edaya_guardian/features/scolarite/models/grade_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fractional marks are displayed without integer truncation', () {
    final grade = GradeEntry.fromMaps(
      result: {'id': 'r', 'score': 12.75, 'designation': 'scored'},
      assessment: {'id': 'a', 'title': 'Quiz', 'periodId': 'p', 'maxScore': 20},
      subjectName: 'Math',
      periodName: 'Term',
    );
    expect(grade.scoreLabel, '12.75 / 20.00');
    expect(grade.designation, 'scored');
  });

  test('nested group comments remain associated with their named section', () {
    final report = ReportCardDetail.fromJson({
      'id': 'report',
      'sectionResults': [
        {
          'sectionId': 'root',
          'sectionKind': 'group',
          'name': 'Core',
          'comment': 'Overall progress',
          'subResults': [
            {
              'sectionId': 'nested',
              'sectionKind': 'group',
              'name': 'Languages',
              'comment': 'Keep reading',
              'subResults': [],
            },
          ],
        },
      ],
    }, periodName: 'Term');
    expect(report.sections.single.comment, 'Overall progress');
    expect(report.sections.single.groupComments.single.name, 'Languages');
    expect(report.sections.single.groupComments.single.comment, 'Keep reading');
  });

  test(
    'same-name report sections retain identities and distinguish no score from zero',
    () {
      final report = ReportCardDetail.fromJson({
        'id': 'report',
        'sectionResults': [
          {
            'sectionId': 'first',
            'sectionKind': 'group',
            'name': 'Core',
            'comment': 'Absence',
            'subResults': [
              {
                'sectionId': 'first-math',
                'sectionKind': 'subject',
                'classSubjectId': 'math',
                'name': 'Math',
                'comment': 'Excused',
              },
            ],
          },
          {
            'sectionId': 'second',
            'sectionKind': 'group',
            'name': 'Core',
            'average': 0,
            'subResults': [
              {
                'sectionId': 'second-math',
                'sectionKind': 'subject',
                'classSubjectId': 'math',
                'name': 'Math',
                'average': 0,
              },
            ],
          },
        ],
      }, periodName: 'Term');
      expect(report.sections, hasLength(2));
      expect(report.sections.first.average, isNull);
      expect(report.sections.first.subjects.single.average, isNull);
      expect(report.sections.first.subjects.single.comment, 'Excused');
      expect(report.sections.last.subjects.single.average, 0);
    },
  );
}
