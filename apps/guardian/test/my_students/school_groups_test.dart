import 'package:edaya_guardian/features/my_students/linked_student.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LinkedStudent student({
    required String id,
    required String schoolId,
    String first = 'A',
    String last = 'B',
  }) {
    return LinkedStudent(
      id: id,
      firstName: first,
      lastName: last,
      status: 'active',
      schoolId: schoolId,
    );
  }

  test('groups children by school and sorts school names', () {
    final groups = groupStudentsBySchool(
      students: [
        student(id: '2', schoolId: 'lycee', first: 'Yao', last: 'Koffi'),
        student(id: '1', schoolId: 'college', first: 'Amina', last: 'Koné'),
        student(id: '3', schoolId: 'college', first: 'Binta', last: 'Diallo'),
      ],
      schoolNames: {
        'college': 'Collège Moderne',
        'lycee': 'Lycée Sainte-Marie',
      },
    );

    expect(groups, hasLength(2));
    expect(groups.first.schoolName, 'Collège Moderne');
    expect(groups.first.students.map((s) => s.fullName), [
      'Amina Koné',
      'Binta Diallo',
    ]);
    expect(groups.last.schoolName, 'Lycée Sainte-Marie');
    expect(groups.last.students.single.fullName, 'Yao Koffi');
  });

  test('uses fallback school when student schoolId is missing', () {
    final groups = groupStudentsBySchool(
      students: [student(id: '1', schoolId: '')],
      schoolNames: {'sch-1': 'École Cocody'},
      fallbackSchoolId: 'sch-1',
    );

    expect(groups, hasLength(1));
    expect(groups.single.schoolId, 'sch-1');
    expect(groups.single.schoolName, 'École Cocody');
  });

  test('keeps one group when every child shares the same school', () {
    final groups = groupStudentsBySchool(
      students: [
        student(id: '1', schoolId: 'sch-1', first: 'Amina', last: 'Koné'),
        student(id: '2', schoolId: 'sch-1', first: 'Yao', last: 'Koffi'),
      ],
      schoolNames: {'sch-1': 'École Cocody'},
    );

    expect(groups, hasLength(1));
    expect(groups.single.schoolName, 'École Cocody');
    expect(groups.single.students, hasLength(2));
  });
}
