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

EntityQuery deliveriesForSubject(String subjectId) {
  return {'subjectId': subjectId};
}
