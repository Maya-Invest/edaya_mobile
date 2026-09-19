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
      _inbox.deliveries.stream,
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
          title: 'Avis des familles',
          subtitle:
              '${item.completedSlotCount}/${item.eligibleSlotCount} réponses',
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
          title: 'Présences à saisir',
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
          title: 'Cahier de texte',
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
          title: 'Notes à saisir',
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
          title: 'Commentaires de bulletin',
          subtitle:
              '${bulletin.classLabel} · ${bulletin.pendingComments} en attente',
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
          title: 'Messages non lus',
          subtitle: '${_inbox.unreadCount} à lire',
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
