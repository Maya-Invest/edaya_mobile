import 'dart:developer' as developer;

import 'package:edaya_shared/edaya_shared.dart';

/// Lightweight client-side observability hooks for pilot hardening.
class TeacherObservability {
  const TeacherObservability();

  void recordScreenLoad(String screen, {required Duration duration}) {
    developer.log(
      'teacher.screen_load',
      name: 'edaya.teacher',
      error: <String, Object?>{
        'screen': screen,
        'durationMs': duration.inMilliseconds,
      },
    );
  }

  void recordDeepLinkFailure({
    required String path,
    required String reason,
  }) {
    developer.log(
      'teacher.deep_link_failure',
      name: 'edaya.teacher',
      error: <String, Object?>{'path': path, 'reason': reason},
    );
  }

  void recordOutboxSyncSuccess(TeacherOutboxKind kind) {
    developer.log(
      'teacher.outbox_sync_success',
      name: 'edaya.teacher',
      error: <String, Object?>{'kind': kind.name},
    );
  }

  void recordOutboxSyncFailure(
    TeacherOutboxKind kind, {
    required String error,
  }) {
    developer.log(
      'teacher.outbox_sync_failure',
      name: 'edaya.teacher',
      error: <String, Object?>{'kind': kind.name, 'error': error},
    );
  }

  void recordOutboxAge(Duration age) {
    developer.log(
      'teacher.outbox_age',
      name: 'edaya.teacher',
      error: <String, Object?>{'ageMinutes': age.inMinutes},
    );
  }
}

/// Times an async screen load and records observability metadata.
Future<T> trackTeacherScreenLoad<T>(
  TeacherObservability observability,
  String screen,
  Future<T> Function() action,
) async {
  final started = DateTime.now();
  try {
    return await action();
  } finally {
    observability.recordScreenLoad(
      screen,
      duration: DateTime.now().difference(started),
    );
  }
}
