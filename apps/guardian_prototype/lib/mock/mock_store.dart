import 'package:flutter/foundation.dart';

class MockSchool {
  const MockSchool({
    required this.id,
    required this.name,
    required this.years,
  });

  final String id;
  final String name;
  final List<String> years;
}

class SchoolStudentGroup {
  const SchoolStudentGroup({
    required this.school,
    required this.students,
  });

  final MockSchool school;
  final List<MockStudent> students;
}

class MockStudent {
  const MockStudent({
    required this.id,
    required this.schoolId,
    required this.firstName,
    required this.lastName,
    required this.classLabel,
    this.photoUrl,
  });

  final String id;
  final String schoolId;
  final String firstName;
  final String lastName;
  final String classLabel;
  final String? photoUrl;

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName[0]}${lastName[0]}';
}

class MockSession {
  const MockSession({
    required this.id,
    required this.subject,
    required this.teacher,
    required this.category,
    required this.date,
    required this.startHour,
    required this.endHour,
    required this.dayIndex,
    this.logbookEntryId,
    this.assessmentDetailId,
    this.activityDetailId,
    this.attendance = 'Présent',
    this.room = '',
  });

  final String id;
  final String subject;
  final String teacher;
  final HomeDayCategory category;
  final DateTime date;
  final int startHour;
  final int endHour;
  final int dayIndex;
  final String? logbookEntryId;
  final String? assessmentDetailId;
  final String? activityDetailId;
  final String attendance;
  final String room;
}

class MockAssessmentDetail {
  const MockAssessmentDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.instructions,
    this.period,
    this.score,
    this.maxScore,
    this.coefficient,
  });

  final String id;
  final String title;
  final String description;
  final String instructions;
  final String? period;
  final double? score;
  final double? maxScore;
  final double? coefficient;

  bool get hasMark => score != null && maxScore != null;
}

class MockActivityPhoto {
  const MockActivityPhoto({
    required this.id,
    required this.url,
    required this.caption,
    this.isGroup = false,
  });

  final String id;
  final String url;
  final String caption;
  final bool isGroup;
}

class MockActivityDetail {
  const MockActivityDetail({
    required this.id,
    required this.staffName,
    required this.staffComment,
    required this.sharedAt,
    required this.photos,
  });

  final String id;
  final String staffName;
  final String staffComment;
  final DateTime sharedAt;
  final List<MockActivityPhoto> photos;
}

class MockEvent {
  const MockEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.description,
    this.endDate,
    this.kind = 'Événement',
    this.isNonSchoolDay = false,
  });

  final String id;
  final String title;
  final DateTime date;
  final DateTime? endDate;
  final String description;
  final String kind;
  final bool isNonSchoolDay;

  bool occursOn(DateTime day) {
    final start = DateTime(date.year, date.month, date.day);
    final endValue = endDate ?? date;
    final end = DateTime(endValue.year, endValue.month, endValue.day);
    final target = DateTime(day.year, day.month, day.day);
    return !target.isBefore(start) && !target.isAfter(end);
  }
}

class MockAttendance {
  const MockAttendance({
    required this.id,
    required this.date,
    required this.subject,
    required this.status,
  });

  final String id;
  final DateTime date;
  final String subject;
  final String status;
}

class MockTopic {
  const MockTopic({
    required this.id,
    required this.subject,
    required this.title,
    required this.progress,
    required this.status,
  });

  final String id;
  final String subject;
  final String title;
  final double progress;
  final String status;
}

enum MockPeriodStatus { open, upcoming }

class MockAcademicPeriod {
  const MockAcademicPeriod({
    required this.id,
    required this.label,
    required this.status,
  });

  final String id;
  final String label;
  final MockPeriodStatus status;

  bool get isSelectable => status == MockPeriodStatus.open;
}

class MockSubjectPeriodMeta {
  const MockSubjectPeriodMeta({
    required this.state,
    this.teacherName,
    this.teacherComment,
  });

  final MockResultsPublicationState state;
  final String? teacherName;
  final String? teacherComment;
}

class SubjectProgressSummary {
  const SubjectProgressSummary({
    required this.subject,
    required this.progress,
    required this.status,
    required this.topicCount,
  });

  final String subject;
  final double progress;
  final String status;
  final int topicCount;

  bool get hasProgramme => topicCount > 0;
}

class MockLogbookEntry {
  const MockLogbookEntry({
    required this.id,
    required this.subject,
    required this.date,
    required this.chapter,
    required this.content,
    required this.progress,
    this.homework,
    this.objectives = const [],
  });

  final String id;
  final String subject;
  final DateTime date;
  final String chapter;
  final String content;
  final int progress;
  final String? homework;
  final List<String> objectives;
}

class MockGrade {
  const MockGrade({
    required this.id,
    required this.subject,
    required this.title,
    required this.score,
    required this.maxScore,
    required this.period,
    required this.date,
    this.coefficient = 1,
  });

  final String id;
  final String subject;
  final String title;
  final double score;
  final double maxScore;
  final String period;
  final DateTime date;
  final double coefficient;
}

enum MockResultsPublicationState { draft, processed, published }

extension MockResultsPublicationStateLabels on MockResultsPublicationState {
  String get label => switch (this) {
    MockResultsPublicationState.draft => 'Brouillon',
    MockResultsPublicationState.processed => 'Traité',
    MockResultsPublicationState.published => 'Publié',
  };
}

class MockSubjectPeriodResults {
  const MockSubjectPeriodResults({
    required this.subject,
    required this.period,
    required this.state,
    required this.gradeCount,
    this.average,
    this.maxScore = 20,
    this.teacherName,
    this.teacherComment,
  });

  final String subject;
  final String period;
  final MockResultsPublicationState state;
  final int gradeCount;
  final double? average;
  final double maxScore;
  final String? teacherName;
  final String? teacherComment;

  bool get isPublished => state == MockResultsPublicationState.published;

