part of 'mock_store.dart';

class MockSchool {
  const MockSchool({required this.id, required this.name, required this.years});

  final String id;
  final String name;
  final List<String> years;
}

class SchoolStudentGroup {
  const SchoolStudentGroup({required this.school, required this.students});

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
        : average!.toStringAsFixed(2).replaceAll('.', ',');
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
