import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_guardian/features/scolarite/models/grade_entry.dart';
import 'package:edaya_guardian/features/scolarite/models/report_card_summary.dart';
import 'package:edaya_guardian/features/calendar/models/calendar_session.dart';
import 'package:edaya_guardian/features/fees/models/payment_record.dart';
import 'package:edaya_guardian/features/inbox/models/inbox_delivery.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';

import 'guardian_widget_test_harness.dart';

class GuardianCalendarSessionProbe {
  const GuardianCalendarSessionProbe({
    required this.sessionTitle,
    required this.subjectLabel,
    required this.sessionDay,
  });

  final String sessionTitle;
  final String subjectLabel;
  final DateTime sessionDay;
}

class GuardianStudentSwitchProbe {
  const GuardianStudentSwitchProbe({
    required this.alternateStudentId,
    required this.alternateStudentName,
  });

  final String alternateStudentId;
  final String alternateStudentName;
}

/// API probes loaded once for guardian widget integration tests.
class GuardianProbeBundle {
  const GuardianProbeBundle({
    required this.academic,
    required this.fees,
    required this.calendar,
    required this.inbox,
    required this.attendance,
    required this.sessionProbe,
    required this.studentSwitchProbe,
    required this.firstGradedAssessmentTitle,
    required this.firstSubjectMatterName,
    required this.firstGradedEntry,
    required this.firstPayment,
    required this.firstInboxDelivery,
    required this.calendarSession,
    required this.firstReportCardSummary,
  });

  final GuardianAcademicProbe academic;
  final GuardianFeesProbe fees;
  final GuardianCalendarProbe calendar;
  final GuardianInboxProbe inbox;
  final List<Map<String, dynamic>> attendance;
  final GuardianCalendarSessionProbe? sessionProbe;
  final GuardianStudentSwitchProbe? studentSwitchProbe;
  final String? firstGradedAssessmentTitle;
  final String? firstSubjectMatterName;
  final GradeEntry? firstGradedEntry;
  final PaymentRecord? firstPayment;
  final InboxDelivery? firstInboxDelivery;
  final CalendarSession? calendarSession;
  final ReportCardSummary? firstReportCardSummary;

  static Future<GuardianProbeBundle> load(
    GuardianWidgetTestHarness harness,
  ) async {
    if (harness.isGuest) {
      throw StateError(
        'GuardianProbeBundle.load requires an authenticated harness',
      );
    }

    final client = harness.portalSession!.schoolClient;
    final profile = harness.profile!;

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
      inboxSubjectId: harness.context!.inboxSubjectId,
    );
    final attendance = await loadGuardianAttendance(
      client,
      studentId: profile.primaryStudentId,
    );

    final sessionProbe = await _loadSessionProbe(
      client,
      calendar.timetableEvents,
      profile.primaryClassGroupId,
    );
    final studentSwitchProbe = _loadStudentSwitchProbe(harness);
    final graded = _loadFirstGradedEntry(academic);
    final firstPayment = _loadFirstPayment(fees);
    final firstInboxDelivery = inbox.deliveries.isEmpty
        ? null
        : InboxDelivery.fromJson(inbox.deliveries.first);
    final calendarSession = _loadCalendarSession(calendar.timetableEvents);
    final firstReportCardSummary = _loadFirstReportCardSummary(academic);

