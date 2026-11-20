import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'teacher_outbox_models.dart';

const teacherOutboxSharedPrefsStorageKey = 'teacher_outbox_v1';
const teacherOutboxMigratedToDriftKey = 'teacher_outbox_migrated_to_drift_v1';

/// Legacy SharedPreferences store kept for one-time migration into Drift.
class SharedPrefsTeacherOutboxStore implements TeacherOutboxStore {
  SharedPrefsTeacherOutboxStore({
    this.storageKey = teacherOutboxSharedPrefsStorageKey,
  });

  final String storageKey;
  TeacherOutboxContext? _context;

  @override
  void bindContext(TeacherOutboxContext? context) {
    _context = context;
  }

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
            (entry) =>
                TeacherOutboxEntry.fromJson(entry.cast<String, dynamic>()),
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
    entry = stampTeacherOutboxContext(entry, _context);
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
  Future<TeacherOutboxEntry?> findEntry(String id) async =>
      (await listPending()).where((entry) => entry.id == id).firstOrNull;

  @override
  Future<List<TeacherOutboxEntry>> listConflicts() async =>
      (await listPending())
          .where(
            (entry) =>
                entry.state == TeacherOutboxState.conflict ||
                entry.state == TeacherOutboxState.rejected,
          )
          .toList();

  @override
  Future<List<TeacherOutboxEntry>> listPending() async {
    final entries = await _readAll();
    return entries
        .where(
          (entry) =>
              entry.state != TeacherOutboxState.synced &&
              teacherOutboxEntryMatchesContext(entry, _context),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Migration copies all unsynced profiles before clearing legacy storage.
  Future<List<TeacherOutboxEntry>> readMigrationEntries() async =>
      (await _readAll())
          .where((entry) => entry.state != TeacherOutboxState.synced)
          .toList();

  @override
  Future<bool> replaceIfCurrent(
    TeacherOutboxEntry expected,
    TeacherOutboxEntry? replacement,
  ) async {
    final entries = await _readAll();
    final at = entries.indexWhere(
      (row) => sameTeacherOutboxVersion(row, expected),
    );
    if (at < 0) return false;
    if (replacement == null) {
      entries.removeAt(at);
    } else {
      entries[at] = replacement;
    }
    await _writeAll(entries);
    return true;
  }

  Future<void>? _recovery;
  @override
  Future<void> prepareReplay() => _recovery ??= _recoverSyncing();

  Future<void> _recoverSyncing() async {
    final entries = await _readAll();
    var changed = false;
    final recovered = entries.map((entry) {
      if (entry.state != TeacherOutboxState.syncing) {
        return entry;
      }
      changed = true;
      return entry.copyWith(
        state: TeacherOutboxState.pending,
        updatedAt: DateTime.now(),
      );
    }).toList();
    if (changed) {
      await _writeAll(recovered);
    }
  }

  Future<void> _writeAll(List<TeacherOutboxEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  @override
  Future<void> upsert(TeacherOutboxEntry entry) async {
    await enqueue(entry);
  }

  @override
  Future<void> remove(String id) async {
    final entries = await _readAll();
    entries.removeWhere((entry) => entry.id == id);
    await _writeAll(entries);
  }

  @override
  Future<void> removeByIdempotencyKey(String idempotencyKey) async {
    final entries = await _readAll();
    entries.removeWhere((entry) => entry.idempotencyKey == idempotencyKey);
    await _writeAll(entries);
  }

  @override
  Future<void> discardBoundContext() async {
    final context = _context;
    if (context == null) {
      return;
    }
    final entries = await _readAll();
    entries.removeWhere(
      (entry) => teacherOutboxEntryMatchesContext(entry, context),
    );
    await _writeAll(entries);
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
