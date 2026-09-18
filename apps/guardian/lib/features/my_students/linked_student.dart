class LinkedStudent {
  const LinkedStudent({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.status,
    this.schoolId = '',
    this.matricule,
    this.photoUrl,
  });

  factory LinkedStudent.fromJson(Map<String, dynamic> json) {
    return LinkedStudent(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      status: json['status'] as String? ?? 'active',
      schoolId: json['schoolId'] as String? ?? '',
      matricule: json['matricule'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String status;
  final String schoolId;
  final String? matricule;
  final String? photoUrl;

  String get fullName => '$firstName $lastName';

  String get initials {
    final first = firstName.trim().isNotEmpty ? firstName.trim()[0] : '';
    final last = lastName.trim().isNotEmpty ? lastName.trim()[0] : '';
    return '$first$last'.toUpperCase();
  }
}

class GuardianSchoolGroup {
  const GuardianSchoolGroup({
    required this.schoolId,
    required this.schoolName,
    required this.students,
  });

  final String schoolId;
  final String schoolName;
  final List<LinkedStudent> students;
}

List<GuardianSchoolGroup> groupStudentsBySchool({
  required List<LinkedStudent> students,
  required Map<String, String> schoolNames,
  String fallbackSchoolId = '',
}) {
  final bySchool = <String, List<LinkedStudent>>{};
  for (final student in students) {
    final schoolId = student.schoolId.isNotEmpty
        ? student.schoolId
        : fallbackSchoolId;
    bySchool
        .putIfAbsent(schoolId.isEmpty ? 'école' : schoolId, () => [])
        .add(student);
  }

  final ids = bySchool.keys.toList()
    ..sort((a, b) {
      return (schoolNames[a] ?? a).toLowerCase().compareTo(
        (schoolNames[b] ?? b).toLowerCase(),
      );
    });

  return [
    for (final id in ids)
      GuardianSchoolGroup(
        schoolId: id,
        schoolName: schoolNames[id] ?? id,
        students: [...bySchool[id]!]
          ..sort((a, b) => a.fullName.compareTo(b.fullName)),
      ),
  ];
}
