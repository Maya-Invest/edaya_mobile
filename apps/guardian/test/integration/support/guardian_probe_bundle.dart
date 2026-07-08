import 'package:edaya_integration_tests/edaya_integration_tests.dart';

import 'guardian_widget_test_harness.dart';

/// API probes loaded once for guardian widget integration tests.
class GuardianProbeBundle {
  const GuardianProbeBundle({
    required this.academic,
    required this.fees,
    required this.calendar,
    required this.inbox,
    required this.attendance,
  });

  final GuardianAcademicProbe academic;
  final GuardianFeesProbe fees;
  final GuardianCalendarProbe calendar;
  final GuardianInboxProbe inbox;
  final List<Map<String, dynamic>> attendance;

  static Future<GuardianProbeBundle> load(GuardianWidgetTestHarness harness) async {
    final client = harness.portalSession.schoolClient;
    final profile = harness.profile;

    final academic = await loadGuardianAcademicData(
      client,
      studentId: profile.primaryStudentId,
      classGroupId: profile.primaryClassGroupId,
      academicYearId: profile.academicYearId,
    );
    final fees = await loadGuardianFeesData(
      client,
      studentId: profile.primaryStudentId,
      academicYearId: profile.academicYearId,
    );
    final calendar = await loadGuardianCalendarData(
      client,
      classGroupId: profile.primaryClassGroupId,
      academicYearId: profile.academicYearId,
    );
    final inbox = await loadGuardianInbox(
      client,
      inboxSubjectId: harness.context.inboxSubjectId,
    );
    final attendance = await loadGuardianAttendance(
      client,
      studentId: profile.primaryStudentId,
    );

    return GuardianProbeBundle(
      academic: academic,
      fees: fees,
      calendar: calendar,
      inbox: inbox,
      attendance: attendance,
    );
  }
}
