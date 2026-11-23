import 'package:edaya_api_client/edaya_api_client.dart';

/// Keeps a stale direct record link inside its owning teacher workspace.
class RecordAccessTransport implements Transport {
  RecordAccessTransport(
    this.delegate, {
    required this.location,
    required this.onUnavailable,
  });

  final Transport delegate;
  final Uri Function() location;
  final void Function(String owner) onUnavailable;

  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    final openedAt = location();
    final body = options?.body;
    final owner = recordOwnerForRead(
      openedAt,
      path,
      body is Map ? body : const {},
    );
    try {
      final result = await delegate.request<T>(method, path, options: options);
      if (owner == '/report-cards' &&
          openedAt.pathSegments.length == 4 &&
          body is Map &&
          body['studentId'] == openedAt.pathSegments.last &&
          result is List &&
          result.isEmpty &&
          location() == openedAt) {
        onUnavailable('/report-cards');
      }
      return result;
    } on ApiError catch (error) {
      if (owner != null &&
          (error.status == 403 || error.status == 404) &&
          location() == openedAt) {
        onUnavailable(owner);
      }
      rethrow;
    }
  }
}

String? recordOwnerForRead(Uri location, String path, Map body) {
  final parts = location.pathSegments;
  if (parts.isEmpty || path.contains('/commands/')) return null;
  if (parts.first == 'session' && parts.length >= 2) {
    return path.endsWith('/lesson-sessions/${Uri.encodeComponent(parts[1])}')
        ? '/calendar'
        : null;
  }
  if (parts.first == 'calendar' && parts.length >= 3 && parts[1] == 'lesson') {
    return path.endsWith('/lesson-sessions/${Uri.encodeComponent(parts[2])}')
        ? '/calendar'
        : null;
  }
  if (parts.first == 'progress' && parts.length == 3 && parts[1] == 'cahier') {
    return path.endsWith('/lesson-sessions/${Uri.encodeComponent(parts[2])}')
        ? '/progress'
        : null;
  }
  if (parts.first == 'classes' && parts.length >= 2) {
    return path.endsWith('/class-groups/${Uri.encodeComponent(parts[1])}')
        ? '/home'
        : null;
  }
  if (parts.first == 'evaluations' && parts.length >= 3) {
    if (parts[1] == 'avis') {
      return path.endsWith('/get-teacher-family-feedback-result') &&
              body['campaignId'] == parts[2]
          ? '/evaluations/avis'
          : null;
    }
    if (parts.last == 'marks') {
      return path.endsWith('/get-assessment-marks-review') &&
              body['assessmentId'] == parts[1]
          ? '/evaluations'
          : null;
    }
  }
  if (parts.first == 'report-cards' && parts.length >= 3) {
    return path.endsWith('/results/list') &&
            body['classGroupId'] == parts[1] &&
            body['periodId'] == parts[2]
        ? '/report-cards'
        : null;
  }
  if (parts.first == 'inbox' &&
      parts.length == 3 &&
      parts[1] == 'conversation') {
    return path.endsWith('/get-conversation') &&
            body['conversationId'] == parts[2]
        ? '/inbox'
        : null;
  }
  if (parts.first == 'inbox' && parts.length == 3 && parts[1] == 'message') {
    return path.endsWith('/message-deliveries/${Uri.encodeComponent(parts[2])}')
        ? '/inbox'
        : null;
  }
  if (parts.first == 'home' && parts.length == 4 && parts[1] == 'student') {
    return path.endsWith('/class-groups/${Uri.encodeComponent(parts[2])}') ||
            path.endsWith('/students/${Uri.encodeComponent(parts[3])}')
        ? '/home'
        : null;
  }
  if (parts.first == 'incidents' && parts.length == 3) {
    final uri = Uri.parse(path);
    if (uri.path.endsWith('/teacher/incidents/detail') &&
        uri.queryParameters['classGroupId'] == parts[1] &&
        uri.queryParameters['incidentId'] == parts[2]) {
      return '/incidents';
    }
    return path.endsWith('/incidents/list') && body['classGroupId'] == parts[1]
        ? '/incidents'
        : null;
  }
  return null;
}
