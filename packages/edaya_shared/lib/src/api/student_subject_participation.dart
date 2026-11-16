import 'package:edaya_shared/src/demo/school_clock.dart';
import 'package:edaya_api_client/edaya_api_client.dart';

/// Child-specific current selections; shared family scopes may contain several siblings.
class StudentSubjectParticipation {
  StudentSubjectParticipation(this.intervals, this.offerings);
  final List<Map<String, dynamic>> intervals;
  final List<Map<String, dynamic>> offerings;

  bool includes(String? classSubjectId, DateTime at) => intervals.any((row) {
    if (row['classSubjectId'] != classSubjectId || row['deletedAt'] != null)
      return false;
    final start = DateTime.parse(row['enrolledAt'] as String);
    final end = row['endedAt'] == null
        ? null
        : DateTime.parse(row['endedAt'] as String);
    if (at.isBefore(start) || (end != null && !at.isBefore(end))) return false;
    if (row['scope'] != 'periods') return true;
    return (row['periods'] as List).any((choice) {
      final activation = DateTime.parse(choice['activatedAt'] as String);
      final periodStart = DateTime.parse(choice['startsAt'] as String);
      final periodEnd = DateTime.parse(choice['endsAt'] as String);
      return !at.isBefore(activation) &&
          !at.isBefore(periodStart) &&
          at.isBefore(periodEnd);
    });
  });

  List<Map<String, dynamic>> currentSubjects([DateTime? at]) => offerings
      .where((row) => includes(row['id'] as String?, at ?? SchoolClock.now()))
      .toList();

  static Future<StudentSubjectParticipation> load(
    SchoolClient client,
    String studentId,
  ) async {
    final data = await client.getStudentSubjectEnrollments({
      'studentId': studentId,
    });
    return StudentSubjectParticipation(
      (data['enrollments'] as List).cast<Map<String, dynamic>>(),
      (data['offerings'] as List).cast<Map<String, dynamic>>(),
    );
  }
}
