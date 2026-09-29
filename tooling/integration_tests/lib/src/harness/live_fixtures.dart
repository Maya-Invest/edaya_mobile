import 'package:edaya_api_client/edaya_api_client.dart';
import 'portal_session.dart';

String fixtureId(String kind) =>
    'ui-$kind-${DateTime.now().microsecondsSinceEpoch}';

/// Mutable records belong to one scenario. Only school/catalog records are shared.
Future<Map<String, dynamic>> createReportCardFixture(
  PortalSession owner, {
  required String classGroupId,
  required String academicYearId,
}) async {
  final client = owner.schoolClient;
  final templates = await client.results.list({'classGroupId': classGroupId});
  if (templates.isEmpty) {
    throw StateError('Required report-card definition fixture missing');
  }
  final template = templates.first;
  final school = await client.effectiveGrants();
  final studentId = fixtureId('report-student');
  await client.registerStudent({
    'id': studentId,
    'schoolId': school.schoolId,
    'firstName': 'Integration',
    'lastName': studentId,
    'sendAccountInvitation': false,
    'createdAt': '2026-09-01T00:00:00.000Z',
  });
  await client.enrollStudent({
    'id': fixtureId('enrollment'),
    'studentId': studentId,
    'classGroupId': classGroupId,
    'createdAt': '2026-09-01T00:00:00.000Z',
  });
  return client.generateReportCardResult({
    'id': fixtureId('report'),
    'studentId': studentId,
    'periodId': template['periodId'],
    'reportCardDefinitionId': template['reportCardDefinitionId'],
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
  });
}

Future<Map<String, dynamic>> createFeedbackFixture(
  PortalSession owner, {
  required String teacherId,
  required String classGroupId,
  required String academicYearId,
}) async {
  final client = owner.schoolClient;
  final assignments = await client.teacherAssignments.list({
    'teacherId': teacherId,
    'kind': 'subject',
    'academicYearId': academicYearId,
  });
  final subjects = await client.classSubjects.list({
    'classGroupId': classGroupId,
  });
  final assignment = assignments
      .where(
        (row) =>
            subjects.any((subject) => subject['id'] == row['classSubjectId']),
      )
      .firstOrNull;
  if (assignment == null) {
    throw StateError('Required feedback teacher assignment missing');
  }
  final periods = await client.academicPeriods.list({
    'academicYearId': academicYearId,
  });
  if (periods.isEmpty) throw StateError('Required academic period missing');
  final periodId = fixtureId('feedback-period');
  await client.academicPeriods.save({
    ...periods.first,
    'id': periodId,
    'name': periodId,
  });
  final id = fixtureId('feedback');
  final moderator = (await client.effectiveGrants()).actorId;
  await client.runCommand('create-family-feedback-campaign', {
    'requestId': fixtureId('create'),
    'id': id,
    'academicYearId': academicYearId,
    'academicPeriodId': periodId,
    'teacherAssignmentId': assignment['id'],
    'moderatorStaffId': moderator,
  });
  return client.runCommand('open-family-feedback-campaign', {
    'requestId': fixtureId('open'),
    'id': id,
  });
}

Future<Map<String, dynamic>> createInboxFixture(
  PortalSession owner, {
  required String subjectId,
  required String actorId,
  required String actorKind,
}) async {
  final grants = await owner.schoolClient.effectiveGrants();
  final id = fixtureId('message');
  await owner.schoolClient.createAnnouncement({
    'id': id,
    'schoolId': grants.schoolId,
    'title': id,
    'content': 'Integration message body',
    'status': 'draft',
  });
  await owner.schoolClient.addTarget({
    'id': '$id-target',
    'announcementId': id,
    'targetKind': actorKind == 'teacher' ? 'school' : actorKind,
    if (actorKind != 'teacher') 'targetId': actorId,
  });
  await owner.schoolClient.publishAnnouncement({'announcementId': id});
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    final rows = await owner.schoolClient.messageDeliveries.list({
      'announcementId': id,
      'subjectId': subjectId,
    });
    final matched = rows.where(
      (row) =>
          row['recipientKind'] == actorKind && row['recipientId'] == actorId,
    );
    if (matched.isNotEmpty) return matched.single;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Required unread message delivery was not materialized');
}