  bool get hasTeacherFeedback =>
      isPublished &&
      ((teacherName != null && teacherName!.isNotEmpty) ||
          (teacherComment != null && teacherComment!.isNotEmpty));

  String get averageLabel {
    if (average == null) return '—';
    final formatted = average! % 1 == 0
        ? average!.toInt().toString()
        : average!.toStringAsFixed(1).replaceAll('.', ',');
    return '$formatted / ${maxScore.toInt()}';
  }

  bool get hasAverage => average != null;
}

class MockReportCard {
  const MockReportCard({
    required this.id,
    required this.period,
    required this.average,
    required this.publishedAt,
    required this.summary,
    this.isCurrentPeriod = false,
  });

  final String id;
  final String period;
  final String average;
  final DateTime publishedAt;
  final String summary;
  final bool isCurrentPeriod;
}

class MockFeeLine {
  const MockFeeLine({
    required this.id,
    required this.label,
    required this.expected,
    required this.paid,
    required this.currency,
    required this.status,
    this.dueDate,
    this.paymentCount = 0,
    this.description,
  });

  final String id;
  final String label;
  final double expected;
  final double paid;
  final String currency;
  final String status;
  final DateTime? dueDate;
  final int paymentCount;
  final String? description;

  double get balance => (expected - paid).clamp(0, expected);

  double get progress => expected == 0 ? 0 : (paid / expected).clamp(0, 1);
}

class MockFeeInstallment {
  const MockFeeInstallment({
    required this.id,
    required this.feeLineId,
    required this.label,
    required this.amount,
    required this.paid,
    required this.currency,
    required this.dueDate,
    required this.status,
  });

  final String id;
  final String feeLineId;
  final String label;
  final double amount;
  final double paid;
  final String currency;
  final DateTime dueDate;
  final String status;

  double get balance => (amount - paid).clamp(0, amount);

  double get progress => amount == 0 ? 0 : (paid / amount).clamp(0, 1);

  bool get isPaid => paid >= amount;
}

class MockPayment {
  const MockPayment({
    required this.id,
    required this.feeLineId,
    required this.feeLabel,
    required this.amount,
    required this.currency,
    required this.method,
    required this.date,
  });

  final String id;
  final String feeLineId;
  final String feeLabel;
  final double amount;
  final String currency;
  final String method;
  final DateTime date;
}

class MockMessage {
  MockMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.sentAt,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime sentAt;
  bool read;
}

enum HomeDayCategory { lesson, activity, assessment }

extension HomeDayCategoryLabels on HomeDayCategory {
  String get label => switch (this) {
    HomeDayCategory.lesson => 'Cours',
    HomeDayCategory.activity => 'Activité',
    HomeDayCategory.assessment => 'Évaluation',
  };
}

class HomeDayItem {
  const HomeDayItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.startHour,
    required this.endHour,
    required this.category,
    this.dayOffset = 0,
    this.sessionId,
  });

  final String id;
  final String title;
  final String subtitle;
  final int startHour;
  final int endHour;
  final HomeDayCategory category;
  final int dayOffset;
  final String? sessionId;
}

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

class TimetableDaySummary {
  const TimetableDaySummary({
    required this.lessonCount,
    required this.activityCount,
    required this.assessmentCount,
  });

  final int lessonCount;
  final int activityCount;
  final int assessmentCount;

  int get total => lessonCount + activityCount + assessmentCount;

  bool get isEmpty => total == 0;
}

class MockStore extends ChangeNotifier {
  MockStore() {
    _schools.addAll(_defaultSchools);
    _students.addAll(_defaultStudents);
    for (final school in _schools) {
      _selectedYearBySchool[school.id] = school.years.first;
    }
    _sessions.addAll(_buildDefaultSessions());
    _events.addAll(_defaultEvents);
    _events.addAll(_homeCalendarSeedEvents());
    _attendance.addAll(_defaultAttendance);
    _topics.addAll(_defaultTopics);
    _academicPeriods.addAll(_defaultAcademicPeriods);
    _logbook.addAll(_buildDefaultLogbook());
    _assessmentDetails.addAll(_buildDefaultAssessmentDetails());
    _activityDetails.addAll(_buildDefaultActivityDetails());
    _grades.addAll(_defaultGrades);
    _reportCards.addAll(_defaultReportCards);
    _feeLines.addAll(_defaultFees);
    _feeInstallments.addAll(_defaultFeeInstallments);
    _payments.addAll(_defaultPayments);
    _messages.addAll(_defaultMessages);
    _upcomingAgenda.addAll(_defaultUpcomingAgenda);
    _upcomingFees.addAll(_defaultUpcomingFees);
    _calendarWeekStart = mondayOf(DateTime.now());
  }

  bool isAuthenticated = false;

  static const guardianFirstName = 'Moussa';
  static const guardianLastName = 'Koné';
  static const guardianEmail = 'parent@demo.ci';

  String get guardianFullName => '$guardianFirstName $guardianLastName';
  String get guardianInitials => '${guardianFirstName[0]}${guardianLastName[0]}';

  final List<MockSchool> _schools = [];
  final List<MockStudent> _students = [];
  final Map<String, String> _selectedYearBySchool = {};
  String activeStudentId = 'amina';

  final List<MockSession> _sessions = [];
  final List<MockEvent> _events = [];
  final List<MockAttendance> _attendance = [];
  final List<MockTopic> _topics = [];
  final List<MockLogbookEntry> _logbook = [];
  final List<MockAssessmentDetail> _assessmentDetails = [];
  final List<MockActivityDetail> _activityDetails = [];
  final List<MockAcademicPeriod> _academicPeriods = [];
  final List<MockGrade> _grades = [];
  final List<MockReportCard> _reportCards = [];
  final List<MockFeeLine> _feeLines = [];
  final List<MockFeeInstallment> _feeInstallments = [];
  final List<MockPayment> _payments = [];
  final List<MockMessage> _messages = [];
  final List<HomeDayItem> _upcomingAgenda = [];
  final List<HomeFinanceAlert> _upcomingFees = [];

