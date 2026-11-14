import 'package:edaya_shared/edaya_shared.dart';

import '../features/inbox/inbox_routes.dart';
import 'teacher_route_paths.dart';

/// Teacher-app notification destinations and safe fallbacks.
abstract final class TeacherNotificationTargets {
  static const home = TeacherRoutePaths.home;
  static const calendar = TeacherRoutePaths.calendar;
  static const classes = TeacherRoutePaths.classes;
  static const evaluations = TeacherRoutePaths.evaluations;
  static const inbox = TeacherRoutePaths.inbox;
  static const settings = TeacherRoutePaths.settings;

  static const Set<String> shellRoutes = {
    home,
    calendar,
    classes,
    evaluations,
    inbox,
  };

  static const Set<String> topLevelRoutes = {
    ...shellRoutes,
    settings,
    TeacherRoutePaths.account,
  };
}

/// Resolves a push deep link to a route that exists in the Accueil teacher app.
String? resolveTeacherNotificationPath(
  NotificationDeepLink link, {
  String fallback = TeacherNotificationTargets.home,
}) {
  final entityPath = _pathFromEntityIds(link.data);
  if (entityPath != null) {
    return entityPath;
  }

  final path = link.path.trim();
  if (path.isEmpty) {
    return null;
  }

  if (path == '/inbox/message' || path.startsWith('/inbox/message')) {
    final deliveryId = link.deliveryId;
    if (deliveryId == null || deliveryId.isEmpty) {
      return TeacherRoutePaths.inbox;
    }
    return inboxMessagePath(deliveryId);
  }

  if (path == '/fees' || path == '/academic' || path == '/teaching') {
    return path == '/teaching' ? TeacherRoutePaths.classes : fallback;
  }

  final remapped = _remapLegacyPath(path);
  if (remapped != null) {
    return remapped;
  }

  if (_isTeacherDeepLinkPath(path)) {
    return path;
  }

  if (TeacherNotificationTargets.topLevelRoutes.contains(path)) {
    return path;
  }

  for (final shellRoute in TeacherNotificationTargets.shellRoutes) {
    if (path == shellRoute || path.startsWith('$shellRoute/')) {
      return path;
    }
  }

  return fallback;
}

String? _pathFromEntityIds(Map<String, String> data) {
  final conversationId = _firstNonEmpty(data, const ['conversationId']);
  if (conversationId != null) {
    return '/inbox/conversation/${Uri.encodeComponent(conversationId)}';
  }
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

  final classGroupId = _firstNonEmpty(data, const ['classGroupId']);
  final periodId = _firstNonEmpty(data, const ['periodId']);
  final studentId = _firstNonEmpty(data, const ['studentId']);
  if (classGroupId != null && periodId != null && studentId != null) {
    return TeacherRoutePaths.reportCardComment(
      classGroupId: classGroupId,
      periodId: periodId,
      studentId: studentId,
    );
  }
  if (classGroupId != null && periodId != null) {
    return TeacherRoutePaths.reportCardRoster(
      classGroupId: classGroupId,
      periodId: periodId,
    );
  }
  if (classGroupId != null) {
    return TeacherRoutePaths.classWorkspace(classGroupId);
  }

  final deliveryId = _firstNonEmpty(data, const ['deliveryId', 'messageId']);
  if (deliveryId != null) {
    return inboxMessagePath(deliveryId);
  }

  return null;
}

String? _remapLegacyPath(String path) {
  const sessionPrefix = '/calendar/sessions/';
  if (path.startsWith(sessionPrefix)) {
    final id = path.substring(sessionPrefix.length).split('/').first;
    if (id.isEmpty) {
      return TeacherRoutePaths.calendar;
    }
    if (path.endsWith('/attendance')) {
      return '${TeacherRoutePaths.session(id)}/attendance';
    }
    if (path.endsWith('/logbook')) {
      return '${TeacherRoutePaths.session(id)}/logbook';
    }
    return TeacherRoutePaths.session(id);
  }

  const marksPrefix = '/evaluations/assessments/';
  if (path.startsWith(marksPrefix)) {
    final rest = path.substring(marksPrefix.length);
    final assessmentId = rest.split('/').first;
    if (assessmentId.isEmpty) {
      return TeacherRoutePaths.evaluations;
    }
    return TeacherRoutePaths.assessmentMarks(assessmentId);
  }

  if (path.startsWith('/report-cards/')) {
    return TeacherRoutePaths.evaluations;
  }

  if (path.startsWith('/calendar/')) {
    return TeacherRoutePaths.calendar;
  }

  return null;
}

bool _isTeacherDeepLinkPath(String path) {
  return path.startsWith('/session/') ||
      path.startsWith('/evaluations/') ||
      path.startsWith('/classes/') ||
      path.startsWith('/inbox/') ||
      path.startsWith('/home/');
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
