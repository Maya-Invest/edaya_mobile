import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_guardian_legacy/features/academic/models/report_card_summary.dart';

void main() {
  group('ReportCardDetail.fromJson', () {
    test('keeps one section per sectionId and dedupes subjects', () {
      final detail = ReportCardDetail.fromJson(
        {
          'id': 'rc-1',
          'sectionResults': [
            {
              'sectionId': 'grp-1',
              'sectionKind': 'group',
              'name': 'Matières fondamentales',
              'average': 14,
              'subResults': [
                {
                  'sectionId': 'subj-fr',
                  'sectionKind': 'subject',
                  'name': 'ci-subj-fr',
                  'average': 14,
                  'classSubjectId': 'cs-fr',
                  'subResults': [],
                },
                {
                  'sectionId': 'subj-fr-dup',
                  'sectionKind': 'subject',
                  'name': 'ci-subj-fr',
                  'average': 14,
                  'classSubjectId': 'cs-fr',
                  'subResults': [],
                },
              ],
            },
            {
              'sectionId': 'grp-1',
              'sectionKind': 'group',
              'name': 'Matières fondamentales',
              'average': 14,
              'subResults': [],
            },
            {
              'sectionId': 'grp-empty',
              'sectionKind': 'group',
              'name': 'Synthèse',
              'average': 0,
              'subResults': [],
            },
          ],
        },
        periodName: 'Trimestre 1',
        subjectNameByClassSubjectId: const {'cs-fr': 'Français'},
      );

      expect(detail.sections, hasLength(1));
      expect(detail.sections.first.name, 'Matières fondamentales');
      expect(detail.sections.first.subjects, hasLength(1));
      expect(detail.sections.first.subjects.first.name, 'Français');
    });

    test('dedupes repeated section names with different sectionIds', () {
      Map<String, dynamic> fondSection(String sectionId) => {
        'sectionId': sectionId,
        'sectionKind': 'group',
        'name': 'Matières fondamentales',
        'average': 15,
        'subResults': [
          {
            'sectionId': '$sectionId-fr',
            'sectionKind': 'subject',
            'name': 'ci-subj-fr',
            'average': 15,
            'classSubjectId': 'cs-fr',
            'subResults': [],
          },
          {
            'sectionId': '$sectionId-math',
            'sectionKind': 'subject',
            'name': 'ci-subj-math',
            'average': 15,
            'classSubjectId': 'cs-math',
            'subResults': [],
          },
        ],
      };

      final detail = ReportCardDetail.fromJson(
        {
          'id': 'rc-1',
          'sectionResults': [
            fondSection('grp-1'),
            fondSection('grp-2'),
            fondSection('grp-3'),
          ],
        },
        periodName: 'Trimestre 1',
        subjectNameByClassSubjectId: const {
          'cs-fr': 'Français',
          'cs-math': 'Mathématiques',
        },
      );

      expect(detail.sections, hasLength(1));
      expect(detail.sections.first.subjects, hasLength(2));
    });
  });
}
