import 'dart:async';
import 'dart:convert';

import 'package:levit_flutter/levit_flutter.dart' show LevitScopeDisposable;

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'teacher_outbox_database.dart';
import 'teacher_outbox_models.dart';
import 'teacher_outbox_store_shared_prefs.dart';

TeacherOutboxStore openTeacherOutboxStore() {
  return DriftTeacherOutboxStore(TeacherOutboxDatabase());
}

class DriftTeacherOutboxStore extends LevitScopeDisposable
    implements TeacherOutboxStore {
  DriftTeacherOutboxStore(this._database);

  final TeacherOutboxDatabase _database;

  @override
  void onClose() => unawaited(_database.close());
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
    final stamped = stampTeacherOutboxContext(entry, _context);
    await _ensureReady();
    await _upsertEntry(stamped);
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

  Expression<bool> _scope(
    $TeacherOutboxRowsTable row,
    TeacherOutboxContext? context,
  ) {
    if (context == null) {
      return row.origin.isNull() |
          row.subjectId.isNull() |
          row.actorKind.isNull() |
          row.actorId.isNull() |
          row.schoolId.isNull();
    }
    return row.origin.equals(context.origin) &
        row.subjectId.equals(context.subjectId) &
        row.actorKind.equals(context.actorKind) &
        row.actorId.equals(context.actorId) &
        row.schoolId.equals(context.schoolId) &
        (context.academicYearId == null
            ? row.academicYearId.isNull()
            : row.academicYearId.equals(context.academicYearId!));
  }

  @override
  Future<List<TeacherOutboxEntry>> listPending() => _entries(
    TeacherOutboxState.values.where(
      (state) => state != TeacherOutboxState.synced,
    ),
  );

  @override
  Future<List<TeacherOutboxEntry>> listConflicts() =>
      _entries([TeacherOutboxState.conflict, TeacherOutboxState.rejected]);

  Future<List<TeacherOutboxEntry>> _entries(
    Iterable<TeacherOutboxState> states,
  ) async {
    final context = _context;
    await _ensureReady();
    final rows =
        await (_database.select(_database.teacherOutboxRows)
              ..where(
                (row) =>
                    _scope(row, context) &
                    row.state.isIn(states.map((s) => s.name)),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.createdAt),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<TeacherOutboxEntry?> findEntry(String id) async {
    final context = _context;
    await _ensureReady();
    final row =
        await (_database.select(_database.teacherOutboxRows)
              ..where((row) => row.id.equals(id) & _scope(row, context)))
            .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<bool> replaceIfCurrent(
    TeacherOutboxEntry expected,
    TeacherOutboxEntry? replacement,
  ) async {
    await _ensureReady();
    Expression<bool> matches($TeacherOutboxRowsTable row) =>
        row.id.equals(expected.id) &
        row.idempotencyKey.equals(expected.idempotencyKey) &
        row.state.equals(expected.state.name) &
        row.updatedAt.equals(expected.updatedAt.millisecondsSinceEpoch) &
        row.attemptCount.equals(expected.attemptCount) &
        row.payloadJson.equals(jsonEncode(expected.payload)) &
        _scope(row, expected.context);
    if (replacement == null) {
      return await (_database.delete(
            _database.teacherOutboxRows,
          )..where(matches)).go() ==
          1;
    }
    return await (_database.update(
          _database.teacherOutboxRows,
        )..where(matches)).write(_toCompanion(replacement)) ==
        1;
  }

  Future<void>? _recovery;
  @override
  Future<void> prepareReplay() => _recovery ??= _recoverSyncing();

  Future<void> _recoverSyncing() async {
    await _ensureReady();
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
    await (_database.delete(
      _database.teacherOutboxRows,
    )..where((row) => _scope(row, context))).go();
  }

  @override
  Future<int> pendingCount() async {
    final summary = await this.summary();
    return summary.pendingCount;
  }

  @override
  Future<TeacherOutboxSummary> summary() async {
    final context = _context;
    await _ensureReady();
    final table = _database.teacherOutboxRows;
    final count = table.id.count();
    final oldest = table.createdAt.min();
    final result =
        await (_database.selectOnly(table)
              ..addColumns([count, oldest])
              ..where(
                _scope(table, context) &
                    table.state.equals(TeacherOutboxState.synced.name).not(),
              ))
            .getSingle();
    final at = result.read(oldest);
    return TeacherOutboxSummary(
      pendingCount: result.read(count) ?? 0,
      oldestPendingAt: at == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(at),
    );
  }

  Future<void> _migrateFromSharedPrefsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(teacherOutboxMigratedToDriftKey) ?? false) {
      return;
    }

    final legacyStore = SharedPrefsTeacherOutboxStore();
    final legacyEntries = await legacyStore.readMigrationEntries();
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
