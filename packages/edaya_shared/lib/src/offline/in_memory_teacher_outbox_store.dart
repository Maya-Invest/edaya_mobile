import 'teacher_outbox_models.dart';

class InMemoryTeacherOutboxStore implements TeacherOutboxStore {
  final Map<String, TeacherOutboxEntry> _entriesByIdempotencyKey = {};
  TeacherOutboxContext? _context;

  @override
  void bindContext(TeacherOutboxContext? context) {
    _context = context;
  }

  @override
  Future<void> enqueue(TeacherOutboxEntry entry) async {
    final stamped = stampTeacherOutboxContext(entry, _context);
    _entriesByIdempotencyKey[stamped.idempotencyKey] = stamped;
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
    final pending =
        _entriesByIdempotencyKey.values
            .where(
              (entry) =>
                  entry.state != TeacherOutboxState.synced &&
                  teacherOutboxEntryMatchesContext(entry, _context),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pending;
  }

  @override
  Future<bool> replaceIfCurrent(
    TeacherOutboxEntry expected,
    TeacherOutboxEntry? replacement,
  ) async {
    final stored = _entriesByIdempotencyKey[expected.idempotencyKey];
    if (stored == null || !sameTeacherOutboxVersion(stored, expected))
      return false;
    if (replacement == null) {
      _entriesByIdempotencyKey.remove(expected.idempotencyKey);
    } else {
      _entriesByIdempotencyKey[expected.idempotencyKey] = replacement;
    }
    return true;
  }

  @override
  Future<void> prepareReplay() async {
    // This in-memory queue cannot survive a previous process.
  }

  @override
  Future<void> upsert(TeacherOutboxEntry entry) async {
    await enqueue(entry);
  }

  @override
  Future<void> remove(String id) async {
    _entriesByIdempotencyKey.removeWhere((_, entry) => entry.id == id);
  }

  @override
  Future<void> removeByIdempotencyKey(String idempotencyKey) async {
    _entriesByIdempotencyKey.remove(idempotencyKey);
  }

  @override
  Future<void> discardBoundContext() async {
    final context = _context;
    if (context == null) {
      return;
    }
    _entriesByIdempotencyKey.removeWhere(
      (_, entry) => teacherOutboxEntryMatchesContext(entry, context),
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
