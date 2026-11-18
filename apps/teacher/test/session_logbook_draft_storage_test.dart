import 'dart:convert';

import 'package:edaya_teacher_v2/features/session/session_logbook_draft_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'teacher_logbook_draft_unscoped_lesson';
  test(
    'keeps conflicting local and queued drafts in review order across a restart',
    () async {
      SharedPreferences.setMockInitialValues({});
      const local = LogbookEdit.chapter('a', false, chapterNotes: 'Local');
      const older = LogbookEdit.chapter(
        'a',
        true,
        chapterNotes: 'Queued',
        needsReview: true,
      );
      const latest = LogbookEdit.chapter(
        'a',
        false,
        chapterNotes: 'Later queue',
        needsReview: true,
      );
      final drafts = SessionLogbookDraftStorage.mergeRecovered(
        {local.key: local},
        {older.key: older},
        'one',
      );
      final queued = SessionLogbookDraftStorage.mergeRecovered(drafts, {
        latest.key: latest,
      }, 'two');
      final repeated = SessionLogbookDraftStorage.mergeRecovered(queued, {
        older.key: older,
      }, 'one');
      await SessionLogbookDraftStorage.save('lesson', null, 1, null, repeated);
      var remaining = await SessionLogbookDraftStorage.load(
        'lesson',
        null,
        1,
        null,
      );
      for (final note in ['Local', 'Queued', 'Later queue']) {
        expect(remaining[local.key]!.chapterNotes, note);
        remaining = SessionLogbookDraftStorage.resolveSection(
          remaining,
          local.key,
        );
      }
      expect(remaining, isEmpty);
    },
  );
  test(
    'recovers notes, ambiguous completion and reason from combined drafts',
    () async {
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'revision': 2,
          'proposalVersion': 4,
          'sessionNote': 'Fractions',
          'objectives': 'Compare halves',
          'familySummary': 'Homework',
          'correctionReason': 'Checked notes',
          'progressEntries': [
            {'matterId': 'a', 'completedPercentage': 100},
            {'matterId': 'b', 'completedPercentage': 30},
          ],
        }),
      });
      final drafts = await SessionLogbookDraftStorage.load(
        'lesson',
        null,
        2,
        4,
      );
      expect(drafts['general']!.note!.familySummary, 'Homework');
      expect(drafts['chapter:a']!.needsReview, isTrue);
      expect(drafts['chapter:b']!.completed, false);
      expect(drafts['chapter:b']!.reason, 'Checked notes');
      await SessionLogbookDraftStorage.save('lesson', null, 2, 4, drafts);
      final reopened = await SessionLogbookDraftStorage.load(
        'lesson',
        null,
        3,
        5,
      );
      expect(reopened['general']!.needsReview, isTrue);
    },
  );
  test(
    'preserves a stale zero-percent section and a queued section removal',
    () async {
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'revision': 1,
          'sections': {
            'chapter:a': {'chapterId': 'a', 'percentage': 0},
          },
        }),
      });
      final drafts = await SessionLogbookDraftStorage.load(
        'lesson',
        null,
        3,
        null,
      );
      expect(drafts['chapter:a']!.completed, false);
      expect(drafts['chapter:a']!.needsReview, isTrue);
      final queued = SessionLogbookDraftStorage.fromQueued({
        'section': 'chapter:a',
        'body': {
          'proposal': {'progress': []},
          'reason': 'Wrong lesson',
        },
      });
      expect(queued['chapter:a']!.removed, isTrue);
      expect(queued['chapter:a']!.reason, 'Wrong lesson');
    },
  );
}