  int scolariteTab = 0;
  int selectedDayIndex = DateTime.now().weekday - 1;
  String selectedSubject = 'Anglais';
  String selectedPeriodId = 't1';
  late DateTime _calendarWeekStart;

  static DateTime mondayOf(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - DateTime.monday));
  }

  List<MockStudent> get students => List.unmodifiable(_students);
  List<MockSchool> get schools => List.unmodifiable(_schools);

  MockStudent get activeStudent =>
      _students.firstWhere((s) => s.id == activeStudentId);

  MockSchool get activeSchool =>
      _schools.firstWhere((s) => s.id == activeStudent.schoolId);

  String get selectedYear => selectedYearForSchool(activeStudent.schoolId);

  String selectedYearForSchool(String schoolId) {
    final stored = _selectedYearBySchool[schoolId];
    if (stored != null) return stored;
    return _schools.firstWhere((school) => school.id == schoolId).years.first;
  }

  List<String> schoolYearsFor(String schoolId) =>
      _schools.firstWhere((school) => school.id == schoolId).years;

  List<SchoolStudentGroup> get studentsBySchool {
    return [
      for (final school in _schools)
        SchoolStudentGroup(
          school: school,
          students: _students.where((student) => student.schoolId == school.id).toList(),
        ),
    ].where((group) => group.students.isNotEmpty).toList();
  }

  List<MockSession> get sessions => List.unmodifiable(_sessions);
  List<MockEvent> get events => List.unmodifiable(_events);
  List<MockAttendance> get attendance => List.unmodifiable(_attendance);
  List<MockTopic> get topics => List.unmodifiable(_topics);
  List<MockLogbookEntry> get logbook => List.unmodifiable(_logbook);
  List<MockAcademicPeriod> get academicPeriods =>
      List.unmodifiable(_academicPeriods);

  MockAcademicPeriod? get selectedAcademicPeriod {
    try {
      return _academicPeriods.firstWhere((period) => period.id == selectedPeriodId);
    } on Object {
      return null;
    }
  }

  List<String> get subjects => const [
    'Anglais',
    'Français',
    'Mathématiques',
    'Sciences',
    'Histoire-Géographie',
  ];

  List<MockTopic> topicsForSubject(String subject) =>
      _topics.where((topic) => topic.subject == subject).toList();

  List<MockLogbookEntry> logbookForSubject(String subject) =>
      _logbook.where((entry) => entry.subject == subject).toList();

  List<MockTopic> get topicsForSelectedSubject => topicsForSubject(selectedSubject);

  List<MockLogbookEntry> get logbookForSelectedSubject =>
      logbookForSubject(selectedSubject);

  double progressForSubject(String subject) {
    final topics = topicsForSubject(subject);
    if (topics.isEmpty) return 0;
    return topics.map((topic) => topic.progress).reduce((a, b) => a + b) /
        topics.length;
  }

  String statusForSubject(String subject) {
    final progress = progressForSubject(subject);
    if (progress <= 0) return 'Non commencé';
    if (progress >= 1) return 'Terminé';
    return 'En cours';
  }

  double get overallProgramProgress {
    final subjectsWithProgramme =
        subjects.where((subject) => topicsForSubject(subject).isNotEmpty);
    if (subjectsWithProgramme.isEmpty) return 0;
    final total = subjectsWithProgramme
        .map(progressForSubject)
        .reduce((a, b) => a + b);
    return total / subjectsWithProgramme.length;
  }

  List<SubjectProgressSummary> get subjectProgressSummaries => [
    for (final subject in subjects)
      SubjectProgressSummary(
        subject: subject,
        progress: progressForSubject(subject),
        status: statusForSubject(subject),
        topicCount: topicsForSubject(subject).length,
      ),
  ];

  int get subjectsWithProgrammeCount =>
      subjectProgressSummaries.where((summary) => summary.hasProgramme).length;

  List<MockGrade> gradesForPeriod(String periodLabel) {
    return _grades
        .where((grade) => grade.period == periodLabel)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<MockGrade> gradesForSubjectAndPeriod(String subject, String periodLabel) {
    return _grades
        .where((grade) => grade.subject == subject && grade.period == periodLabel)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  MockAcademicPeriod? periodById(String periodId) {
    try {
      return _academicPeriods.firstWhere((period) => period.id == periodId);
    } on Object {
      return null;
    }
  }

  List<MockSubjectPeriodResults> subjectResultsForPeriod(String periodLabel) {
    final metaBySubject = _subjectPeriodMeta[periodLabel];
    if (metaBySubject == null) return [];

    return metaBySubject.entries.map((entry) {
      final grades = gradesForSubjectAndPeriod(entry.key, periodLabel);
      final meta = entry.value;
      return MockSubjectPeriodResults(
        subject: entry.key,
        period: periodLabel,
        state: meta.state,
        gradeCount: grades.length,
        average: grades.isEmpty ? null : _weightedAverage(grades),
        teacherName: meta.teacherName,
        teacherComment: meta.teacherComment,
      );
    }).toList()
      ..sort((a, b) => a.subject.compareTo(b.subject));
  }

  MockSubjectPeriodResults? subjectResultsFor(
    String subject,
    String periodLabel,
  ) {
    try {
      return subjectResultsForPeriod(periodLabel)
          .firstWhere((result) => result.subject == subject);
    } on Object {
      return null;
    }
  }

  static double _weightedAverage(List<MockGrade> grades) {
    var total = 0.0;
    var coefficientSum = 0.0;
    for (final grade in grades) {
      final normalized = (grade.score / grade.maxScore) * 20;
      total += normalized * grade.coefficient;
      coefficientSum += grade.coefficient;
    }
    if (coefficientSum == 0) return 0;
    return total / coefficientSum;
  }

  List<MockGrade> get gradesForSelectedPeriod {
    final period = selectedAcademicPeriod;
    if (period == null) return grades;
    return _grades.where((grade) => grade.period == period.label).toList();
  }

  List<MockReportCard> get reportCardsForSelectedPeriod {
    final period = selectedAcademicPeriod;
    if (period == null) return reportCards;
    return _reportCards.where((card) => card.period == period.label).toList();
  }
  List<MockGrade> get grades => List.unmodifiable(_grades);
  List<MockReportCard> get reportCards => List.unmodifiable(_reportCards);
  List<MockFeeLine> get feeLines => List.unmodifiable(_feeLines);
  List<MockFeeInstallment> get feeInstallments =>
      List.unmodifiable(_feeInstallments);
  List<MockPayment> get payments => List.unmodifiable(_payments);

  MockFeeLine? feeById(String id) {
    try {
      return _feeLines.firstWhere((fee) => fee.id == id);
    } on Object {
      return null;
    }
  }

  List<MockFeeInstallment> installmentsForFee(String feeLineId) {
    return _feeInstallments
        .where((installment) => installment.feeLineId == feeLineId)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<MockPayment> paymentsForFee(String feeLineId) {
    return _payments
        .where((payment) => payment.feeLineId == feeLineId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
  List<MockMessage> get messages => List.unmodifiable(_messages);
  List<HomeDayItem> get upcomingAgenda {
    final sorted = List<HomeDayItem>.from(_upcomingAgenda)
      ..sort((a, b) {
        final byDay = a.dayOffset.compareTo(b.dayOffset);
        if (byDay != 0) return byDay;
        return a.startHour.compareTo(b.startHour);
      });
    return sorted.take(3).toList();
  }

  List<HomeFinanceAlert> get homeFinanceAlerts => List.unmodifiable(_upcomingFees);

  List<MockGrade> get latestGrades {
    final sorted = List<MockGrade>.from(_grades)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(3).toList();
  }

  MockReportCard? get currentPeriodReportCard {
    try {
      return _reportCards.firstWhere((r) => r.isCurrentPeriod);
    } on Object {
      return null;
    }
  }

  DateTime get selectedCalendarDate =>
      _calendarWeekStart.add(Duration(days: selectedDayIndex));

  DateTime dateForWeekDay(int dayIndex) =>
      _calendarWeekStart.add(Duration(days: dayIndex));

  List<MockEvent> get eventsForSelectedDay =>
      _events.where((event) => event.occursOn(selectedCalendarDate)).toList();

  List<MockEvent> get schoolEventsForSelectedDay => eventsForSelectedDay
      .where((event) => !event.isNonSchoolDay)
      .toList();

  List<MockSession> get sessionsForSelectedDay {
    final selected = selectedCalendarDate;
    final sessions = _sessions
        .where((session) => _isSameCalendarDay(session.date, selected))
        .toList()
      ..sort((a, b) => a.startHour.compareTo(b.startHour));
    return sessions;
  }

  MockEvent? get noSchoolDayForSelectedDay {
    for (final event in eventsForSelectedDay) {
      if (event.isNonSchoolDay) return event;
    }
    return null;
  }

  DateTime get todayDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  MockEvent? get noSchoolDayToday => noSchoolDayForOffset(0);

  DateTime dateForDayOffset(int dayOffset) =>
      todayDate.add(Duration(days: dayOffset));

  int dayIndexForOffset(int dayOffset) => dateForDayOffset(dayOffset).weekday - 1;

  MockEvent? noSchoolDayForOffset(int dayOffset) {
    final date = dateForDayOffset(dayOffset);
    for (final event in _events) {
      if (event.isNonSchoolDay && event.occursOn(date)) return event;
    }
    return null;
  }

  List<MockEvent> schoolEventsForDayOffset(int dayOffset) {
    final date = dateForDayOffset(dayOffset);
    return _events
        .where((event) => event.occursOn(date) && !event.isNonSchoolDay)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  TimetableDaySummary timetableSummaryForDayOffset(int dayOffset) {
    if (noSchoolDayForOffset(dayOffset) != null) {
      return const TimetableDaySummary(
        lessonCount: 0,
        activityCount: 0,
        assessmentCount: 0,
      );
    }

    final items = _upcomingAgenda.where((item) => item.dayOffset == dayOffset);
    var lessons = 0;
    var activities = 0;
    var assessments = 0;
    for (final item in items) {
      switch (item.category) {
        case HomeDayCategory.lesson:
          lessons++;
        case HomeDayCategory.activity:
          activities++;
        case HomeDayCategory.assessment:
          assessments++;
      }
    }
    return TimetableDaySummary(
      lessonCount: lessons,
      activityCount: activities,
      assessmentCount: assessments,
    );
  }

  bool hasHomeDayPlan(int dayOffset) {
    if (noSchoolDayForOffset(dayOffset) != null) return true;
    if (schoolEventsForDayOffset(dayOffset).isNotEmpty) return true;
    return !timetableSummaryForDayOffset(dayOffset).isEmpty;
  }

  void selectCalendarDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    _calendarWeekStart = mondayOf(normalized);
    selectedDayIndex = normalized.weekday - DateTime.monday;
    notifyListeners();
  }

  void goToPreviousWeek() {
    _calendarWeekStart = _calendarWeekStart.subtract(const Duration(days: 7));
    notifyListeners();
  }

  void goToNextWeek() {
    _calendarWeekStart = _calendarWeekStart.add(const Duration(days: 7));
    notifyListeners();
  }

  void selectCalendarDayOffset(int dayOffset) {
    selectCalendarDate(todayDate.add(Duration(days: dayOffset)));
  }

  int get unreadCount => _messages.where((m) => !m.read).length;
  int get overdueFeeCount => _feeLines.where((f) => f.status == 'En retard').length;

  double get feeExpected => _feeLines.fold(0, (s, f) => s + f.expected);
  double get feePaid => _feeLines.fold(0, (s, f) => s + f.paid);
  double get feeBalance => (feeExpected - feePaid).clamp(0, feeExpected);

  MockSession? get nextSessionToday {
    final nowHour = DateTime.now().hour;
    final todaySessions = _sessions
        .where(
          (session) =>
              _isSameCalendarDay(session.date, todayDate) &&
              session.startHour >= nowHour,
        )
        .toList()
      ..sort((a, b) => a.startHour.compareTo(b.startHour));
    return todaySessions.isEmpty ? null : todaySessions.first;
  }

  MockGrade? get latestGrade {
    if (_grades.isEmpty) return null;
    final sorted = List<MockGrade>.from(_grades)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.first;
  }

  void signIn() {
    isAuthenticated = true;
    notifyListeners();
  }

  void signOut() {
    isAuthenticated = false;
    notifyListeners();
  }

  void selectStudent(String id) {
    activeStudentId = id;
    notifyListeners();
  }

  void selectYearForSchool(String schoolId, String year) {
    _selectedYearBySchool[schoolId] = year;
    notifyListeners();
  }

  void selectYear(String year) {
    selectYearForSchool(activeStudent.schoolId, year);
  }

  void setScolariteTab(int index) {
    scolariteTab = index;
    notifyListeners();
  }

  void selectDay(int index) {
    selectedDayIndex = index;
    notifyListeners();
  }

  void selectSubject(String subject) {
    selectedSubject = subject;
    notifyListeners();
  }

  static const _subjectSlugs = <String, String>{
    'anglais': 'Anglais',
    'francais': 'Français',
    'mathematiques': 'Mathématiques',
    'sciences': 'Sciences',
    'histoire-geographie': 'Histoire-Géographie',
  };

  static String subjectRouteParam(String subject) {
    for (final entry in _subjectSlugs.entries) {
      if (entry.value == subject) return entry.key;
    }
    return subject.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  }

  static String subjectFromRouteParam(String param) =>
      _subjectSlugs[param] ?? param;

  void selectPeriod(String periodId) {
    final period = _academicPeriods.firstWhere((item) => item.id == periodId);
    if (!period.isSelectable) return;
    selectedPeriodId = periodId;
    notifyListeners();
  }

  void markMessageRead(String id) {
    final msg = _messages.firstWhere((m) => m.id == id);
    if (msg.read) return;
    msg.read = true;
    notifyListeners();
  }

  MockSession? sessionById(String id) {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } on Object {
      return null;
    }
  }

  MockLogbookEntry? logbookEntryById(String id) {
    try {
      return _logbook.firstWhere((entry) => entry.id == id);
    } on Object {
      return null;
    }
  }

  MockLogbookEntry? logbookForSession(String sessionId) {
    final session = sessionById(sessionId);
    final entryId = session?.logbookEntryId;
    if (entryId == null) return null;
    return logbookEntryById(entryId);
  }

  MockAssessmentDetail? assessmentForSession(String sessionId) {
    final session = sessionById(sessionId);
    final detailId = session?.assessmentDetailId;
    if (detailId == null) return null;
    return assessmentDetailById(detailId);
  }

  MockActivityDetail? activityForSession(String sessionId) {
    final session = sessionById(sessionId);
    final detailId = session?.activityDetailId;
    if (detailId == null) return null;
    return activityDetailById(detailId);
  }

  MockAssessmentDetail? assessmentDetailById(String id) {
    try {
      return _assessmentDetails.firstWhere((detail) => detail.id == id);
    } on Object {
      return null;
    }
  }

  MockActivityDetail? activityDetailById(String id) {
    try {
      return _activityDetails.firstWhere((detail) => detail.id == id);
    } on Object {
      return null;
    }
  }

  MockGrade? gradeById(String id) {
    try {
      return _grades.firstWhere((g) => g.id == id);
    } on Object {
      return null;
    }
  }

  MockReportCard? reportCardForPeriod(String periodLabel) {
    try {
      return _reportCards.firstWhere((card) => card.period == periodLabel);
    } on Object {
      return null;
    }
  }

  MockReportCard? reportCardById(String id) {
    try {
      return _reportCards.firstWhere((r) => r.id == id);
    } on Object {
      return null;
    }
  }

  MockPayment? paymentById(String id) {
    try {
      return _payments.firstWhere((p) => p.id == id);
    } on Object {
      return null;
    }
  }

  MockMessage? messageById(String id) {
    try {
      return _messages.firstWhere((m) => m.id == id);
    } on Object {
      return null;
    }
  }
}

bool _isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

final _defaultSchools = [
  const MockSchool(
    id: 'school-college',
    name: 'Collège Lumière d\'Abidjan',
    years: [
      '2025 — 2026',
      '2024 — 2025',
      '2023 — 2024',
      '2022 — 2023',
    ],
  ),
  const MockSchool(
    id: 'school-lycee',
    name: 'Lycée Moderne de Cocody',
    years: [
      '2025 — 2026',
      '2024 — 2025',
      '2023 — 2024',
    ],
  ),
];

final _defaultStudents = [
  const MockStudent(
    id: 'amina',
    schoolId: 'school-college',
    firstName: 'Amina',
    lastName: 'Koné',
    classLabel: '6ème A',
    photoUrl: 'https://i.pravatar.cc/128?img=47',
  ),
  const MockStudent(
    id: 'youssef',
    schoolId: 'school-lycee',
    firstName: 'Youssef',
    lastName: 'Koné',
    classLabel: '3ème B',
    photoUrl: 'https://i.pravatar.cc/128?img=12',
  ),
];

final _sessionSeedDate = DateTime(2000, 1, 1);

final _defaultSessions = [
  MockSession(
    id: 's1',
    subject: 'Mathématiques',
    teacher: 'M. Diallo',
    category: HomeDayCategory.lesson,
    date: _sessionSeedDate,
    startHour: 8,
    endHour: 9,
    room: 'Salle 12',
    dayIndex: 0,
    logbookEntryId: 'lb-s1',
    attendance: 'Présent',
  ),
  MockSession(
    id: 's2',
    subject: 'Anglais',
    teacher: 'Mme Lawson',
    category: HomeDayCategory.lesson,
    date: _sessionSeedDate,
    startHour: 10,
    endHour: 11,
    room: 'Salle 8',
    dayIndex: 0,
    logbookEntryId: 'lb-s2',
    attendance: 'Présent',
  ),
  MockSession(
    id: 's3',
    subject: 'Sport',
    teacher: 'M. Koné',
    category: HomeDayCategory.activity,
    date: _sessionSeedDate,
    startHour: 14,
    endHour: 15,
    room: 'Gymnase',
    dayIndex: 0,
    activityDetailId: 'ad-s3',
    attendance: 'Présent',
  ),
  MockSession(
    id: 's4',
    subject: 'Contrôle de français',
    teacher: 'Mme Traoré',
    category: HomeDayCategory.assessment,
    date: _sessionSeedDate,
    startHour: 11,
    endHour: 12,
    room: 'Salle 4',
    dayIndex: 0,
    assessmentDetailId: 'as-s4',
    attendance: 'Présent',
  ),
  MockSession(
    id: 's5',
    subject: 'Sciences',
    teacher: 'M. Bamba',
    category: HomeDayCategory.activity,
    date: _sessionSeedDate,
    startHour: 15,
    endHour: 16,
    room: 'Labo 2',
    dayIndex: 1,
    activityDetailId: 'ad-s5',
    attendance: 'Présent',
  ),
  MockSession(
    id: 's6',
    subject: 'Dictée n°3',
    teacher: 'Mme Traoré',
    category: HomeDayCategory.assessment,
    date: _sessionSeedDate,
    startHour: 9,
    endHour: 10,
    room: 'Salle 4',
    dayIndex: 2,
    assessmentDetailId: 'as-s6',
    attendance: 'Présent',
  ),
];

List<MockSession> _buildDefaultSessions() {
  final today = DateTime.now();
  final normalized = DateTime(today.year, today.month, today.day);
  return [
    for (final session in _defaultSessions)
      () {
        final dayOffset = session.dayIndex - _defaultSessions.first.dayIndex;
        final date = normalized.add(Duration(days: dayOffset));
        return MockSession(
          id: session.id,
          subject: session.subject,
          teacher: session.teacher,
          category: session.category,
          date: date,
          startHour: session.startHour,
          endHour: session.endHour,
          dayIndex: date.weekday - DateTime.monday,
          logbookEntryId: session.logbookEntryId,
          assessmentDetailId: session.assessmentDetailId,
          activityDetailId: session.activityDetailId,
          attendance: session.attendance,
          room: session.room,
        );
      }(),
  ];
}

List<MockLogbookEntry> _buildDefaultLogbook() {
  final today = DateTime.now();
  final normalized = DateTime(today.year, today.month, today.day);
  return [
    MockLogbookEntry(
      id: 'lb-s1',
      subject: 'Mathématiques',
      date: normalized,
      chapter: 'Équations du premier degré',
      content:
          'Rappel de la méthode de résolution et application sur des problèmes concrets en classe.',
      homework: 'Exercices 3 à 7, page 42',
      progress: 58,
      objectives: const [
        'Résoudre une équation du premier degré',
        'Modéliser un problème avec une inconnue',
      ],
    ),
    MockLogbookEntry(
      id: 'lb-s2',
      subject: 'Anglais',
      date: normalized,
      chapter: 'School life vocabulary',
      content:
          'Révision du lexique de la vie scolaire et mise en situation à l\'oral.',
      homework: 'Apprendre le vocabulaire de la leçon 4',
      progress: 42,
    ),
    MockLogbookEntry(
      id: 'l1',
      subject: 'Anglais',
      date: normalized.subtract(const Duration(days: 6)),
      chapter: 'Compréhension écrite',
      content: 'Révision vocabulaire unit 2 — contrôle prévu vendredi.',
      progress: 35,
    ),
    MockLogbookEntry(
      id: 'l2',
      subject: 'Anglais',
      date: normalized.subtract(const Duration(days: 9)),
      chapter: 'Civilisation britannique',
      content: 'Compréhension écrite — texte sur Londres.',
      progress: 20,
    ),
    MockLogbookEntry(
      id: 'l3',
      subject: 'Français',
      date: normalized.subtract(const Duration(days: 3)),
      chapter: 'Le récit autobiographique',
      content: 'Analyse d\'un extrait et repérage des temps du récit.',
      progress: 20,
    ),
    MockLogbookEntry(
      id: 'l4',
      subject: 'Mathématiques',
      date: normalized.subtract(const Duration(days: 1)),
      chapter: 'Équations du premier degré',
      content: 'Mise en équation de problèmes simples.',
      progress: 58,
    ),
  ];
}

List<MockAssessmentDetail> _buildDefaultAssessmentDetails() {
  return const [
    MockAssessmentDetail(
      id: 'as-s4',
      title: 'Contrôle de français — Rédaction',
      description:
          'Évaluation écrite portant sur l\'expression écrite et la structuration d\'un paragraphe argumenté.',
      instructions:
          'Rédiger un texte de 20 à 25 lignes sur le thème « Mon quotidien à l\'école ». '
          'Attention à l\'orthographe et à la ponctuation.',
      period: 'Trimestre 1',
      coefficient: 2,
    ),
    MockAssessmentDetail(
      id: 'as-s6',
      title: 'Dictée n°3',
      description: 'Dictée sur les homophones et les accords dans le groupe nominal.',
      instructions: 'Aucune préparation spécifique — révision des règles vues en classe.',
      period: 'Trimestre 1',
      score: 16,
      maxScore: 20,
      coefficient: 1,
    ),
  ];
}

List<MockActivityDetail> _buildDefaultActivityDetails() {
  final today = DateTime.now();
  final normalized = DateTime(today.year, today.month, today.day);

  return [
    MockActivityDetail(
      id: 'ad-s3',
      staffName: 'M. Koné',
      staffComment:
          'Belle séance de relais ce matin. Amina a bien participé et a encouragé ses camarades. '
          'Les photos du groupe sont partagées ci-dessous.',
      sharedAt: normalized.add(const Duration(hours: 15)),
      photos: const [
        MockActivityPhoto(
          id: 'ph-s3-1',
          url: 'https://picsum.photos/seed/edaya-sport-group/480/320',
          caption: 'Équipe gagnante du relais',
          isGroup: true,
        ),
        MockActivityPhoto(
          id: 'ph-s3-2',
          url: 'https://picsum.photos/seed/edaya-sport-amina/480/320',
          caption: 'Amina au départ du relais',
          isGroup: false,
        ),
      ],
    ),
    MockActivityDetail(
      id: 'ad-s5',
      staffName: 'M. Bamba',
      staffComment:
          'Atelier sciences prévu demain : expérience sur la densité des liquides. '
          'Merci de prévoir une blouse si possible.',
      sharedAt: normalized.add(const Duration(days: 1, hours: 8)),
      photos: const [
        MockActivityPhoto(
          id: 'ph-s5-1',
          url: 'https://picsum.photos/seed/edaya-lab-group/480/320',
          caption: 'Préparation du matériel en binômes',
          isGroup: true,
        ),
      ],
    ),
  ];
}

final _defaultEvents = [
  MockEvent(
    id: 'e1',
    title: 'Rentrée scolaire',
    date: DateTime(2026, 9, 15),
    description: 'Rentrée des classes à 7h30.',
    kind: 'Événement scolaire',
  ),
  MockEvent(
    id: 'e2',
    title: 'Conseil de classe',
    date: DateTime(2026, 10, 20),
    description: 'Prem trimestre — présence des parents souhaitée.',
    kind: 'Réunion',
  ),
  MockEvent(
    id: 'e3',
    title: 'Sortie pédagogique',
    date: DateTime(2026, 7, 23),
    description: 'Visite du musée des civilisations.',
    kind: 'Sortie',
  ),
];

List<MockEvent> _homeCalendarSeedEvents() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));

  return [
    MockEvent(
      id: 'e-today-1',
      title: 'Réunion parents-professeurs',
      date: today,
      description: 'Rappel — inscription avant 18h.',
      kind: 'Réunion',
    ),
    MockEvent(
      id: 'e-today-2',
      title: 'Atelier sciences',
      date: today,
      description: 'Expériences en salle de labo.',
      kind: 'Atelier',
    ),
    MockEvent(
      id: 'e0',
      title: 'Jour sans école',
      date: tomorrow,
      description: 'Fermeture exceptionnelle de l\'établissement.',
      kind: 'Fermeture',
      isNonSchoolDay: true,
    ),
  ];
}

