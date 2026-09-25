import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'teacher_outbox_database.dart';
import 'teacher_outbox_models.dart';
import 'teacher_outbox_store_shared_prefs.dart';

TeacherOutboxStore openTeacherOutboxStore() {
  return DriftTeacherOutboxStore(TeacherOutboxDatabase());
}

class DriftTeacherOutboxStore implements TeacherOutboxStore {
  DriftTeacherOutboxStore(this._database);

  final TeacherOutboxDatabase _database;
  Future<void>? _migration;
  TeacherOutboxContext? _context;

  @override
  void bindContext(TeacherOutboxContext? context) {
    _context = context;
  }

  Future<void> _ensureReady() {
    return _migration ??= _migrateFromSharedPrefsIfNeeded();
  }

  @override
  Future<void> enqueue(TeacherOutboxEntry entry) async {
    await _ensureReady();
    await _upsertEntry(stampTeacherOutboxContext(entry, _context));
  }

  Future<void> _upsertEntry(TeacherOutboxEntry entry) async {
    final existing =
        await (_database.select(_database.teacherOutboxRows)
              ..where((row) => row.idempotencyKey.equals(entry.idempotencyKey)))
            .getSingleOrNull();

    if (existing == null) {
      await _insertEntry(entry);
      return;
    }

    await (_database.update(_database.teacherOutboxRows)
          ..where((row) => row.id.equals(existing.id)))
        .write(_toCompanion(entry, replaceId: existing.id));
  }

  Future<void> _insertEntry(TeacherOutboxEntry entry) async {
    await _database
        .into(_database.teacherOutboxRows)
        .insert(_toCompanion(entry));
  }

  @override
  Future<List<TeacherOutboxEntry>> listPending() async {
    await _ensureReady();
    await _recoverSyncing();
    final rows =
        await (_database.select(_database.teacherOutboxRows)
              ..where(
                (row) => row.state.isIn([
                  TeacherOutboxState.pending.name,
                  TeacherOutboxState.savedLocally.name,
                  TeacherOutboxState.failed.name,
                  TeacherOutboxState.conflict.name,
                  TeacherOutboxState.rejected.name,
                ]),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
            .get();
    return rows
        .map(_fromRow)
        .where((entry) => teacherOutboxEntryMatchesContext(entry, _context))
        .toList();
  }

  Future<void> _recoverSyncing() async {
    await (_database.update(
      _database.teacherOutboxRows,
    )..where((row) => row.state.equals(TeacherOutboxState.syncing.name))).write(
      TeacherOutboxRowsCompanion(
        state: Value(TeacherOutboxState.pending.name),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<void> upsert(TeacherOutboxEntry entry) async {
    await enqueue(entry);
  }

  @override
  Future<void> remove(String id) async {
    await _ensureReady();
    await (_database.delete(
      _database.teacherOutboxRows,
    )..where((row) => row.id.equals(id))).go();
  }

  @override
  Future<void> removeByIdempotencyKey(String idempotencyKey) async {
    await _ensureReady();
    await (_database.delete(
      _database.teacherOutboxRows,
    )..where((row) => row.idempotencyKey.equals(idempotencyKey))).go();
  }

  @override
  Future<void> discardBoundContext() async {
    final context = _context;
    if (context == null) {
      return;
    }
    await _ensureReady();
    final rows = await _database.select(_database.teacherOutboxRows).get();
    for (final row in rows) {
      final entry = _fromRow(row);
      if (teacherOutboxEntryMatchesContext(entry, context)) {
        await remove(entry.id);
      }
    }
  }

  @override
  Future<int> pendingCount() async {
    final summary = await this.summary();
    return summary.pendingCount;
  }

  @override
  Future<TeacherOutboxSummary> summary() async {
    final pending = await listPending();
    return TeacherOutboxSummary.fromEntries(pending);
  }

  Future<void> _migrateFromSharedPrefsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(teacherOutboxMigratedToDriftKey) ?? false) {
      return;
    }

    final legacyStore = SharedPrefsTeacherOutboxStore();
    final legacyEntries = await legacyStore.listPending();
    await _database.transaction(() async {
      for (final entry in legacyEntries) {
        await _insertEntry(entry);
      }
    });
    await legacyStore.clearStorage();
    await prefs.setBool(teacherOutboxMigratedToDriftKey, true);
  }

  TeacherOutboxRowsCompanion _toCompanion(
    TeacherOutboxEntry entry, {
    String? replaceId,
  }) {
    return TeacherOutboxRowsCompanion(
      id: Value(replaceId ?? entry.id),
      kind: Value(entry.kind.name),
      idempotencyKey: Value(entry.idempotencyKey),
      payloadJson: Value(jsonEncode(entry.payload)),
      state: Value(entry.state.name),
      attemptCount: Value(entry.attemptCount),
      lastError: Value(entry.lastError),
      createdAt: Value(entry.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(entry.updatedAt.millisecondsSinceEpoch),
      origin: Value(entry.context?.origin),
      subjectId: Value(entry.context?.subjectId),
      actorKind: Value(entry.context?.actorKind),
      actorId: Value(entry.context?.actorId),
      schoolId: Value(entry.context?.schoolId),
      academicYearId: Value(entry.context?.academicYearId),
    );
  }

  TeacherOutboxEntry _fromRow(TeacherOutboxRow row) {
    return TeacherOutboxEntry(
      id: row.id,
      kind: TeacherOutboxKind.values.byName(row.kind),
      idempotencyKey: row.idempotencyKey,
      payload: (jsonDecode(row.payloadJson) as Map).cast<String, dynamic>(),
      state: TeacherOutboxState.values.byName(row.state),
      attemptCount: row.attemptCount,
      lastError: row.lastError,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      context: _contextFromRow(row),
    );
  }

  TeacherOutboxContext? _contextFromRow(TeacherOutboxRow row) {
    final origin = row.origin;
    final subjectId = row.subjectId;
    final actorKind = row.actorKind;
    final actorId = row.actorId;
    final schoolId = row.schoolId;
    if (origin == null ||
        subjectId == null ||
        actorKind == null ||
        actorId == null ||
        schoolId == null) {
      return null;
    }
    return TeacherOutboxContext(
      origin: origin,
      subjectId: subjectId,
      actorKind: actorKind,
      actorId: actorId,
      schoolId: schoolId,
      academicYearId: row.academicYearId,
    );
  }
}
