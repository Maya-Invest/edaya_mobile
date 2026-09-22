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
  Future<List<TeacherOutboxEntry>> listPending() async {
    _recoverSyncing();
    final pending = _entriesByIdempotencyKey.values
        .where(
          (entry) =>
              teacherOutboxEntryIsReplayable(entry) &&
              teacherOutboxEntryMatchesContext(entry, _context),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pending;
  }

  void _recoverSyncing() {
    for (final entry in _entriesByIdempotencyKey.values.toList()) {
      if (entry.state == TeacherOutboxState.syncing) {
        _entriesByIdempotencyKey[entry.idempotencyKey] = entry.copyWith(
          state: TeacherOutboxState.pending,
          updatedAt: DateTime.now(),
        );
      }
    }
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
