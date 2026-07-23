import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../common/utils/entity_filters.dart';
import '../calendar/models/calendar_session.dart';
import '../calendar/models/school_event.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import '../fees/models/student_fee_line.dart';
import '../scolarite/models/grade_entry.dart';
import '../scolarite/models/report_card_summary.dart';

class HomeFinanceAlert {
  const HomeFinanceAlert({
    required this.id,
    required this.label,
    required this.amount,
    required this.currency,
    required this.dueDate,
    required this.isOverdue,
  });

  final String id;
  final String label;
  final double amount;
  final String currency;
  final DateTime dueDate;
  final bool isOverdue;
}

class HomeDayPlan {
  const HomeDayPlan({
    required this.dayOffset,
    required this.sessions,
    required this.events,
    required this.noSchoolDay,
  });

  final int dayOffset;
  final List<CalendarSession> sessions;
  final List<SchoolEvent> events;
  final SchoolEvent? noSchoolDay;

  bool get hasContent =>
      noSchoolDay != null || events.isNotEmpty || sessions.isNotEmpty;

  int get lessonCount =>
      sessions.where((s) => s.kind == 'lesson').length;
  int get activityCount =>
      sessions.where((s) => s.kind == 'activity').length;
  int get assessmentCount =>
      sessions.where((s) => s.kind == 'assessment').length;
}

