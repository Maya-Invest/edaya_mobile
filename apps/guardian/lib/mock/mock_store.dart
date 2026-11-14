import 'package:flutter/foundation.dart';

part 'models.dart';
part 'fixtures.dart';

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
  String get guardianInitials =>
      '${guardianFirstName[0]}${guardianLastName[0]}';

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
    return normalized.subtract(
      Duration(days: normalized.weekday - DateTime.monday),
    );
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
          students: _students
              .where((student) => student.schoolId == school.id)
              .toList(),
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
      return _academicPeriods.firstWhere(
        (period) => period.id == selectedPeriodId,
      );
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

  List<MockTopic> get topicsForSelectedSubject =>
      topicsForSubject(selectedSubject);

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
    final subjectsWithProgramme = subjects.where(
      (subject) => topicsForSubject(subject).isNotEmpty,
    );
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
    return _grades.where((grade) => grade.period == periodLabel).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<MockGrade> gradesForSubjectAndPeriod(
    String subject,
    String periodLabel,
  ) {
    return _grades
        .where(
          (grade) => grade.subject == subject && grade.period == periodLabel,
        )
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
    }).toList()..sort((a, b) => a.subject.compareTo(b.subject));
  }

  MockSubjectPeriodResults? subjectResultsFor(
    String subject,
    String periodLabel,
  ) {
    try {
      return subjectResultsForPeriod(
        periodLabel,
      ).firstWhere((result) => result.subject == subject);
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
    return _payments.where((payment) => payment.feeLineId == feeLineId).toList()
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

  List<HomeFinanceAlert> get homeFinanceAlerts =>
      List.unmodifiable(_upcomingFees);

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

  List<MockEvent> get schoolEventsForSelectedDay =>
      eventsForSelectedDay.where((event) => !event.isNonSchoolDay).toList();

  List<MockSession> sessionsForDay(DateTime day) {
    return _sessions
        .where((session) => _isSameCalendarDay(session.date, day))
        .toList()
      ..sort((a, b) => a.startHour.compareTo(b.startHour));
  }

  List<MockSession> get sessionsForSelectedDay =>
      sessionsForDay(selectedCalendarDate);

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

  int dayIndexForOffset(int dayOffset) =>
      dateForDayOffset(dayOffset).weekday - 1;

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
  int get overdueFeeCount =>
      _feeLines.where((f) => f.status == 'En retard').length;

  double get feeExpected => _feeLines.fold(0, (s, f) => s + f.expected);
  double get feePaid => _feeLines.fold(0, (s, f) => s + f.paid);
  double get feeBalance => (feeExpected - feePaid).clamp(0, feeExpected);

  MockSession? get nextSessionToday {
    final nowHour = DateTime.now().hour;
    final todaySessions =
        _sessions
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
