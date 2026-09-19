import 'package:edaya_shared/edaya_shared.dart';

import 'teacher_route_paths.dart';

/// Teacher-app notification destinations and safe fallbacks.
abstract final class TeacherNotificationTargets {
  static const calendar = TeacherRoutePaths.calendar;
  static const evaluations = TeacherRoutePaths.evaluations;
  static const teaching = TeacherRoutePaths.teaching;
  static const reportCards = TeacherRoutePaths.reportCards;
  static const settings = '/settings';

  static const Set<String> shellRoutes = {
    calendar,
    evaluations,
    teaching,
    reportCards,
  };

  static const Set<String> topLevelRoutes = {
    ...shellRoutes,
    settings,
    '/account',
  };
}

/// Resolves a push deep link to a route that exists in the teacher app.
///
/// Entity identifiers in [link.data] take precedence over generic shell paths.
/// Unknown guardian routes and inbox destinations (not yet implemented) fall back
/// to [fallback].
String? resolveTeacherNotificationPath(
  NotificationDeepLink link, {
  String fallback = TeacherNotificationTargets.calendar,
}) {
  final entityPath = _pathFromEntityIds(link.data);
  if (entityPath != null) {
    return entityPath;
  }

  final path = link.path.trim();
  if (path.isEmpty) {
    return null;
  }

  if (path == '/inbox' || path == '/inbox/message') {
    return fallback;
  }

  if (path == '/fees' || path == '/academic') {
    return fallback;
  }

  if (_isTeacherDeepLinkPath(path)) {
    return path;
  }

  if (TeacherNotificationTargets.topLevelRoutes.contains(path)) {
    return path;
  }

  for (final shellRoute in TeacherNotificationTargets.shellRoutes) {
    if (path == shellRoute || path.startsWith('$shellRoute/')) {
      return shellRoute;
    }
  }

  return fallback;
}

String? _pathFromEntityIds(Map<String, String> data) {
  final sessionId = _firstNonEmpty(data, const [
    'lessonSessionId',
    'sessionId',
  ]);
  if (sessionId != null) {
    return TeacherRoutePaths.session(sessionId);
  }

  final assessmentId = _firstNonEmpty(data, const ['assessmentId']);
  if (assessmentId != null) {
    return TeacherRoutePaths.assessmentMarks(assessmentId);
  }

  final resultId = _firstNonEmpty(data, const [
    'resultId',
    'reportCardResultId',
  ]);
  final studentId = _firstNonEmpty(data, const ['studentId']);
  if (resultId != null && studentId != null) {
    return TeacherRoutePaths.reportCardComment(
      resultId: resultId,
      studentId: studentId,
    );
  }

  final classGroupId = _firstNonEmpty(data, const ['classGroupId']);
  final periodId = _firstNonEmpty(data, const ['periodId']);
  if (classGroupId != null && periodId != null) {
    return TeacherRoutePaths.reportCardRoster(
      classGroupId: classGroupId,
      periodId: periodId,
    );
  }

  return null;
}

bool _isTeacherDeepLinkPath(String path) {
  return path.startsWith('/calendar/sessions/') ||
      path.startsWith('/evaluations/assessments/') ||
      path.startsWith('/report-cards/classes/') ||
      path.startsWith('/report-cards/results/');
}

String? _firstNonEmpty(Map<String, String> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}
