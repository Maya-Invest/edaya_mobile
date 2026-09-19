# Teacher app — Offline outbox architecture

**Status:** Approved for Wave 1 implementation  
**Date:** 2026-07-20  
**Related:** [Teacher app implementation plan](teacher-app-implementation-plan.md)

## Goal

Allow teachers to complete attendance, logbook, marks, and report-card comment writes when connectivity is intermittent, without silent data loss or duplicate server mutations.

## Scope (initial)

| Write type | Idempotency key shape | Conflict policy |
|------------|----------------------|-----------------|
| Attendance | `attendance:{occurrenceId}:{studentId}` | Server wins on status mismatch; teacher may re-apply exception |
| Logbook draft/save | `logbook:{lessonSessionId}:{matterId?}` | Last-write-wins with `updatedAt` check |
| Marks | `mark:{assessmentId}:{studentId}` | Last-write-wins with result version |
| Report-card comment | `comment:{resultId}:{sectionId}` | Last-write-wins with result version |

## Storage choice

**Drift (SQLite)** in `edaya_shared` under `lib/src/offline/`:

- Single `teacher_outbox` table shared by teacher app processes
- Encrypted SQLCipher is a follow-up; v1 uses app-sandbox SQLite
- Read models (agenda headers, roster ids) cached in separate Drift tables in Wave 1

### `teacher_outbox` row

| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT PK | UUID |
| `kind` | TEXT | `attendance`, `logbook`, `mark`, `comment` |
| `idempotency_key` | TEXT UNIQUE | dedupe + server header |
| `payload_json` | TEXT | command/entity body |
| `state` | TEXT | `saved_locally`, `pending`, `syncing`, `synced`, `conflict`, `failed` |
| `attempt_count` | INT | retry counter |
| `last_error` | TEXT nullable | teacher-safe message |
| `created_at` | INT | epoch ms |
| `updated_at` | INT | epoch ms |

## Sync loop

1. UI writes to local outbox in a Drift transaction and updates row state to `pending`.
2. `TeacherOutboxProcessor` (Levit controller, app scope) drains `pending` rows FIFO per kind.
3. Each send includes `Idempotency-Key` header (or command field where API already supports it).
4. Success → `synced`; retriable API error → `pending` with backoff; version conflict → `conflict` with server snapshot.
5. Account screen shows pending count and oldest pending age via `SyncIndicator`.

## UI states

Use shared `SyncIndicator` / `StatusBadge`:

- `saved` — optimistic in-memory only (not yet flushed to outbox)
- `savedLocally` — persisted to outbox
- `pending` / `syncing` / `synced` / `failed`

Never show `synced` until server acknowledges.

## Security

- No student free-text in analytics events
- Outbox payload redacted from crash logs
- Clear outbox on sign-out after user confirmation if pending rows exist

## Wave 1 implementation checklist

- [x] Add `drift` + `drift_dev` to `edaya_shared`
- [x] Implement `TeacherOutboxStore` port + Drift adapter
- [x] Wire attendance + logbook enqueue in session controllers
- [x] Add account-screen pending sync summary
- [ ] Integration test: enqueue → airplane mode → replay

## Non-goals (v1)

- Cross-device sync conflict UI beyond last-write-wins
- Guardian or staff apps sharing the same outbox schema
- Background iOS URLSession sync (foreground + resume only)
