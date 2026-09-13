import 'package:edaya_shared/edaya_shared.dart';

EntityQuery publishedReportCardsForStudent(String studentId) {
  return {'studentId': studentId, 'status': 'published'};
}

EntityQuery studentFeesForStudent(String studentId) {
  return studentScope(studentId);
}

EntityQuery paymentsForStudentFees(List<String> studentFeeIds) {
  return recordsForField('studentFeeId', studentFeeIds);
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
