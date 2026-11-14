import 'package:edaya_shared/edaya_shared.dart' show systemL10n;
import 'package:flutter/foundation.dart';
import '../features/session/session_logbook_draft_storage.dart';

part 'models.dart';
part 'fixtures.dart';

class MockStore extends ChangeNotifier {
  MockStore() {
    _schools.add(_school);
    _selectedYear = _school.years.first;
    _assignments.addAll(_defaultAssignments);
    _students.addAll(_buildStudents());
    activeAssignmentId = _defaultAssignments.first.id;
    _calendarWeekStart = mondayOf(DateTime.now());
    selectedDayIndex = DateTime.now().weekday - 1;
    if (selectedDayIndex > 4) selectedDayIndex = 0;
    _sessions.addAll(_buildSessions(_calendarWeekStart));
    _attendance.addAll(_buildAttendance(_sessions, _students));
    _logbooks.addAll(_buildLogbooks(_sessions));
    _evaluations.addAll(_buildEvaluations());
    _marks.addAll(_buildMarks(_evaluations, _students));
    _reportCardClasses.addAll(_buildReportCardClasses());
    _reportCardStudents.addAll(_buildReportCardRoster(_students));
    _messages.addAll(_buildMessages());
    _familyFeedback.addAll(const [
      MockFamilyFeedback(
        id: 'ff-open',
        title: 'Avis familles · Français',
        subtitle: '6e A · à consulter',
        open: true,
      ),
      MockFamilyFeedback(
        id: 'ff-done',
        title: 'Avis familles · Mathématiques',
        subtitle: '5e B · archive',
        open: false,
      ),
    ]);
  }

  bool isAuthenticated = false;

  final List<MockSchool> _schools = [];
  late String _selectedYear;
  final List<MockClassAssignment> _assignments = [];
  late String activeAssignmentId;
  final List<MockStudent> _students = [];
  final List<MockSession> _sessions = [];
  final Map<String, List<MockAttendanceRecord>> _attendance = {};
  final Map<String, MockLogbook> _logbooks = {};
  final List<MockEvaluation> _evaluations = [];
  final List<MockMark> _marks = [];
  final List<MockReportCardClass> _reportCardClasses = [];
  final List<MockReportCardStudent> _reportCardStudents = [];
  final List<MockMessage> _messages = [];
  final List<MockFamilyFeedback> _familyFeedback = [];

  late DateTime _calendarWeekStart;
  int selectedDayIndex = 0;

  static DateTime mondayOf(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(
      Duration(days: normalized.weekday - DateTime.monday),
    );
  }

  void signIn() {
    isAuthenticated = true;
    notifyListeners();
  }

  void signOut() {
    isAuthenticated = false;
    notifyListeners();
  }

  MockTeacher get teacher => _teacher;
  String get teacherFullName => _teacher.fullName;
  String get teacherInitials => _teacher.initials;

  List<MockSchool> get schools => List.unmodifiable(_schools);
  MockSchool get activeSchool => _schools.first;
  String get selectedYear => _selectedYear;
  List<String> get years => activeSchool.years;

  void selectYear(String year) {
    _selectedYear = year;
    notifyListeners();
  }

  List<MockClassAssignment> get assignments => List.unmodifiable(_assignments);

  MockClassAssignment get activeAssignment =>
      _assignments.firstWhere((a) => a.id == activeAssignmentId);

  void selectAssignment(String id) {
    activeAssignmentId = id;
    notifyListeners();
  }

  List<MockStudent> get students => List.unmodifiable(_students);

  List<MockStudent> studentsFor(String classId) =>
      _students.where((s) => s.classId == classId).toList();

  MockStudent? studentById(String id) {
    try {
      return _students.firstWhere((s) => s.id == id);
    } on Object {
      return null;
    }
  }

  DateTime get calendarWeekStart => _calendarWeekStart;

  DateTime get selectedCalendarDate =>
      _calendarWeekStart.add(Duration(days: selectedDayIndex));

  DateTime dateForWeekDay(int index) =>
      _calendarWeekStart.add(Duration(days: index));

  void setCalendarWeek(DateTime monday) {
    _calendarWeekStart = mondayOf(monday);
    _sessions
      ..clear()
      ..addAll(_buildSessions(_calendarWeekStart));
    _attendance
      ..clear()
      ..addAll(_buildAttendance(_sessions, _students));
    notifyListeners();
  }

