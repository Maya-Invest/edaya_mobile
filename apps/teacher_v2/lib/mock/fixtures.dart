part of 'mock_store.dart';

final _school = const MockSchool(
  id: 'school-1',
  name: 'Collège Moderne Plateau',
  years: ['2025-2026', '2024-2025'],
);

final _teacher = const MockTeacher(
  id: 'teacher-1',
  firstName: 'Aminata',
  lastName: 'Traoré',
  email: 'enseignant@demo.ci',
);

final _defaultAssignments = const [
  MockClassAssignment(
    id: 'asg-6a',
    classId: 'cls-6a',
    classLabel: '6ème A',
    subject: 'Mathématiques',
    isHomeroom: false,
    studentCount: 10,
  ),
  MockClassAssignment(
    id: 'asg-5b',
    classId: 'cls-5b',
    classLabel: '5ème B',
    subject: 'Mathématiques',
    isHomeroom: true,
    studentCount: 10,
  ),
  MockClassAssignment(
    id: 'asg-3a',
    classId: 'cls-3a',
    classLabel: '3ème A',
    subject: 'Mathématiques',
    isHomeroom: false,
    studentCount: 8,
  ),
];

List<MockStudent> _buildStudents() {
  const sixA = [
    ('s-6a-01', 'Amina', 'Koné'),
    ('s-6a-02', 'Yao', 'Kouassi'),
    ('s-6a-03', 'Fatou', 'Diallo'),
    ('s-6a-04', 'Ibrahim', 'Touré'),
    ('s-6a-05', 'Mariame', 'Sangaré'),
    ('s-6a-06', 'Koffi', 'N\'Guessan'),
    ('s-6a-07', 'Awa', 'Bamba'),
    ('s-6a-08', 'Sébastien', 'Aka'),
    ('s-6a-09', 'Rokia', 'Ouattara'),
    ('s-6a-10', 'Jean', 'Brou'),
  ];
  const fiveB = [
    ('s-5b-01', 'Mariam', 'Cissé'),
    ('s-5b-02', 'Ousmane', 'Diabaté'),
    ('s-5b-03', 'Chantal', 'Yao'),
    ('s-5b-04', 'Adama', 'Konaté'),
    ('s-5b-05', 'Inès', 'Gnahoré'),
    ('s-5b-06', 'Moussa', 'Traoré'),
    ('s-5b-07', 'Patricia', 'Kouamé'),
    ('s-5b-08', 'Serge', 'Doh'),
    ('s-5b-09', 'Nadège', 'Assi'),
    ('s-5b-10', 'Ismaël', 'Bakayoko'),
  ];
  const threeA = [
    ('s-3a-01', 'Grace', 'Mensah'),
    ('s-3a-02', 'Kevin', 'Aka'),
    ('s-3a-03', 'Léa', 'Kouadio'),
    ('s-3a-04', 'Paul', 'N\'Dri'),
    ('s-3a-05', 'Sarah', 'Zadi'),
    ('s-3a-06', 'David', 'Koffi'),
    ('s-3a-07', 'Esther', 'Bamba'),
    ('s-3a-08', 'Franck', 'Yao'),
  ];
  return [
    for (final e in sixA)
      MockStudent(id: e.$1, classId: 'cls-6a', firstName: e.$2, lastName: e.$3),
    for (final e in fiveB)
      MockStudent(id: e.$1, classId: 'cls-5b', firstName: e.$2, lastName: e.$3),
    for (final e in threeA)
      MockStudent(id: e.$1, classId: 'cls-3a', firstName: e.$2, lastName: e.$3),
  ];
}

DateTime _day(DateTime monday, int weekday, {int hour = 8}) {
  final d = monday.add(Duration(days: weekday - 1));
  return DateTime(d.year, d.month, d.day, hour);
}

