import 'package:edaya_api_client/edaya_api_client.dart' hide EntityQuery;

import '../config/guardian_portal_profile.dart';
import 'portal_session.dart';
import 'teacher_portal_harness.dart';

/// Resolved state after mirroring the guardian app bootstrap chain.
class GuardianPortalContext {
  const GuardianPortalContext({
    required this.profile,
    required this.grants,
    required this.academicYears,
    required this.linkedStudentIds,
    required this.linkedStudents,
    required this.primaryEnrollment,
    required this.primaryClassGroup,
    required this.guardianProfile,
    required this.inboxSubjectId,
    required this.authUserId,
  });

  final GuardianPortalProfile profile;
  final EffectiveGrantsResponse grants;
  final List<Map<String, dynamic>> academicYears;
  final List<String> linkedStudentIds;
  final List<Map<String, dynamic>> linkedStudents;
  final Map<String, dynamic> primaryEnrollment;
  final Map<String, dynamic> primaryClassGroup;
  final Map<String, dynamic> guardianProfile;
  final String inboxSubjectId;
  final String authUserId;
}

class GuardianAcademicProbe {
  const GuardianAcademicProbe({
    required this.academicPeriods,
    required this.classSubjects,
    required this.subjects,
    required this.assessments,
    required this.assessmentResults,
    required this.classSubjectMatters,
    required this.subjectMatters,
    required this.reportCards,
  });

  final List<Map<String, dynamic>> academicPeriods;
  final List<Map<String, dynamic>> classSubjects;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> assessments;
  final List<Map<String, dynamic>> assessmentResults;
  final List<Map<String, dynamic>> classSubjectMatters;
  final List<Map<String, dynamic>> subjectMatters;
  final List<Map<String, dynamic>> reportCards;
}

class GuardianFeesProbe {
  const GuardianFeesProbe({
    required this.studentFees,
    required this.payments,
    required this.feeNamesById,
  });

  final List<Map<String, dynamic>> studentFees;
  final List<Map<String, dynamic>> payments;
  final Map<String, String> feeNamesById;
}

class GuardianCalendarProbe {
  const GuardianCalendarProbe({
    required this.timetableEvents,
    required this.calendarEvents,
  });

  final List<dynamic> timetableEvents;
  final List<Map<String, dynamic>> calendarEvents;
}

class GuardianInboxProbe {
  const GuardianInboxProbe({
    required this.deliveries,
    required this.unreadDeliveryId,
  });

  final List<Map<String, dynamic>> deliveries;
  final String? unreadDeliveryId;
}

EntityQuery guardianLinksForGuardian(String guardianId) {
  return {'guardianId': guardianId};
}

EntityQuery activeEnrollmentForStudent({
  required String studentId,
  required String academicYearId,
}) {
  return {
    'studentId': studentId,
    'academicYearId': academicYearId,
    'status': 'active',
  };
}

EntityQuery publishedReportCardsForStudent(String studentId) {
  return {
    'studentId': studentId,
    'status': 'published',
  };
}

EntityQuery studentFeesForStudent(String studentId) {
  return {'studentId': studentId};
}

EntityQuery paymentsForStudentFees(List<String> studentFeeIds) {
  return recordsForField('studentFeeId', studentFeeIds);
}

EntityQuery deliveriesForSubject(String subjectId) {
  return {'subjectId': subjectId};
}

EntityQuery attendanceForStudent(String studentId) {
  return {'studentId': studentId};
}

EntityQuery classGroupScope(String classGroupId) {
  return {'classGroupId': classGroupId};
}

EntityQuery academicYearScope(String academicYearId) {
  return {'academicYearId': academicYearId};
}

EntityQuery recordsForField(String field, List<String> ids) {
  if (ids.isEmpty) {
    return {
      field: {'\$in': ['__no_match__']},
    };
  }
  return {
    field: {'\$in': ids},
  };
}

Future<List<String>> loadGuardianLinkedStudentIds(
  SchoolClient client,
  String guardianId,
) async {
  final links = await client.guardianLinks.list(guardianLinksForGuardian(guardianId));
  final ids = <String>{};
  for (final link in links) {
    final studentId = link['studentId'] as String?;
    if (studentId != null && studentId.isNotEmpty) {
      ids.add(studentId);
    }
  }
  return ids.toList()..sort();
}

