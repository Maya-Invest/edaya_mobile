/// Only years in this pupil's enrollment history can be selected.
List<Map<String, dynamic>> pupilEnrollmentYears(
  Iterable<Map<String, dynamic>> years,
  Iterable<Map<String, dynamic>> enrollments,
  String studentId,
) {
  final ids = enrollments
      .where((e) => e['studentId'] == studentId)
      .map((e) => e['academicYearId'])
      .toSet();
  return years.where((y) => ids.contains(y['id'])).toList()..sort(
    (a, b) => '${b['startDate'] ?? b['name'] ?? ''}'.compareTo(
      '${a['startDate'] ?? a['name'] ?? ''}',
    ),
  );
}

String? defaultPupilYear(List<Map<String, dynamic>> years) =>
    (years.where((y) => y['status'] == 'published').firstOrNull ??
            years.firstOrNull)?['id']
        as String?;
