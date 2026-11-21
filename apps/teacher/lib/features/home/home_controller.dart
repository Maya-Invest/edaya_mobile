import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../calendar/live_calendar_controller.dart';
import '../evaluations/family_feedback_controller.dart';
import '../evaluations/live_evaluations_controller.dart';
import '../inbox/live_inbox_controller.dart';
import '../report_cards/live_report_cards_controller.dart';
import 'accueil_task.dart';

class LiveHomeController extends LevitController {
  LiveHomeController({
    required LiveCalendarController calendar,
    required LiveEvaluationsController evaluations,
    required LiveFamilyFeedbackController familyFeedback,
    required LiveReportCardsController reportCards,
    required LiveInboxController inbox,
  }) : _calendar = calendar,
       _evaluations = evaluations,
       _familyFeedback = familyFeedback,
       _reportCards = reportCards,
       _inbox = inbox;

  final LiveCalendarController _calendar;
  final LiveEvaluationsController _evaluations;
  final LiveFamilyFeedbackController _familyFeedback;
  final LiveReportCardsController _reportCards;
  final LiveInboxController _inbox;
  final tick = LxVar(0);

  @override
  void onInit() {
    super.onInit();
    autoDispose(tick);
    for (final subscription in [
      _calendar.sessions.stream,
      _calendar.attendanceCompletionBySessionId.stream,
      _calendar.logbookCompleteBySessionId.stream,
      _evaluations.evaluations.stream,
      _familyFeedback.results.stream,
      _reportCards.classSummaries.stream,
      _inbox.noticeUnreadChanges,
      _inbox.conversationUnread.stream,
    ]) {
      autoDispose(subscription.listen((_) => tick.value++));
    }
  }

  List<AccueilTask> get tasks {
    final items = <AccueilTask>[];
    for (final item in _familyFeedback.openResults) {
      items.add(
        AccueilTask(
          id: 'ff-${item.campaignId}',
          kind: 'feedback',
          title: systemL10n().teacherTaskFamilyFeedback,
          subtitle: systemL10n().surveyResponseRatio(
            item.completedSlotCount,
            item.eligibleSlotCount,
          ),
          route: '/home/avis/${item.campaignId}',
          priority: 1,
        ),
      );
    }
    for (final session in _calendar.incompleteAttendanceSessions) {
      items.add(
        AccueilTask(
          id: 'att-${session.id}',
          kind: 'attendance',
          title: systemL10n().teacherTaskAttendance,
          subtitle: '${session.classLabel} · ${session.subjectLabel}',
          route: '/session/${session.id}/attendance',
          priority: 2,
        ),
      );
    }
    for (final session in _calendar.incompleteLogbookSessions) {
      items.add(
        AccueilTask(
          id: 'log-${session.id}',
          kind: 'logbook',
          title: systemL10n().teacherTaskLogbook,
          subtitle: '${session.classLabel} · ${session.subjectLabel}',
          route: '/session/${session.id}/logbook',
          priority: 3,
        ),
      );
    }
    for (final evaluation in _evaluations.needingMarks) {
      items.add(
        AccueilTask(
          id: 'marks-${evaluation.id}',
          kind: 'marks',
          title: systemL10n().teacherTaskMarks,
          subtitle:
              '${evaluation.title} · ${evaluation.gradedCount}/${evaluation.totalStudents}',
          route: '/evaluations/${evaluation.id}/marks',
          priority: 4,
        ),
      );
    }
    for (final bulletin in _reportCards.pendingCommentClasses) {
      items.add(
        AccueilTask(
          id: 'rc-${bulletin.classGroupId}-${bulletin.periodId}',
          kind: 'bulletin',
          title: systemL10n().teacherTaskReportComments,
          subtitle: systemL10n().pendingLabel(
            bulletin.classLabel,
            bulletin.pendingComments,
          ),
          route:
              '/evaluations/report-cards/${bulletin.classGroupId}/${bulletin.periodId}',
          priority: 5,
        ),
      );
    }
    if (_inbox.unreadCount > 0) {
      items.add(
        AccueilTask(
          id: 'inbox-unread',
          kind: 'inbox',
          title: systemL10n().unreadMessages,
          subtitle: systemL10n().toRead(_inbox.unreadCount),
          route: '/inbox',
          priority: 6,
        ),
      );
    }
    items.sort((a, b) => a.priority.compareTo(b.priority));
    return items;
  }

  AccueilTask? get primaryTask => tasks.isEmpty ? null : tasks.first;

  int get remainingCount => tasks.length <= 1 ? 0 : tasks.length - 1;
}
