import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'teacher_outbox_models.dart';

const teacherOutboxSharedPrefsStorageKey = 'teacher_outbox_v1';
const teacherOutboxMigratedToDriftKey = 'teacher_outbox_migrated_to_drift_v1';

/// Legacy SharedPreferences store kept for one-time migration into Drift.
class SharedPrefsTeacherOutboxStore implements TeacherOutboxStore {
  SharedPrefsTeacherOutboxStore({this.storageKey = teacherOutboxSharedPrefsStorageKey});

  final String storageKey;

  Future<List<TeacherOutboxEntry>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }
      return decoded
          .whereType<Map>()
          .map(
            (entry) => TeacherOutboxEntry.fromJson(entry.cast<String, dynamic>()),
          )
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  @override
  Future<void> enqueue(TeacherOutboxEntry entry) async {
    final entries = await _readAll();
    final existingIndex = entries.indexWhere(
      (candidate) => candidate.idempotencyKey == entry.idempotencyKey,
    );
    if (existingIndex >= 0) {
      entries[existingIndex] = entry;
    } else {
      entries.add(entry);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  @override
  Future<List<TeacherOutboxEntry>> listPending() async {
    final entries = await _readAll();
    return entries.where(_isPendingState).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> upsert(TeacherOutboxEntry entry) async {
    await enqueue(entry);
  }

  @override
  Future<void> remove(String id) async {
    final entries = await _readAll();
    entries.removeWhere((entry) => entry.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  @override
  Future<int> pendingCount() async {
    final pending = await listPending();
    return pending.length;
  }

  @override
  Future<TeacherOutboxSummary> summary() async {
    final pending = await listPending();
    return TeacherOutboxSummary.fromEntries(pending);
  }
}

bool _isPendingState(TeacherOutboxEntry entry) {
  return entry.state == TeacherOutboxState.pending ||
      entry.state == TeacherOutboxState.savedLocally ||
      entry.state == TeacherOutboxState.failed;
}