final _defaultAttendance = [
  MockAttendance(
    id: 'a1',
    date: DateTime(2026, 7, 10),
    subject: 'Mathématiques',
    status: 'Absent',
  ),
  MockAttendance(
    id: 'a2',
    date: DateTime(2026, 7, 8),
    subject: 'Français',
    status: 'Présent',
  ),
  MockAttendance(
    id: 'a3',
    date: DateTime(2026, 7, 5),
    subject: 'Anglais',
    status: 'Retard',
  ),
];

final _defaultAcademicPeriods = [
  const MockAcademicPeriod(
    id: 't1',
    label: 'Trimestre 1',
    status: MockPeriodStatus.open,
  ),
  const MockAcademicPeriod(
    id: 't2',
    label: 'Trimestre 2',
    status: MockPeriodStatus.upcoming,
  ),
  const MockAcademicPeriod(
    id: 't3',
    label: 'Trimestre 3',
    status: MockPeriodStatus.upcoming,
  ),
];

final _defaultTopics = [
  const MockTopic(
    id: 't1',
    subject: 'Anglais',
    title: 'School life',
    progress: 0,
    status: 'Non commencé',
  ),
  const MockTopic(
    id: 't2',
    subject: 'Anglais',
    title: 'Describing people and places',
    progress: 0.35,
    status: 'En cours',
  ),
  const MockTopic(
    id: 't3',
    subject: 'Anglais',
    title: 'Talking about the past',
    progress: 0,
    status: 'Non commencé',
  ),
  const MockTopic(
    id: 't4',
    subject: 'Français',
    title: 'Le récit autobiographique',
    progress: 0.2,
    status: 'En cours',
  ),
  const MockTopic(
    id: 't5',
    subject: 'Français',
    title: 'L\'argumentation',
    progress: 0,
    status: 'Non commencé',
  ),
  const MockTopic(
    id: 't6',
    subject: 'Mathématiques',
    title: 'Équations du premier degré',
    progress: 0.58,
    status: 'En cours',
  ),
  const MockTopic(
    id: 't7',
    subject: 'Sciences',
    title: 'La densité des liquides',
    progress: 0.12,
    status: 'En cours',
  ),
  const MockTopic(
    id: 't8',
    subject: 'Histoire-Géographie',
    title: 'L\'Afrique de l\'Ouest au XIXe siècle',
    progress: 0,
    status: 'Non commencé',
  ),
];


