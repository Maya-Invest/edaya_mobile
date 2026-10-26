import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edaya_teacher/features/report_cards/report_card_comment_draft_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'round trips stable section identities with the base report version',
    () async {
      SharedPreferences.setMockInitialValues({});
      final draft = ReportCardCommentDraft(
        commentsBySectionId: {
          'module:sciences': 'Good progress',
          'subject:math': 'Keep practicing',
        },
        updatedAt: DateTime.utc(2026, 10, 26),
        baseVersion: 7,
      );
      await ReportCardCommentDraftStorage.save(
        resultId: 'report',
        studentId: 'student',
        draft: draft,
      );
      final loaded = await ReportCardCommentDraftStorage.load(
        resultId: 'report',
        studentId: 'student',
      );
      expect(loaded!.baseVersion, 7);
      expect(loaded.commentsBySectionId, draft.commentsBySectionId);
      await ReportCardCommentDraftStorage.clear(
        resultId: 'report',
        studentId: 'student',
      );
      expect(
        await ReportCardCommentDraftStorage.load(
          resultId: 'report',
          studentId: 'student',
        ),
        isNull,
      );
    },
  );
  test(
    'does not restore legacy section drafts or malformed versioned drafts',
    () async {
      SharedPreferences.setMockInitialValues({
        'teacher_report_comment_report_student': jsonEncode({
          'commentsBySectionId': {'old-template-section': 'Old'},
        }),
        'teacher_report_comment_v2_report_student': jsonEncode({
          'formatVersion': 1,
          'baseVersion': 3,
        }),
      });
      expect(
        await ReportCardCommentDraftStorage.load(
          resultId: 'report',
          studentId: 'student',
        ),
        isNull,
      );
    },
  );
}
