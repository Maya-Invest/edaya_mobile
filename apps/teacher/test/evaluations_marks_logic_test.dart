import 'package:edaya_teacher/features/evaluations/evaluations_marks_logic.dart';
import 'package:edaya_teacher/features/evaluations/models/evaluation_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldApplyMarksLoad', () {
    test(
      'rejects stale roster responses after a save invalidates generation',
      () {
        expect(shouldApplyMarksLoad(1, 2), isFalse);
      },
    );

    test('accepts roster responses for the active generation', () {
      expect(shouldApplyMarksLoad(2, 2), isTrue);
    });
  });

  group('applyStudentMark', () {
    final rows = [
      const StudentMarkRow(studentId: 's1', studentName: 'Ada'),
      const StudentMarkRow(studentId: 's2', studentName: 'Bob', score: 11),
    ];

    test('optimistically patches the target student score', () {
      final updated = applyStudentMark(
        rows,
        studentId: 's1',
        resultId: 'ar-asm-s1',
        score: 15,
      );

      expect(updated.first.score, 15);
      expect(updated.first.resultId, 'ar-asm-s1');
      expect(updated.last.score, 11);
    });

    test('reverts the target student when save fails', () {
      final optimistic = applyStudentMark(
        rows,
        studentId: 's1',
        resultId: 'ar-asm-s1',
        score: 15,
      );
      final reverted = applyStudentMark(
        optimistic,
        studentId: 's1',
        resultId: null,
        score: null,
      );

      expect(reverted.first.score, isNull);
      expect(reverted.first.resultId, isNull);
    });
  });

  group('patchEvaluationGradedCount', () {
    test('updates graded count from saved roster rows', () {
      const summary = EvaluationSummary(
        id: 'asm-1',
        title: 'Quiz',
        classGroupId: 'cg-1',
        classSubjectId: 'cs-1',
        periodId: 'p-1',
        classLabel: '6A',
        subjectLabel: 'Math',
        date: '2026-04-01',
        maxScore: 20,
        gradedCount: 0,
        totalStudents: 2,
      );

      final patched = patchEvaluationGradedCount(
        summaries: [summary],
        evaluationId: 'asm-1',
        students: const [
          StudentMarkRow(studentId: 's1', studentName: 'Ada', score: 14),
          StudentMarkRow(studentId: 's2', studentName: 'Bob'),
        ],
      );

      expect(patched.single.gradedCount, 1);
    });
  });

  group('teacher assessment visibility and grading gates', () {
    test('subject teachers only see assessments for assigned subjects', () {
      expect(
        shouldIncludeAssessmentForTeacher(
          classSubjectId: 'cs-math',
          taughtSubjectIds: {'cs-math'},
        ),
        isTrue,
      );
      expect(
        shouldIncludeAssessmentForTeacher(
          classSubjectId: 'cs-french',
          taughtSubjectIds: {'cs-math'},
        ),
        isFalse,
      );
    });

    test('subject teachers cannot input grades outside assigned subjects', () {
      expect(
        canInputGradeForSubject(
          classSubjectId: 'cs-french',
          taughtSubjectIds: {'cs-math'},
        ),
        isFalse,
      );
    });
  });
}