final _defaultGrades = [
  MockGrade(
    id: 'g1',
    subject: 'Français',
    title: 'Dictée n°3',
    score: 16,
    maxScore: 20,
    period: 'Trimestre 1',
    date: DateTime(2026, 7, 14),
  ),
  MockGrade(
    id: 'g4',
    subject: 'Français',
    title: 'Rédaction',
    score: 15,
    maxScore: 20,
    period: 'Trimestre 1',
    date: DateTime(2026, 7, 10),
    coefficient: 2,
  ),
  MockGrade(
    id: 'g2',
    subject: 'Mathématiques',
    title: 'Contrôle géométrie',
    score: 14,
    maxScore: 20,
    period: 'Trimestre 1',
    date: DateTime(2026, 7, 8),
  ),
  MockGrade(
    id: 'g5',
    subject: 'Mathématiques',
    title: 'Devoir maison',
    score: 12,
    maxScore: 20,
    period: 'Trimestre 1',
    date: DateTime(2026, 7, 5),
  ),
  MockGrade(
    id: 'g3',
    subject: 'Anglais',
    title: 'Compréhension écrite',
    score: 17,
    maxScore: 20,
    period: 'Trimestre 1',
    date: DateTime(2026, 7, 3),
  ),
];

const _subjectPeriodMeta = {
  'Trimestre 1': {
    'Anglais': MockSubjectPeriodMeta(
      state: MockResultsPublicationState.published,
      teacherName: 'Mme Lawson',
      teacherComment:
          'Très bon trimestre. Amina participe activement en classe '
          'et progresse en expression orale.',
    ),
    'Français': MockSubjectPeriodMeta(
      state: MockResultsPublicationState.published,
      teacherName: 'Mme Diallo',
      teacherComment:
          'Résultats satisfaisants. Le travail sur l\'orthographe porte '
          'ses fruits ; continuer les efforts en rédaction.',
    ),
    'Mathématiques': MockSubjectPeriodMeta(
      state: MockResultsPublicationState.processed,
    ),
    'Sciences': MockSubjectPeriodMeta(
      state: MockResultsPublicationState.draft,
    ),
  },
};

