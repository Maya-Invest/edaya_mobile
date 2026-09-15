import 'package:edaya_shared/edaya_shared.dart';

EntityQuery publishedReportCardsForStudent(String studentId) {
  return {'studentId': studentId, 'status': 'published'};
}

EntityQuery studentChargesForStudent({
  required String studentId,
  required String academicYearId,
}) {
  return {'studentId': studentId, 'academicYearId': academicYearId};
}

EntityQuery deliveriesForGuardian({
  required String subjectId,
  required String guardianId,
  required String schoolId,
}) {
  return {
    'subjectId': subjectId,
    'recipientKind': 'guardian',
    'recipientId': guardianId,
    'schoolId': schoolId,
  };
}