class HomeController extends LevitController with LevitReactiveTasksMixin {
  HomeController({
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _academicYear = academicYear,
       _session = session,
       _schoolClient = schoolClient;

  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;
  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;

  final overdueFeeCount = LxVar(0);
  final feeBalance = LxVar(0.0);
  final feeCurrency = LxVar('EUR');
  final financeAlerts = LxVar<List<HomeFinanceAlert>>(const []);
  final unreadCount = LxVar(0);
  final latestBulletin = LxVar<ReportCardSummary?>(null);
  final latestGrades = LxVar<List<GradeEntry>>(const []);
  final todayPlan = LxVar<HomeDayPlan?>(null);
  final tomorrowPlan = LxVar<HomeDayPlan?>(null);
  final errorMessage = LxVar('');
  final selectedDayOffset = LxVar(0);

  @override
  void onInit() {
    super.onInit();
    autoDispose(overdueFeeCount);
    autoDispose(feeBalance);
    autoDispose(feeCurrency);
    autoDispose(financeAlerts);
    autoDispose(unreadCount);
    autoDispose(latestBulletin);
    autoDispose(latestGrades);
    autoDispose(todayPlan);
    autoDispose(tomorrowPlan);
    autoDispose(errorMessage);
    autoDispose(selectedDayOffset);

    for (final subscription in [
      _studentContext.classGroupId.stream,
      _studentContext.activeStudent.stream,
      _academicYear.selectedYearId.stream,
      _session.user.stream,
    ]) {
      autoDispose(subscription.listen((_) => unawaited(load())));
    }

    unawaited(load());
  }

  void openCalendarDay(int dayOffset) {
    selectedDayOffset(dayOffset);
  }

  Future<void> load() async {
    await runTask(() async {
      await Future.wait([
        _loadFees(),
        _loadInbox(),
        _loadAcademicHighlights(),
        _loadDayPlans(),
      ]);
    });
  }

  Future<void> _loadFees() async {
    final studentId = _studentContext.activeStudentId;
    final yearId = _academicYear.selectedYearId.value;
    if (studentId == null || yearId == null) {
      overdueFeeCount(0);
      feeBalance(0);
      financeAlerts(const []);
      return;
    }

    try {
      final client = _schoolClient();
      final rows = await client.studentFees.list(
        studentFeesForStudent(studentId),
      );
      final yearFees = rows
          .where((row) => row['academicYearId'] == yearId)
          .where((row) => row['status'] != 'cancelled')
          .toList();

      final feeIds = yearFees
          .map((row) => row['feeId'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      final feeNameById = <String, String>{};
      for (final feeId in feeIds) {
        try {
          final fee = await client.fees.get(feeId);
          feeNameById[feeId] = fee['name'] as String? ?? feeId;
        } on Object {
          feeNameById[feeId] = systemL10n().schoolFee;
        }
      }

      final lines = yearFees
          .map(
            (row) => StudentFeeLine.fromJson(
              row,
              label: feeNameById[row['feeId'] as String] ??
                  systemL10n().schoolFee,
            ),
          )
          .toList();

      overdueFeeCount(
        lines.where((l) => l.status == StudentFeeStatus.overdue).length,
      );
      feeBalance(
        lines.fold<double>(0, (sum, l) => sum + l.balance),
      );
      if (lines.isNotEmpty) {
        feeCurrency(lines.first.currency);
      }

      financeAlerts(
        lines
            .where(
              (l) =>
                  l.dueDate != null &&
                  l.balance > 0 &&
                  (l.status == StudentFeeStatus.overdue ||
                      l.status == StudentFeeStatus.pending ||
                      l.status == StudentFeeStatus.partial),
            )
            .map(
              (l) => HomeFinanceAlert(
                id: l.id,
                label: l.label,
                amount: l.balance,
                currency: l.currency,
                dueDate: l.dueDate!,
                isOverdue: l.status == StudentFeeStatus.overdue,
              ),
            )
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate)),
      );
    } on Object {
      overdueFeeCount(0);
      feeBalance(0);
      financeAlerts(const []);
    }
  }

  Future<void> _loadInbox() async {
    final subjectId = _session.user.value?.id;
    if (subjectId == null) {
      unreadCount(0);
      return;
    }
    try {
      final rows = await _schoolClient().messageDeliveries.list(
        deliveriesForSubject(subjectId),
      );
      unreadCount(
        rows.where((row) => row['status'] != 'read').length,
      );
    } on Object {
      unreadCount(0);
    }
  }

  Future<void> _loadAcademicHighlights() async {
    final studentId = _studentContext.activeStudentId;
    if (studentId == null) {
      latestBulletin(null);
      latestGrades(const []);
      return;
    }

    try {
      final client = _schoolClient();
      final reportRows = await client.results.list(
        publishedReportCardsForStudent(studentId),
      );
      if (reportRows.isEmpty) {
        latestBulletin(null);
      } else {
        final cards = reportRows
            .map(
              (row) => ReportCardSummary.fromJson(
                row,
                periodName:
                    row['periodId'] as String? ?? systemL10n().periodFallback,
              ),
            )
            .toList()
          ..sort((a, b) {
            final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
        latestBulletin(cards.first);
      }
    } on Object {
      latestBulletin(null);
    }

    // Latest grades are optional enrichment; skip heavy assessment fan-out if no class.
    final classGroupId = _studentContext.classGroupId.value;
    if (classGroupId == null) {
      latestGrades(const []);
      return;
    }

    try {
      final client = _schoolClient();
      final assessments = await client.assessments.list(
        classGroupScope(classGroupId),
      );
      final assessmentById = {
        for (final a in assessments) a['id'] as String: a,
      };
      if (assessmentById.isEmpty) {
        latestGrades(const []);
        return;
      }
      final results = await client.assessmentResults.list({
        'studentId': studentId,
        ...recordsForField('assessmentId', assessmentById.keys.toList()),
      });
      final entries = <GradeEntry>[];
      for (final result in results) {
        final assessment = assessmentById[result['assessmentId'] as String?];
        if (assessment == null) continue;
        entries.add(
          GradeEntry.fromMaps(
            result: result,
            assessment: assessment,
            subjectName: systemL10n().subjectFallback,
            periodName:
                assessment['periodId'] as String? ??
                systemL10n().periodFallback,
          ),
        );
      }
      entries.sort((a, b) {
        final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      latestGrades(entries.take(5).toList());
    } on Object {
      latestGrades(const []);
    }
  }

  Future<void> _loadDayPlans() async {
    final classGroupId = _studentContext.classGroupId.value;
    final yearId = _academicYear.selectedYearId.value;
    if (classGroupId == null || yearId == null) {
      todayPlan(null);
      tomorrowPlan(null);
      return;
    }

    try {
      final client = _schoolClient();
      final today = defaultCalendarDay();
      final weekStart = startOfWeek(today);
      final range = planningDateRangeForWeek(weekStart);
      final occurrences = await fetchClassTimetableOccurrences(
        client,
        classGroupId,
        range: range,
        enrichStaffWorkspace: false,
      );
      final sessions = occurrences
          .map(CalendarSession.fromOccurrence)
          .toList(growable: false);

      List<SchoolEvent> events = const [];
      try {
        final eventRows = await client.calendarEvents.list(
          academicYearScope(yearId),
        );
        events = eventRows.map(SchoolEvent.fromJson).toList(growable: false);
      } on Object {
        events = const [];
      }

      todayPlan(_planForOffset(0, today, sessions, events));
      tomorrowPlan(_planForOffset(1, today, sessions, events));
    } on Object {
      todayPlan(null);
      tomorrowPlan(null);
    }
  }

  HomeDayPlan _planForOffset(
    int offset,
    DateTime today,
    List<CalendarSession> sessions,
    List<SchoolEvent> events,
  ) {
    final day = DateTime(today.year, today.month, today.day)
        .add(Duration(days: offset));
    final daySessions = sessions.where((s) => s.occursOn(day)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final dayEvents = events.where((e) => e.occursOn(day)).toList();
    final noSchool = dayEvents.where((e) => e.isNonSchoolDay).firstOrNull;
    return HomeDayPlan(
      dayOffset: offset,
      sessions: daySessions,
      events: dayEvents.where((e) => !e.isNonSchoolDay).toList(),
      noSchoolDay: noSchool,
    );
  }
}