final _defaultReportCards = [
  MockReportCard(
    id: 'rc1',
    period: 'Trimestre 1',
    average: '15,2 / 20',
    publishedAt: DateTime(2026, 7, 18),
    summary: 'Bon trimestre. Amina progresse en anglais et en mathématiques.',
    isCurrentPeriod: true,
  ),
];

final _defaultUpcomingAgenda = [
  const HomeDayItem(
    id: 'd1',
    title: 'Mathématiques',
    subtitle: 'M. Diallo',
    startHour: 8,
    endHour: 9,
    category: HomeDayCategory.lesson,
    sessionId: 's1',
  ),
  const HomeDayItem(
    id: 'd2',
    title: 'Anglais',
    subtitle: 'Mme Lawson',
    startHour: 10,
    endHour: 11,
    category: HomeDayCategory.lesson,
    sessionId: 's2',
  ),
  const HomeDayItem(
    id: 'd3',
    title: 'Contrôle de français',
    subtitle: 'Évaluation écrite · Mme Traoré',
    startHour: 11,
    endHour: 12,
    category: HomeDayCategory.assessment,
    sessionId: 's4',
  ),
  const HomeDayItem(
    id: 'd4',
    title: 'Sport',
    subtitle: 'Gymnase · M. Koné',
    startHour: 14,
    endHour: 15,
    category: HomeDayCategory.activity,
    sessionId: 's3',
  ),
];

