class LinkedStudent {
  const LinkedStudent({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.status,
    this.matricule,
  });

  factory LinkedStudent.fromJson(Map<String, dynamic> json) {
    return LinkedStudent(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      status: json['status'] as String? ?? 'active',
      matricule: json['matricule'] as String?,
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String status;
  final String? matricule;

  String get fullName => '$firstName $lastName';

  String get initials {
    final first = firstName.trim().isNotEmpty ? firstName.trim()[0] : '';
    final last = lastName.trim().isNotEmpty ? lastName.trim()[0] : '';
    return '$first$last'.toUpperCase();
  }
}