List<MockSession> _buildSessions(DateTime weekMonday) {
  final sessions = <MockSession>[];
  var i = 0;
  void add(
    String classId,
    String classLabel,
    int weekday,
    int start,
    int end, {
    String room = 'Salle 12',
    bool attendance = true,
    bool logbook = true,
  }) {
    i++;
    sessions.add(
      MockSession(
        id: 'sess-$i',
        classId: classId,
        classLabel: classLabel,
        subject: 'Mathématiques',
        date: _day(weekMonday, weekday, hour: start),
        startHour: start,
        endHour: end,
        room: room,
        attendanceComplete: attendance,
        logbookComplete: logbook,
      ),
    );
  }

  // Monday
  add('cls-6a', '6ème A', 1, 8, 9);
  add('cls-5b', '5ème B', 1, 10, 11);
  add('cls-3a', '3ème A', 1, 14, 15);
  // Tuesday — incomplete today-ish tasks on mid-week
  add('cls-6a', '6ème A', 2, 8, 9, attendance: false, logbook: false);
  add('cls-5b', '5ème B', 2, 11, 12);
  // Wednesday
  add('cls-3a', '3ème A', 3, 8, 9, attendance: false);
  add('cls-6a', '6ème A', 3, 10, 11, logbook: false);
  add('cls-5b', '5ème B', 3, 15, 16);
  // Thursday
  add('cls-5b', '5ème B', 4, 8, 9);
  add('cls-3a', '3ème A', 4, 10, 11);
  add('cls-6a', '6ème A', 4, 14, 15);
  // Friday
  add('cls-6a', '6ème A', 5, 8, 9);
  add('cls-5b', '5ème B', 5, 10, 11);
  add('cls-3a', '3ème A', 5, 14, 15);

  // Align incomplete sessions to "today" when weekday is school day.
  final today = DateTime.now();
  final todayWd = today.weekday;
  if (todayWd >= 1 && todayWd <= 5) {
    for (final s in sessions) {
      if (s.date.weekday == todayWd) {
        // Keep first incomplete flags from seed; ensure at least one incomplete today.
      }
    }
    final todaySessions = sessions
        .where((s) => s.date.weekday == todayWd)
        .toList();
    if (todaySessions.isNotEmpty) {
      todaySessions.first.attendanceComplete = false;
      todaySessions.first.logbookComplete = false;
      if (todaySessions.length > 1) {
        todaySessions[1].logbookComplete = false;
      }
    }
  }

  return sessions;
}

Map<String, List<MockAttendanceRecord>> _buildAttendance(
  List<MockSession> sessions,
  List<MockStudent> students,
) {
  final map = <String, List<MockAttendanceRecord>>{};
  for (final session in sessions) {
    final roster = students.where((s) => s.classId == session.classId);
    map[session.id] = [
      for (final s in roster)
        MockAttendanceRecord(
          studentId: s.id,
          status: session.attendanceComplete ? AttendanceStatus.present : null,
        ),
    ];
  }
  return map;
}

Map<String, MockLogbook> _buildLogbooks(List<MockSession> sessions) {
  return {
    for (final s in sessions)
      if (s.logbookComplete)
        s.id: MockLogbook(
          sessionId: s.id,
          content: 'Chapitre fractions — exercices 1 à 8',
          objectives: 'Maîtriser l\'addition de fractions',
          homework: 'Exercices 9–12 page 54',
          chapters: {'fractions': 62, 'decimals': 30},
        ),
  };
}

List<MockEvaluation> _buildEvaluations() {
  final now = DateTime.now();
  return [
    MockEvaluation(
      id: 'eval-1',
      classId: 'cls-6a',
      classLabel: '6ème A',
      subject: 'Mathématiques',
      title: 'Devoir surveillé — Fractions',
      period: '1er trimestre',
      maxScore: 20,
      coefficient: 2,
      dueDate: now.subtract(const Duration(days: 2)),
      gradedCount: 6,
      totalCount: 10,
    ),
    MockEvaluation(
      id: 'eval-2',
      classId: 'cls-5b',
      classLabel: '5ème B',
      subject: 'Mathématiques',
      title: 'Interro — Équations',
      period: '1er trimestre',
      maxScore: 20,
      coefficient: 1,
      dueDate: now.subtract(const Duration(days: 5)),
      gradedCount: 10,
      totalCount: 10,
    ),
    MockEvaluation(
      id: 'eval-3',
      classId: 'cls-3a',
      classLabel: '3ème A',
      subject: 'Mathématiques',
      title: 'DS — Géométrie',
      period: '1er trimestre',
      maxScore: 20,
      coefficient: 3,
      dueDate: now.add(const Duration(days: 3)),
      gradedCount: 0,
      totalCount: 8,
    ),
    MockEvaluation(
      id: 'eval-4',
      classId: 'cls-6a',
      classLabel: '6ème A',
      subject: 'Mathématiques',
      title: 'Devoir maison — Proportions',
      period: '1er trimestre',
      maxScore: 10,
      coefficient: 1,
      dueDate: now.add(const Duration(days: 7)),
      gradedCount: 2,
      totalCount: 10,
    ),
  ];
}