final _defaultUpcomingFees = [
  HomeFinanceAlert(
    id: 'f1',
    label: 'Scolarité — Collège',
    amount: 150000,
    currency: 'EUR',
    dueDate: DateTime(2026, 5, 30),
    isOverdue: true,
  ),
  HomeFinanceAlert(
    id: 'f2',
    label: 'Cantine — Trimestre 2',
    amount: 45000,
    currency: 'EUR',
    dueDate: DateTime(2026, 9, 15),
    isOverdue: false,
  ),
];

final _defaultFees = [
  MockFeeLine(
    id: 'f1',
    label: 'Scolarité — Collège',
    expected: 450000,
    paid: 300000,
    currency: 'EUR',
    status: 'En retard',
    dueDate: DateTime(2026, 5, 30),
    paymentCount: 2,
    description:
        'Frais de scolarité annuels pour l\'année 2025 — 2026, '
        'répartis en trois échéances trimestrielles.',
  ),
];

final _defaultFeeInstallments = [
  MockFeeInstallment(
    id: 'i1',
    feeLineId: 'f1',
    label: '1re échéance',
    amount: 150000,
    paid: 150000,
    currency: 'EUR',
    dueDate: DateTime(2026, 1, 15),
    status: 'Payé',
  ),
  MockFeeInstallment(
    id: 'i2',
    feeLineId: 'f1',
    label: '2e échéance',
    amount: 150000,
    paid: 150000,
    currency: 'EUR',
    dueDate: DateTime(2026, 3, 30),
    status: 'Payé',
  ),
  MockFeeInstallment(
    id: 'i3',
    feeLineId: 'f1',
    label: '3e échéance',
    amount: 150000,
    paid: 0,
    currency: 'EUR',
    dueDate: DateTime(2026, 5, 30),
    status: 'En retard',
  ),
];

final _defaultPayments = [
  MockPayment(
    id: 'p1',
    feeLineId: 'f1',
    feeLabel: 'Scolarité — Collège',
    amount: 150000,
    currency: 'EUR',
    method: 'Virement bancaire',
    date: DateTime(2026, 3, 15),
  ),
  MockPayment(
    id: 'p2',
    feeLineId: 'f1',
    feeLabel: 'Scolarité — Collège',
    amount: 150000,
    currency: 'EUR',
    method: 'Virement bancaire',
    date: DateTime(2026, 1, 10),
  ),
];

final _defaultMessages = [
  MockMessage(
    id: 'm1',
    title: 'Rentrée scolaire 2025',
    body:
        'La rentrée des classes aura lieu le lundi 15 septembre à 7h30. Merci de vérifier les fournitures.',
    sentAt: DateTime(2026, 7, 15),
    read: true,
  ),
  MockMessage(
    id: 'm2',
    title: 'Réunion parents-professeurs',
    body: 'La réunion se tiendra le 20 octobre à 18h en salle polyvalente.',
    sentAt: DateTime(2026, 1, 28),
    read: false,
  ),
];
