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
  // Grade periods cannot overlap. Use a new pupil in the existing class and period.
  final studentId = fixtureId('report-student');
  await client.registerStudent({
    'requestId': fixtureId('register-report-student'),
    'id': studentId,
    'schoolId': (await client.effectiveGrants()).schoolId,
    'firstName': 'Test',
    'lastName': studentId,
    'sendAccountInvitation': false,
  });
  await client.enrollStudent({
    'id': fixtureId('report-enrollment'),
    'classGroupId': classGroupId,
    'studentId': studentId,
    'enrolledAt': DateTime.utc(2026, 9, 1).toIso8601String(),
  });
  final periodId = template['periodId'] as String;
  return client.generateReportCardResult({
    'id': fixtureId('report'),
    'studentId': studentId,
    'periodId': periodId,
    if (template['reportCardDefinitionId'] != null)
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
  final periodId = periods.last['id'] as String;
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

/// Release the assignment/period slot without reusing another scenario's data.
Future<void> disposeFeedbackFixture(PortalSession owner, String id) async {
  if (!id.startsWith('ui-feedback-')) throw ArgumentError('Not a test fixture');
  final campaign = await owner.schoolClient.runQuery(
    'get-family-feedback-campaign',
    {'id': id},
  );
  if (campaign['status'] == 'archived') return;
  final command = ['published', 'cancelled'].contains(campaign['status'])
      ? 'archive-family-feedback-campaign'
      : 'cancel-family-feedback-campaign';
  await owner.schoolClient.runCommand(command, {
    'id': id,
    'requestId': fixtureId('feedback-cleanup'),
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