Future<String> resolveGuardianInboxSubjectId({
  required SchoolClient client,
  required String guardianId,
  required String authUserId,
}) async {
  final guardian = await client.guardians.get(guardianId);
  final subjectId = guardian['subjectId'] as String?;
  if (subjectId != null && subjectId.isNotEmpty) {
    return subjectId;
  }
  return authUserId;
}

/// Mirrors guardian login bootstrap:
/// grants → guardian links → academic years → active student enrollment.
Future<GuardianPortalContext> bootstrapGuardianPortal(
  PortalSession session,
  GuardianPortalProfile profile,
) async {
  final client = session.schoolClient;
  final grants = await client.effectiveGrants();
  final authSession = await session.authClient.getSession();
  final authUserId = authSession.data?.user.id ?? '';

  final linkedStudentIds = await loadGuardianLinkedStudentIds(
    client,
    grants.actorId,
  );
  if (linkedStudentIds.isEmpty) {
    throw StateError('guardian ${grants.actorId} has no linked students');
  }

  final linkedStudents = await client.students.list(entitiesByIds(linkedStudentIds));
  final academicYears = await client.academicYears.list();
  final guardianProfile = await client.guardians.get(grants.actorId);
  final inboxSubjectId = await resolveGuardianInboxSubjectId(
    client: client,
    guardianId: grants.actorId,
    authUserId: authUserId,
  );

  final enrollments = await client.enrollments.list(
    activeEnrollmentForStudent(
      studentId: profile.primaryStudentId,
      academicYearId: profile.academicYearId,
    ),
  );
  if (enrollments.isEmpty) {
    throw StateError(
      'student ${profile.primaryStudentId} has no active enrollment for ${profile.academicYearId}',
    );
  }

  final primaryEnrollment = enrollments.first;
  final classGroupId = primaryEnrollment['classGroupId'] as String;
  final primaryClassGroup = await client.classGroups.get(classGroupId);

  return GuardianPortalContext(
    profile: profile,
    grants: grants,
    academicYears: academicYears,
    linkedStudentIds: linkedStudentIds,
    linkedStudents: linkedStudents,
    primaryEnrollment: primaryEnrollment,
    primaryClassGroup: primaryClassGroup,
    guardianProfile: guardianProfile,
    inboxSubjectId: inboxSubjectId,
    authUserId: authUserId,
  );
}

/// Mirrors [AcademicController.loadAcademicData].
Future<GuardianAcademicProbe> loadGuardianAcademicData(
  SchoolClient client, {
  required String studentId,
  required String classGroupId,
  required String academicYearId,
}) async {
  final academicPeriods = await client.academicPeriods.list(
    academicYearScope(academicYearId),
  );
  final classSubjects = await client.classSubjects.list(
    classGroupScope(classGroupId),
  );
  final subjectIds = classSubjects
      .map((row) => row['subjectId'] as String?)
      .whereType<String>()
      .toSet()
      .toList();
  final subjects = subjectIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.subjects.list(entitiesByIds(subjectIds));

  final assessments = await client.assessments.list(classGroupScope(classGroupId));
  final assessmentIds = assessments.map((row) => row['id'] as String).toList();
  final assessmentResults = assessmentIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.assessmentResults.list({
          'studentId': studentId,
          ...recordsForField('assessmentId', assessmentIds),
        });

  final classSubjectIds = classSubjects.map((row) => row['id'] as String).toList();
  final classSubjectMatters = classSubjectIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.classSubjectMatters.list(
          recordsForField('classSubjectId', classSubjectIds),
        );
  final subjectMatterIds = classSubjectMatters
      .map((row) => row['subjectMatterId'] as String?)
      .whereType<String>()
      .toSet()
      .toList();
  final subjectMatters = subjectMatterIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.subjectMatters.list(entitiesByIds(subjectMatterIds));

  final reportCards = await client.results.list(
    publishedReportCardsForStudent(studentId),
  );

  return GuardianAcademicProbe(
    academicPeriods: academicPeriods,
    classSubjects: classSubjects,
    subjects: subjects,
    assessments: assessments,
    assessmentResults: assessmentResults,
    classSubjectMatters: classSubjectMatters,
    subjectMatters: subjectMatters,
    reportCards: reportCards,
  );
}

