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

  test('flat module snapshots retain weighting, names and comments', () {
    final report = ReportCardDetail.fromJson(
      {
        'id': 'report',
        'sectionResults': [
          {
            'sectionId': 'module:science',
            'sectionKind': 'module',
            'name': 'Sciences',
            'comment': 'Overall progress',
            'weightingMode': 'explicit',
            'weight': 2.5,
            'average': 14,
            'subResults': [
              {
                'sectionId': 'subject:math',
                'sectionKind': 'subject',
                'classSubjectId': 'math',
                'name': 'Published mathematics',
                'coefficient': 3,
                'average': 14,
                'comment': 'Keep practicing',
              },
            ],
          },
        ],
        'revisedDraft': {'sectionResults': []},
      },
      periodName: 'Term',
      subjectNameByClassSubjectId: {'math': 'Renamed mathematics'},
    );
    expect(report.sections.single.comment, 'Overall progress');
    expect(report.sections.single.weight, 2.5);
    expect(report.sections.single.weightingMode, 'explicit');
    expect(
      report.sections.single.subjects.single.name,
      'Published mathematics',
    );
    expect(report.sections.single.subjects.single.coefficient, 3);
    expect(report.sections.single.subjects.single.comment, 'Keep practicing');
  });

  test(
    'same-name report sections retain identities and distinguish no score from zero',
    () {
      final report = ReportCardDetail.fromJson({
        'id': 'report',
        'sectionResults': [
          {
            'sectionId': 'first',
            'sectionKind': 'module',
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
            'sectionKind': 'module',
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
