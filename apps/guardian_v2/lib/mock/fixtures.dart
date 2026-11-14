part of 'mock_store.dart';

final _defaultSchools = [
  const MockSchool(
    id: 'school-college',
    name: 'Collège Lumière d\'Abidjan',
    years: ['2025 — 2026', '2024 — 2025', '2023 — 2024', '2022 — 2023'],
  ),
  const MockSchool(
    id: 'school-lycee',
    name: 'Lycée Moderne de Cocody',
    years: ['2025 — 2026', '2024 — 2025', '2023 — 2024'],
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
      description:
          'Dictée sur les homophones et les accords dans le groupe nominal.',
      instructions:
          'Aucune préparation spécifique — révision des règles vues en classe.',
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
    'Sciences': MockSubjectPeriodMeta(state: MockResultsPublicationState.draft),
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
