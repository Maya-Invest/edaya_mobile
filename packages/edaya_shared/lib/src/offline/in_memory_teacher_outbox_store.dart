import 'teacher_outbox_models.dart';

class InMemoryTeacherOutboxStore implements TeacherOutboxStore {
  final Map<String, TeacherOutboxEntry> _entriesByIdempotencyKey = {};

  @override
  Future<void> enqueue(TeacherOutboxEntry entry) async {
    _entriesByIdempotencyKey[entry.idempotencyKey] = entry;
  }

  @override
  Future<List<TeacherOutboxEntry>> listPending() async {
    final pending = _entriesByIdempotencyKey.values
        .where(
          (entry) =>
              entry.state == TeacherOutboxState.pending ||
              entry.state == TeacherOutboxState.savedLocally ||
              entry.state == TeacherOutboxState.failed,
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pending;
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
