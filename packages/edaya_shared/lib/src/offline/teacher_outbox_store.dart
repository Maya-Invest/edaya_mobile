export 'drift_teacher_outbox_store.dart';
export 'in_memory_teacher_outbox_store.dart';
export 'teacher_outbox_database.dart';
export 'teacher_outbox_models.dart';
export 'teacher_outbox_store_shared_prefs.dart';
export 'teacher_outbox_sync.dart';
export 'teacher_write_failure.dart';
export 'teacher_outbox_sync_summary_card.dart';

import 'package:flutter/foundation.dart';

import 'drift_teacher_outbox_store.dart';
import 'in_memory_teacher_outbox_store.dart';
import 'teacher_outbox_database.dart';
import 'teacher_outbox_models.dart';

TeacherOutboxStore Function()? _teacherOutboxStoreFactory;

/// Overrides the default Drift-backed store factory in tests.
void configureTeacherOutboxStoreFactory(
  TeacherOutboxStore Function()? factory,
) {
  _teacherOutboxStoreFactory = factory;
}

/// Opens the teacher outbox store for the current platform.
///
/// Native mobile/desktop uses Drift SQLite. Web uses an in-memory store until
/// `sqlite3.wasm` worker assets are added to the Flutter web bundle.
TeacherOutboxStore openTeacherOutboxStore() {
  final factory = _teacherOutboxStoreFactory;
  if (factory != null) {
    return factory();
  }
  if (kIsWeb) {
    return InMemoryTeacherOutboxStore();
  }
  return DriftTeacherOutboxStore(TeacherOutboxDatabase());
}