    return GuardianProbeBundle(
      academic: academic,
      fees: fees,
      calendar: calendar,
      inbox: inbox,
      attendance: attendance,
      sessionProbe: sessionProbe,
      studentSwitchProbe: studentSwitchProbe,
      firstGradedAssessmentTitle: graded?.$1,
      firstSubjectMatterName: _firstSubjectMatterName(academic),
      firstGradedEntry: graded?.$2,
      firstPayment: firstPayment,
      firstInboxDelivery: firstInboxDelivery,
      calendarSession: calendarSession,
      firstReportCardSummary: firstReportCardSummary,
    );
  }

  static CalendarSession? _loadCalendarSession(List<dynamic> events) {
    for (final event in events) {
      if (event is! Map<String, dynamic>) {
        continue;
      }
      if (event['kind'] != 'lesson') {
        continue;
      }
      final startsAtRaw = event['startsAt'] as String?;
      final endsAtRaw = event['endsAt'] as String?;
      if (startsAtRaw == null || endsAtRaw == null) {
        continue;
      }
      final id =
          event['id'] as String? ??
          event['lessonSessionId'] as String? ??
          event['occurrenceId'] as String?;
      if (id == null || id.isEmpty) {
        continue;
      }

      return CalendarSession(
        id: id,
        title: event['title'] as String? ?? 'Lesson',
        kind: 'lesson',
        startsAt: DateTime.parse(startsAtRaw).toLocal(),
        endsAt: DateTime.parse(endsAtRaw).toLocal(),
        classSubjectId: event['classSubjectId'] as String?,
        subjectLabel:
            event['subjectLabel'] as String? ?? event['title'] as String?,
        status: event['status'] as String?,
      );
    }
    return null;
  }

  static ReportCardSummary? _loadFirstReportCardSummary(
    GuardianAcademicProbe academic,
  ) {
    if (academic.reportCards.isEmpty) {
      return null;
    }

    final row = academic.reportCards.first;
    final periodId = row['periodId'] as String? ?? '';
    final periodName = academic.academicPeriods
        .cast<Map<String, dynamic>>()
        .where((period) => period['id'] == periodId)
        .map((period) => period['name'] as String? ?? periodId)
        .firstOrNull;

    return ReportCardSummary.fromJson(row, periodName: periodName ?? periodId);
  }

  static Future<GuardianCalendarSessionProbe?> _loadSessionProbe(
    SchoolClient client,
    List<dynamic> events,
    String classGroupId,
  ) async {
    for (final event in events) {
      if (event is! Map<String, dynamic>) {
        continue;
      }
      if (event['kind'] != 'lesson') {
        continue;
      }
      final startsAtRaw = event['startsAt'] as String?;
      if (startsAtRaw == null) {
        continue;
      }
      final startsAt = DateTime.parse(startsAtRaw).toLocal();
      final title = event['title'] as String? ?? 'Lesson';
      final subjectLabel =
          event['subjectLabel'] as String? ??
          event['title'] as String? ??
          title;
      return GuardianCalendarSessionProbe(
        sessionTitle: title,
        subjectLabel: subjectLabel,
        sessionDay: DateTime(startsAt.year, startsAt.month, startsAt.day),
      );
    }

    final lessonSessionId = await resolveLessonSessionIdForClass(
      client,
      classGroupId: classGroupId,
      timetableEvents: events,
    );
    if (lessonSessionId == null) {
      return null;
    }

    final lessonSession = await client.lessonSessions.get(lessonSessionId);
    final startsAtRaw = lessonSession['startsAt'] as String?;
    if (startsAtRaw == null) {
      return null;
    }
    final startsAt = DateTime.parse(startsAtRaw).toLocal();
    final title =
        lessonSession['title'] as String? ??
        lessonSession['displayLabel'] as String? ??
        'Lesson';

    return GuardianCalendarSessionProbe(
      sessionTitle: title,
      subjectLabel: title,
      sessionDay: DateTime(startsAt.year, startsAt.month, startsAt.day),
    );
  }

  static GuardianStudentSwitchProbe? _loadStudentSwitchProbe(
    GuardianWidgetTestHarness harness,
  ) {
    if (harness.context!.linkedStudents.length < 2) {
      return null;
    }

    final alternate = harness.context!.linkedStudents.firstWhere(
      (row) => row['id'] != harness.profile!.primaryStudentId,
      orElse: () => harness.context!.linkedStudents.last,
    );
    final firstName = alternate['firstName'] as String? ?? '';
    final lastName = alternate['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();

    return GuardianStudentSwitchProbe(
      alternateStudentId: alternate['id'] as String,
      alternateStudentName: fullName.isEmpty
          ? alternate['id'] as String
          : fullName,
    );
  }

  static (String, GradeEntry)? _loadFirstGradedEntry(
    GuardianAcademicProbe academic,
  ) {
    final periodNameById = {
      for (final period in academic.academicPeriods)
        period['id'] as String:
            period['name'] as String? ?? period['id'] as String,
    };
    final subjectNameById = {
      for (final subject in academic.subjects)
        subject['id'] as String: subject['name'] as String? ?? '',
    };
    final classSubjectById = {
      for (final row in academic.classSubjects) row['id'] as String: row,
    };

    for (final result in academic.assessmentResults) {
      if (result['score'] == null) {
        continue;
      }
      final assessmentId = result['assessmentId'] as String?;
      if (assessmentId == null) {
        continue;
      }
      final assessment = academic.assessments
          .cast<Map<String, dynamic>>()
          .where((row) => row['id'] == assessmentId)
          .firstOrNull;
      if (assessment == null) {
        continue;
      }

      final classSubjectId = assessment['classSubjectId'] as String?;
      final classSubject = classSubjectId == null
          ? null
          : classSubjectById[classSubjectId];
      final subjectId = classSubject?['subjectId'] as String?;
      final subjectName = subjectId == null
          ? ''
          : subjectNameById[subjectId] ?? '';
      final periodId = assessment['periodId'] as String? ?? '';
      final periodName = periodNameById[periodId] ?? periodId;
      final title = assessment['title'] as String? ?? assessmentId;

      return (
        title,
        GradeEntry.fromMaps(
          result: result,
          assessment: assessment,
          subjectName: subjectName.isEmpty ? 'Subject' : subjectName,
          periodName: periodName,
        ),
      );
    }

    return null;
  }

  static String? _firstSubjectMatterName(GuardianAcademicProbe academic) {
    for (final matter in academic.subjectMatters) {
      final name =
          matter['name'] as String? ?? matter['title'] as String? ?? '';
      if (name.isNotEmpty) {
        return name;
      }
    }
    return null;
  }

  static PaymentRecord? _loadFirstPayment(GuardianFeesProbe fees) {
    if (fees.payments.isEmpty) {
      return null;
    }

    final payment = fees.payments.first;
    final chargeId =
        payment['studentChargeId'] as String? ??
        payment['chargeId'] as String? ??
        payment['studentFeeId'] as String?;
    final charge = fees.studentCharges
        .where((row) => row['id'] == chargeId)
        .cast<Map<String, dynamic>?>()
        .firstWhere((row) => row != null, orElse: () => null);
    final feeLabel = charge?['label'] as String? ?? chargeId ?? 'Fee';

    return PaymentRecord.fromJson(payment, feeLabel: feeLabel);
  }
}