List<MockMark> _buildMarks(
  List<MockEvaluation> evals,
  List<MockStudent> students,
) {
  final marks = <MockMark>[];
  for (final e in evals) {
    final roster = students.where((s) => s.classId == e.classId).toList();
    for (var i = 0; i < roster.length; i++) {
      final graded = i < e.gradedCount;
      marks.add(
        MockMark(
          evaluationId: e.id,
          studentId: roster[i].id,
          score: graded ? (8 + (i % 10)).toDouble() : null,
        ),
      );
    }
  }
  return marks;
}

List<MockReportCardClass> _buildReportCardClasses() => const [
  MockReportCardClass(
    id: 'rc-5b-t1',
    classId: 'cls-5b',
    classLabel: '5ème B',
    period: '1er trimestre',
    periodId: 't1',
    pendingComments: 4,
    totalStudents: 10,
  ),
  MockReportCardClass(
    id: 'rc-6a-t1',
    classId: 'cls-6a',
    classLabel: '6ème A',
    period: '1er trimestre',
    periodId: 't1',
    pendingComments: 7,
    totalStudents: 10,
  ),
];

List<MockReportCardStudent> _buildReportCardRoster(List<MockStudent> students) {
  final roster = <MockReportCardStudent>[];
  void addClass(String classId, String periodId, {required bool homeroom}) {
    final kids = students.where((s) => s.classId == classId).toList();
    for (var i = 0; i < kids.length; i++) {
      final done = i % 3 == 0;
      roster.add(
        MockReportCardStudent(
          id: 'rcs-$classId-$periodId-${kids[i].id}',
          classId: classId,
          periodId: periodId,
          studentId: kids[i].id,
          studentName: kids[i].fullName,
          average: 10 + (i % 8).toDouble(),
          rank: i + 1,
          hasHomeroomComment: homeroom && done,
          hasSubjectComment: !homeroom && done,
          homeroomComment: homeroom && done ? 'Élève sérieux et appliqué.' : '',
          subjectComment: !homeroom && done ? 'Bons progrès en calcul.' : '',
        ),
      );
    }
  }

  addClass('cls-5b', 't1', homeroom: true);
  addClass('cls-6a', 't1', homeroom: false);
  return roster;
}

List<MockMessage> _buildMessages() {
  final now = DateTime.now();
  return [
    MockMessage(
      id: 'msg-1',
      title: 'Conseil de classe — 5ème B',
      body:
          'Le conseil de classe du 1er trimestre aura lieu mardi prochain à 16h. Merci de préparer vos commentaires.',
      sentAt: now.subtract(const Duration(hours: 3)),
      read: false,
      type: 'announcement',
    ),
    MockMessage(
      id: 'msg-2',
      title: 'Bulletins à compléter',
      body:
          '4 commentaires de bulletin sont encore en attente pour la 5ème B (1er trimestre).',
      sentAt: now.subtract(const Duration(hours: 8)),
      read: false,
      type: 'notification',
    ),
    MockMessage(
      id: 'msg-3',
      title: 'Réunion pédagogique',
      body:
          'Réunion département mathématiques vendredi 12h en salle des professeurs.',
      sentAt: now.subtract(const Duration(days: 1)),
      read: true,
      type: 'announcement',
    ),
    MockMessage(
      id: 'msg-4',
      title: 'Absence élève — Amina Koné',
      body: 'Absence justifiée pour Amina Koné (6ème A) le mardi.',
      sentAt: now.subtract(const Duration(days: 2)),
      read: true,
      type: 'notification',
    ),
    MockMessage(
      id: 'msg-5',
      title: 'Calendrier des devoirs',
      body:
          'Merci de saisir les dates de devoirs dans le cahier de texte avant vendredi.',
      sentAt: now.subtract(const Duration(days: 3)),
      read: false,
      type: 'announcement',
    ),
  ];
}
