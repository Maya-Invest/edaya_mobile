import 'package:edaya_teacher_v2/features/context/academic_year_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher uses published year even when a future draft sorts first', () {
    final selected = publishedTeacherYear([
      {'id': 'future', 'name': '2027–2028', 'status': 'draft'},
      {'id': 'current', 'name': '2026–2027', 'status': 'published'},
      {'id': 'past', 'name': '2025–2026', 'status': 'archived'},
    ]);
    expect(selected?['id'], 'current');
  });
  test('teacher never falls back to a draft or archived school year', () {
    expect(
      publishedTeacherYear([
        {'id': 'future', 'status': 'draft'},
        {'id': 'past', 'status': 'archived'},
      ]),
      isNull,
    );
    expect(publishedTeacherYear([]), isNull);
  });
}
