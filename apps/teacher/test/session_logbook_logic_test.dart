import 'package:edaya_teacher/features/session/models/session_detail_models.dart';
import 'package:edaya_teacher/features/session/session_logbook_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildSessionSubjectMatters', () {
    test('merges cumulative and session progress per matter', () {
      final matters = buildSessionSubjectMatters(
        matterLinks: const [
          {
            'id': 'csm-b',
            'subjectMatterId': 'sm-b',
            'status': 'not_started',
            'completedPercentage': 10,
          },
          {
            'id': 'csm-a',
            'subjectMatterId': 'sm-a',
            'status': 'in_progress',
            'completedPercentage': 40,
          },
        ],
        subjectMatters: const [
          {'id': 'sm-a', 'name': 'Fractions', 'sequenceOrder': 1},
          {'id': 'sm-b', 'name': 'Decimals', 'sequenceOrder': 2},
        ],
        sessionProgressRows: const [
          {
            'id': 'csp-1',
            'classSubjectMatterId': 'csm-a',
            'lessonSessionId': 'ls-1',
            'completedPercentage': 55,
            'notes': 'Worked examples',
            'recordedAt': '2026-04-01T10:00:00.000Z',
          },
        ],
        fallbackName: 'Chapter',
      );

      expect(matters, hasLength(2));
      expect(matters.first.name, 'Fractions');
      expect(matters.first.cumulativePercentage, 40);
      expect(matters.first.sessionProgress?.completedPercentage, 55);
      expect(matters.first.sessionProgress?.notes, 'Worked examples');
      expect(matters.last.sessionProgress, isNull);
    });
  });

  group('minMatterProgressPercentage', () {
    test('uses session snapshot when present', () {
      const matter = SessionSubjectMatterOption(
        id: 'csm-a',
        name: 'Fractions',
        sequenceOrder: 1,
        status: ClassSubjectMatterStatus.inProgress,
        cumulativePercentage: 40,
        sessionProgress: SessionMatterProgress(
          id: 'csp-1',
          classSubjectMatterId: 'csm-a',
          completedPercentage: 55,
        ),
      );

      expect(minMatterProgressPercentage(matter), 55);
    });

    test('falls back to cumulative aggregate for new records', () {
      const matter = SessionSubjectMatterOption(
        id: 'csm-a',
        name: 'Fractions',
        sequenceOrder: 1,
        status: ClassSubjectMatterStatus.notStarted,
        cumulativePercentage: 25,
      );

      expect(minMatterProgressPercentage(matter), 25);
    });
  });

  group('recordedSessionMatters / pickableSessionMatters', () {
    final matters = [
      const SessionSubjectMatterOption(
        id: 'csm-a',
        name: 'Fractions',
        sequenceOrder: 1,
        status: ClassSubjectMatterStatus.inProgress,
        cumulativePercentage: 40,
        sessionProgress: SessionMatterProgress(
          id: 'csp-1',
          classSubjectMatterId: 'csm-a',
          completedPercentage: 55,
        ),
      ),
      const SessionSubjectMatterOption(
        id: 'csm-b',
        name: 'Decimals',
        sequenceOrder: 2,
        status: ClassSubjectMatterStatus.notStarted,
        cumulativePercentage: 0,
      ),
    ];

    test('splits recorded and pickable matters', () {
      expect(recordedSessionMatters(matters), hasLength(1));
      expect(recordedSessionMatters(matters).first.name, 'Fractions');
      expect(pickableSessionMatters(matters), hasLength(1));
      expect(pickableSessionMatters(matters).first.name, 'Decimals');
    });
  });

  group('recordLessonProgressPayload', () {
    test('omits blank notes', () {
      final payload = recordLessonProgressPayload(
        id: 'csp-1',
        classSubjectMatterId: 'csm-a',
        lessonSessionId: 'ls-1',
        completedPercentage: 60,
        notes: '   ',
        recordedAt: DateTime.utc(2026, 4, 1, 10),
      );

      expect(payload.containsKey('notes'), isFalse);
      expect(payload['completedPercentage'], 60);
    });
  });
}
