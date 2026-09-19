import 'package:edaya_guardian/features/scolarite/models/grade_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GradeEntry reads score and startsAt from assessment payloads', () {
    final entry = GradeEntry.fromMaps(
      result: {'id': 'ar-1', 'score': 14},
      assessment: {
        'id': 'asm-1',
        'title': 'Évaluation — nombres',
        'periodId': 't1',
        'startsAt': '2026-11-16T09:00:00.000Z',
        'maxScore': 20,
        'coefficient': 2,
      },
      subjectName: 'Maths',
      periodName: 'Trimestre 1',
    );

    expect(entry.score, 14);
    expect(entry.hasScore, isTrue);
    expect(entry.date, DateTime.utc(2026, 11, 16, 9));
    expect(entry.maxScore, 20);
    expect(entry.coefficient, 2);
  });

  test('GradeEntry parses string scores from API payloads', () {
    final entry = GradeEntry.fromMaps(
      result: {'id': 'ar-2', 'score': '12.5'},
      assessment: {
        'id': 'asm-2',
        'title': 'Dictée',
        'periodId': 't1',
        'startsAt': '2026-11-16T09:00:00.000Z',
      },
      subjectName: 'Français',
      periodName: 'Trimestre 1',
    );

    expect(entry.score, 12.5);
    expect(entry.hasScore, isTrue);
  });
}
