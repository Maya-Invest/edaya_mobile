import '../my_students/linked_student.dart';

/// A single read authorized for this account and guardian profile.
class GuardianChoices {
  GuardianChoices.fromJson(Map<String, dynamic> data, {required this.accountId})
    : guardianId = data['guardianId'] as String,
      schoolId = data['school']['id'] as String,
      schoolName = data['school']['name'] as String,
      timeZone = data['school']['timeZone'] as String,
      children = (data['children'] as List)
          .cast<Map<String, dynamic>>()
          .map(LinkedStudent.fromJson)
          .toList(),
      years = (data['years'] as List).cast<Map<String, dynamic>>(),
      enrollments = (data['enrollments'] as List).cast<Map<String, dynamic>>();

  final String? accountId;
  final String guardianId, schoolId, schoolName, timeZone;
  final List<LinkedStudent> children;
  final List<Map<String, dynamic>> years, enrollments;
}
