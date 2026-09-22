import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../common/utils/entity_filters.dart';
import '../calendar/models/calendar_session.dart';
import '../calendar/models/school_event.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import '../fees/models/student_charge_line.dart';
import '../scolarite/grades_data.dart';
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
  final int amount;
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

  int get lessonCount => sessions.where((s) => s.kind == 'lesson').length;
  int get activityCount => sessions.where((s) => s.kind == 'activity').length;
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
  final loadWarnings = LxVar<Set<String>>(const {});
  final feeBalance = LxVar(0);
  final feeCurrency = LxVar('XOF');
  final unreadCount = LxVar(0);
  final openCampaigns = LxVar<List<GuardianFamilyFeedbackCampaign>>(const []);
  final photoNeedsAttention = LxVar(false);
  final leftoverPapers = LxVar<List<DocumentIssuanceRecord>>(const []);
  final financeAlerts = LxVar<List<HomeFinanceAlert>>(const []);
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
    autoDispose(loadWarnings);
    autoDispose(feeBalance);
    autoDispose(feeCurrency);
    autoDispose(unreadCount);
    autoDispose(openCampaigns);
    autoDispose(photoNeedsAttention);
    autoDispose(leftoverPapers);
    autoDispose(financeAlerts);
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
        _loadCampaigns(),
        _loadChildAttention(),
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
      return;
    }

    try {
      final rows = await _schoolClient().studentCharges.list(
        studentChargesForStudent(studentId: studentId, academicYearId: yearId),
      );
      final lines = rows
          .where((row) => row['status'] != 'cancelled')
          .map(StudentChargeLine.fromJson)
          .toList();
      overdueFeeCount(
        lines.where((line) => line.status == ChargeStatus.overdue).length,
      );
      feeBalance(
        lines.fold<int>(0, (sum, line) => sum + line.remainingObligation),
      );
      _clearWarn('fees');
      if (lines.isNotEmpty) {
        feeCurrency(lines.first.currency);
      }
      financeAlerts(
        lines
            .where(
              (line) =>
                  line.dueDate != null &&
                  line.remainingObligation > 0 &&
                  (line.status == ChargeStatus.overdue ||
                      line.status == ChargeStatus.pending ||
                      line.status == ChargeStatus.partial),
            )
            .map(
              (line) => HomeFinanceAlert(
                id: line.id,
                label: line.label,
                amount: line.remainingObligation,
                currency: line.currency,
                dueDate: line.dueDate!,
                isOverdue: line.status == ChargeStatus.overdue,
              ),
            )
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate)),
      );
    } on Object {
      _warn('fees');
    }
  }

  void _warn(String key) {
    loadWarnings({...loadWarnings.value, key});
  }

  void _clearWarn(String key) {
    if (!loadWarnings.value.contains(key)) {
      return;
    }
    loadWarnings({...loadWarnings.value}..remove(key));
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
      unreadCount(rows.where((row) => row['status'] != 'read').length);
      _clearWarn('inbox');
    } on Object {
      _warn('inbox');
    }
  }

  Future<void> _loadCampaigns() async {
    try {
      final items = await listGuardianFamilyFeedbackCampaigns(_schoolClient());
      final studentId = _studentContext.activeStudentId;
      final scoped = studentId == null
          ? items
          : items.where((item) => item.studentId == studentId).toList();
      openCampaigns(scoped.where((item) => item.slotState == 'open').toList());
    } on Object {
      openCampaigns(const []);
    }
  }

  Future<void> _loadChildAttention() async {
    final studentId = _studentContext.activeStudentId;
    final yearId = _academicYear.selectedYearId.value;
    if (studentId == null) {
      photoNeedsAttention(false);
      leftoverPapers(const []);
      return;
    }

    try {
      final rows = await optionalEntityList(
        _schoolClient().studentPhotoSubmissions.list({
          'studentId': studentId,
          r'$limit': 20,
        }),
      );
      photoNeedsAttention(
        rows.any(
          (row) => row['status'] == 'pending' || row['status'] == 'rejected',
        ),
      );
    } on Object {
      photoNeedsAttention(false);
    }

    if (yearId == null) {
      leftoverPapers(const []);
      return;
    }

    try {
      final items = await listDocumentIssuances(
        _schoolClient(),
        studentId: studentId,
        academicYearId: yearId,
      );
      leftoverPapers(
        items
            .where((item) => isLeftoverFamilyPaper(item.templateKey))
            .where((item) => item.isDownloadable || item.isPending)
            .toList(),
      );
    } on Object {
      leftoverPapers(const []);
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
            final aDate =
                a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
        latestBulletin(cards.first);
      }
    } on Object {
      latestBulletin(null);
    }

    final classGroupId = _studentContext.classGroupId.value;
    if (classGroupId == null) {
      latestGrades(const []);
      return;
    }

    try {
      final client = _schoolClient();
      final sources = await fetchStudentGradeSources(
        client: client,
        studentId: studentId,
        classGroupId: classGroupId,
        subjectFallback: systemL10n().subjectFallback,
      );
      final entries = <GradeEntry>[];
      for (final result in sources.results) {
        final assessment =
            sources.assessmentById[result['assessmentId'] as String?];
        if (assessment == null) continue;
        entries.add(
          GradeEntry.fromMaps(
            result: result,
            assessment: assessment,
            subjectName:
                sources.subjectNameByClassSubjectId[assessment['classSubjectId']
                    as String?] ??
                systemL10n().subjectFallback,
            periodName:
                assessment['periodId'] as String? ?? systemL10n().periodFallback,
          ),
        );
      }
      entries.sort((a, b) {
        final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      latestGrades(entries.where((entry) => entry.hasScore).take(3).toList());
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
    final day = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: offset));
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