/// Mirrors [FeesController.loadFeesData].
Future<GuardianFeesProbe> loadGuardianFeesData(
  SchoolClient client, {
  required String studentId,
  required String academicYearId,
}) async {
  final studentFees = (await client.studentFees.list(studentFeesForStudent(studentId)))
      .where((row) => row['academicYearId'] == academicYearId)
      .where((row) => row['status'] != 'cancelled')
      .toList();

  final studentFeeIds = studentFees.map((row) => row['id'] as String).toList();
  final payments = studentFeeIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.payments.list(paymentsForStudentFees(studentFeeIds));

  final feeIds = studentFees
      .map((row) => row['feeId'] as String?)
      .whereType<String>()
      .toSet()
      .toList();
  final feeNamesById = <String, String>{};
  for (final feeId in feeIds) {
    final fee = await client.fees.get(feeId);
    feeNamesById[feeId] = fee['name'] as String? ?? feeId;
  }

  return GuardianFeesProbe(
    studentFees: studentFees,
    payments: payments,
    feeNamesById: feeNamesById,
  );
}

/// Mirrors [CalendarController.loadCalendarData] reads.
Future<GuardianCalendarProbe> loadGuardianCalendarData(
  SchoolClient client, {
  required String classGroupId,
  required String academicYearId,
}) async {
  final timetableByClass = await loadCalendarTimetables(client, [classGroupId]);
  final timetableEvents = timetableByClass[classGroupId] ?? const [];
  await loadTimetableEnrichment(
    client,
    classGroupId: classGroupId,
    academicYearId: academicYearId,
    events: timetableEvents,
  );

  final calendarEvents = await client.calendarEvents.list(
    academicYearScope(academicYearId),
  );

  return GuardianCalendarProbe(
    timetableEvents: timetableEvents,
    calendarEvents: calendarEvents,
  );
}

/// Mirrors [InboxController.loadInbox] using the guardian notification subject id.
Future<GuardianInboxProbe> loadGuardianInbox(
  SchoolClient client, {
  required String inboxSubjectId,
}) async {
  final deliveries = await client.messageDeliveries.list(
    deliveriesForSubject(inboxSubjectId),
  );

  String? unreadDeliveryId;
  for (final delivery in deliveries) {
    final status = delivery['status'] as String?;
    if (status == 'sent' || status == 'pending') {
      unreadDeliveryId = delivery['id'] as String?;
      break;
    }
  }

  return GuardianInboxProbe(
    deliveries: deliveries,
    unreadDeliveryId: unreadDeliveryId,
  );
}

/// Mirrors [AttendanceListController.loadAttendance].
Future<List<Map<String, dynamic>>> loadGuardianAttendance(
  SchoolClient client, {
  required String studentId,
}) async {
  return client.attendance.list(attendanceForStudent(studentId));
}

/// Mirrors [MessageDetailsController.markAsReadIfNeeded].
Future<void> probeGuardianMarkDeliveryRead(
  SchoolClient client, {
  required String deliveryId,
}) async {
  final result = await client.markDeliveryRead({
    'deliveryId': deliveryId,
  });
  if (result['status'] != 'read') {
    throw StateError('markDeliveryRead did not set status to read for $deliveryId');
  }

  final deliveryIdFromResult = result['id'] as String?;
  if (deliveryIdFromResult != deliveryId) {
    throw StateError('markDeliveryRead returned unexpected delivery id');
  }
}

/// Guardians must not create assessments.
Future<void> expectGuardianCannotCreateAssessment(
  SchoolClient client, {
  required String classGroupId,
  required String classSubjectId,
  required String periodId,
}) async {
  final asmId = 'asm-guardian-probe-${DateTime.now().millisecondsSinceEpoch}';
  final now = DateTime.now().toUtc();
  try {
    await client.createAssessment({
      'id': asmId,
      'classGroupId': classGroupId,
      'classSubjectId': classSubjectId,
      'periodId': periodId,
      'title': 'Guardian probe',
      'kind': 'quiz',
      'maxScore': 20,
      'coefficient': 1,
      'attachments': <Map<String, dynamic>>[],
      'createdAt': now.toIso8601String(),
      'startsAt': now.toIso8601String(),
      'endsAt': now.add(const Duration(hours: 1)).toIso8601String(),
    });
    throw StateError('guardian must not create assessments');
  } on ApiError catch (error) {
    if (error.status != 403) {
      rethrow;
    }
  }
}
