import 'package:edaya_teacher/features/teaching/models/teaching_models.dart';
import 'package:edaya_teacher/features/teaching/teaching_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildTeachingClassSubjectOptions', () {
    test('sorts by label and resolves subject names', () {
      final options = buildTeachingClassSubjectOptions(
        classSubjectRows: [
          {
            'id': 'cs-b',
            'classGroupId': 'cg-6a',
            'subjectId': 'sub-b',
          },
          {
            'id': 'cs-a',
            'classGroupId': 'cg-6a',
            'subjectId': 'sub-a',
          },
        ],
        subjectNameById: {
          'sub-a': 'Maths',
          'sub-b': 'French',
        },
        classLabelById: {'cg-6a': '6ème A'},
        subjectFallback: 'Subject',
      );

      expect(options, hasLength(2));
      expect(options.first.id, 'cs-b');
      expect(options.first.label, '6ème A · French');
      expect(options.last.id, 'cs-a');
      expect(options.last.subjectName, 'Maths');
    });
  });

  group('buildTeachingProgressOverview', () {
    test('maps matter links and sorts by sequence order', () {
      final overview = buildTeachingProgressOverview(
        classSubject: {'completedPercentage': 42},
        matterLinks: [
          {
            'id': 'link-2',
            'subjectMatterId': 'sm-2',
            'status': 'in_progress',
            'completedPercentage': 50,
            'notes': 'Half done',
          },
          {
            'id': 'link-1',
            'subjectMatterId': 'sm-1',
            'status': 'completed',
            'completedPercentage': 100,
          },
        ],
        subjectMatters: [
          {'id': 'sm-1', 'name': 'Chapter 1', 'sequenceOrder': 1},
          {'id': 'sm-2', 'name': 'Chapter 2', 'sequenceOrder': 2},
        ],
        matterFallback: 'Chapter',
      );

      expect(overview.classSubjectCompletedPercentage, 42);
      expect(overview.matters, hasLength(2));
      expect(overview.matters.first.name, 'Chapter 1');
      expect(overview.matters.first.status, TeachingMatterStatus.completed);
      expect(overview.matters.last.notes, 'Half done');
    });
  });

  group('buildTeachingLogEntries', () {
    test('joins session notes and progress snapshots', () {
      final entries = buildTeachingLogEntries(
        lessonSessions: [
          {
            'id': 'ls-1',
            'classGroupId': 'cg-6a',
            'classSubjectId': 'cs-maths',
            'displayLabel': 'Maths',
            'startsAt': '2025-09-10T08:00:00.000Z',
            'endsAt': '2025-09-10T09:00:00.000Z',
            'sessionNote': 'Intro lesson',
          },
        ],
        progressRows: [
          {
            'lessonSessionId': 'ls-1',
            'classSubjectMatterId': 'link-1',
            'completedPercentage': 25,
            'notes': 'Started',
          },
        ],
        matterLinks: [
          {'id': 'link-1', 'subjectMatterId': 'sm-1'},
        ],
        subjectMatters: [
          {'id': 'sm-1', 'name': 'Algebra'},
        ],
        classLabel: '6ème A',
        subjectLabel: 'Maths',
        matterFallback: 'Chapter',
      );

      expect(entries, hasLength(1));
      expect(entries.first.sessionNote, 'Intro lesson');
      expect(entries.first.matterSnapshots.first.matterName, 'Algebra');
      expect(entries.first.hasContent, isTrue);
    });
  });
}
