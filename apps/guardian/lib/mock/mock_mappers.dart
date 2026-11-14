import '../features/calendar/models/calendar_session.dart';
import '../features/calendar/models/logbook_entry.dart';
import '../features/calendar/models/school_event.dart';
import '../features/scolarite/models/grade_entry.dart';
import 'mock_store.dart';

String mockSessionKind(HomeDayCategory category) {
  return switch (category) {
    HomeDayCategory.lesson => 'lesson',
    HomeDayCategory.activity => 'activity',
    HomeDayCategory.assessment => 'assessment',
  };
}

CalendarSession calendarSessionFromMock(MockSession session) {
  final startsAt = DateTime(
    session.date.year,
    session.date.month,
    session.date.day,
    session.startHour,
  );
  final endsAt = DateTime(
    session.date.year,
    session.date.month,
    session.date.day,
    session.endHour,
  );
  return CalendarSession(
    id: session.id,
    title: session.subject,
    kind: mockSessionKind(session.category),
    startsAt: startsAt,
    endsAt: endsAt,
    subjectLabel: session.subject,
  );
}

SchoolEvent schoolEventFromMock(MockEvent event) {
  return SchoolEvent(
    id: event.id,
    title: event.title,
    startDate: event.date,
    endDate: event.endDate ?? event.date,
    kind: event.kind,
    isNonSchoolDay: event.isNonSchoolDay,
    description: event.description,
  );
}

LogbookEntry logbookEntryFromMock(MockLogbookEntry entry) {
  return LogbookEntry(
    id: entry.id,
    chapter: entry.chapter,
    content: entry.content,
    progress: entry.progress,
    date: entry.date,
    homework: entry.homework,
    objectives: entry.objectives,
  );
}

GradeEntry gradeEntryFromMock(MockGrade grade) {
  return GradeEntry(
    id: grade.id,
    assessmentId: grade.id,
    title: grade.title,
    subjectName: grade.subject,
    periodId: grade.period,
    periodName: grade.period,
    maxScore: grade.maxScore,
    coefficient: grade.coefficient,
    date: grade.date,
    score: grade.score,
  );
}
