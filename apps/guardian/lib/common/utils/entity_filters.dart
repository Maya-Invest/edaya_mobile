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

EntityQuery deliveriesForSubject(String subjectId) {
  return {'subjectId': subjectId};
}