  void selectDay(int index) {
    selectedDayIndex = index.clamp(0, 6);
    notifyListeners();
  }

  void selectCalendarDate(DateTime date) {
    _calendarWeekStart = mondayOf(date);
    selectedDayIndex = date.weekday - 1;
    _sessions
      ..clear()
      ..addAll(_buildSessions(_calendarWeekStart));
    _attendance
      ..clear()
      ..addAll(_buildAttendance(_sessions, _students));
    notifyListeners();
  }

  void openCalendarDay(int dayOffset) {
    final target = DateTime.now().add(Duration(days: dayOffset));
    selectCalendarDate(target);
  }

  List<MockSession> get sessions => List.unmodifiable(_sessions);

  List<MockSession> sessionsForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _sessions
        .where(
          (s) =>
              s.date.year == d.year &&
              s.date.month == d.month &&
              s.date.day == d.day,
        )
        .toList()
      ..sort((a, b) => a.startHour.compareTo(b.startHour));
  }

  List<MockSession> get selectedDaySessions =>
      sessionsForDay(selectedCalendarDate);

  MockSession? sessionById(String id) {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } on Object {
      return null;
    }
  }

  MockSession? get currentSession {
    final now = DateTime.now();
    final today = sessionsForDay(now);
    for (final s in today) {
      if (now.hour >= s.startHour && now.hour < s.endHour) return s;
    }
    return null;
  }

  MockSession? get nextSession {
    final now = DateTime.now();
    final today = sessionsForDay(now);
    for (final s in today) {
      if (s.startHour > now.hour) return s;
    }
    return null;
  }

  List<MockAttendanceRecord> getAttendance(String sessionId) =>
      List.unmodifiable(_attendance[sessionId] ?? const []);

  void setAttendanceStatus(
    String sessionId,
    String studentId,
    AttendanceStatus status, {
    String? comment,
  }) {
    final list = _attendance[sessionId];
    if (list == null) return;
    final record = list.firstWhere((r) => r.studentId == studentId);
    record.status = status;
    record.comment = comment ?? record.comment;
    notifyListeners();
  }

  void markAllPresent(String sessionId) {
    final list = _attendance[sessionId];
    if (list == null) return;
    for (final r in list) {
      r.status ??= AttendanceStatus.present;
    }
    notifyListeners();
  }

  void completeAttendance(String sessionId) {
    final session = sessionById(sessionId);
    if (session == null) return;
    session.attendanceComplete = true;
    notifyListeners();
  }

  MockLogbook? getLogbook(String sessionId) => _logbooks[sessionId];

  static const programmeChapters = {
    'fractions': 'Fractions',
    'decimals': 'Nombres décimaux',
    'geometry': 'Géométrie',
  };
  final logbookDrafts = <String, Map<String, LogbookEdit>>{};
  void saveLogbook(String sessionId, LogbookEdit edit) {
    final book = _logbooks.putIfAbsent(
      sessionId,
      () => MockLogbook(sessionId: sessionId),
    );
    if (edit.note case final note?) {
      book.content = note.content;
      book.objectives = note.objectives.join('\n');
      book.homework = note.homework ?? '';
      book.familySummary = note.familySummary ?? '';
    } else {
      book.chapters[edit.chapterId!] = edit.percentage!;
    }
    logbookDrafts[sessionId]?.remove(edit.key);
    sessionById(sessionId)?.logbookComplete = true;
    notifyListeners();
  }

  List<MockEvaluation> get evaluations => List.unmodifiable(_evaluations);

  List<MockEvaluation> get evaluationsNeedingMarks =>
      _evaluations.where((e) => e.needsMarks).toList();

  MockEvaluation? evaluationById(String id) {
    try {
      return _evaluations.firstWhere((e) => e.id == id);
    } on Object {
      return null;
    }
  }

  List<MockMark> marksFor(String evaluationId) =>
      _marks.where((m) => m.evaluationId == evaluationId).toList();

  void setMark(String evaluationId, String studentId, double? score) {
    final mark = _marks.firstWhere(
      (m) => m.evaluationId == evaluationId && m.studentId == studentId,
    );
    mark.score = score;
    final eval = evaluationById(evaluationId);
    if (eval != null) {
      eval.gradedCount = marksFor(
        evaluationId,
      ).where((m) => m.score != null).length;
    }
    notifyListeners();
  }

  List<MockReportCardClass> get reportCardClasses =>
      List.unmodifiable(_reportCardClasses);

  List<MockReportCardStudent> rosterFor(String classId, String periodId) =>
      _reportCardStudents
          .where((r) => r.classId == classId && r.periodId == periodId)
          .toList();

  MockReportCardStudent? reportCardStudentById(String id) {
    try {
      return _reportCardStudents.firstWhere((r) => r.id == id);
    } on Object {
      return null;
    }
  }

  void saveComment({
    required String rosterId,
    String? homeroomComment,
    String? subjectComment,
  }) {
    final row = reportCardStudentById(rosterId);
    if (row == null) return;
    if (homeroomComment != null) {
      row.homeroomComment = homeroomComment;
      row.hasHomeroomComment = homeroomComment.trim().isNotEmpty;
    }
    if (subjectComment != null) {
      row.subjectComment = subjectComment;
      row.hasSubjectComment = subjectComment.trim().isNotEmpty;
    }
    notifyListeners();
  }

  List<MockMessage> get messages => List.unmodifiable(_messages);

  int get unreadCount => _messages.where((m) => !m.read).length;

  MockMessage? messageById(String id) {
    try {
      return _messages.firstWhere((m) => m.id == id);
    } on Object {
      return null;
    }
  }

  void markRead(String id) {
    final m = messageById(id);
    if (m == null) return;
    m.read = true;
    notifyListeners();
  }

  List<MockSession> get incompleteAttendanceToday {
    final today = sessionsForDay(DateTime.now());
    return today.where((s) => !s.attendanceComplete).toList();
  }

  List<MockSession> get incompleteLogbookToday {
    final today = sessionsForDay(DateTime.now());
    return today.where((s) => !s.logbookComplete).toList();
  }

  List<MockTask> get todayTasks {
    final tasks = <MockTask>[];
    for (final item in _familyFeedback.where((item) => item.open)) {
      tasks.add(
        MockTask(
          id: 'ff-${item.id}',
          kind: 'feedback',
          title: item.title,
          subtitle: item.subtitle,
          route: '/home/avis/${item.id}',
        ),
      );
    }
    for (final s in incompleteAttendanceToday) {
      tasks.add(
        MockTask(
          id: 'att-${s.id}',
          kind: 'attendance',
          title: 'Présences à saisir',
          subtitle: '${s.classLabel} · ${s.startHour}h–${s.endHour}h',
          route: '/session/${s.id}/attendance',
        ),
      );
    }
    for (final s in incompleteLogbookToday) {
      tasks.add(
        MockTask(
          id: 'log-${s.id}',
          kind: 'logbook',
          title: systemL10n().logbook,
          subtitle: '${s.classLabel} · ${s.subject}',
          route: '/session/${s.id}/logbook',
        ),
      );
    }
    for (final e in evaluationsNeedingMarks) {
      tasks.add(
        MockTask(
          id: 'marks-${e.id}',
          kind: 'marks',
          title: 'Notes à saisir',
          subtitle: '${e.title} · ${e.gradedCount}/${e.totalCount}',
          route: '/evaluations/${e.id}/marks',
        ),
      );
    }
    for (final rc in _reportCardClasses.where((c) => c.pendingComments > 0)) {
      tasks.add(
        MockTask(
          id: 'rc-${rc.id}',
          kind: 'comments',
          title: 'Commentaires bulletin',
          subtitle: '${rc.classLabel} · ${rc.pendingComments} en attente',
          route: '/evaluations/report-cards/${rc.classId}/${rc.periodId}',
        ),
      );
    }
    if (unreadCount > 0) {
      tasks.add(
        MockTask(
          id: 'inbox',
          kind: 'message',
          title: 'Messages non lus',
          subtitle: '$unreadCount message(s)',
          route: '/inbox',
        ),
      );
    }
    return tasks;
  }

  List<MockFamilyFeedback> get familyFeedback =>
      List.unmodifiable(_familyFeedback);

  MockFamilyFeedback? familyFeedbackById(String id) {
    try {
      return _familyFeedback.firstWhere((item) => item.id == id);
    } on Object {
      return null;
    }
  }
}
