# Teacher workspace aggregate API — RFC

**Status:** Proposed (backend)  
**Date:** 2026-07-20  
**Consumers:** Teacher mobile app (Wave 1 Today dashboard, Wave 4 performance)  
**Related:** [Teacher app implementation plan](teacher-app-implementation-plan.md)

## Problem

The teacher app currently performs N+1 entity loops (per class-subject → assessments → results). This is slow for multi-class teachers and high-latency networks.

## Proposal

Add **teacher-scoped read queries** under `/core/queries/` (or commands returning read models) that return display-ready DTOs after authorization checks. Mobile keeps using entity saves/commands for writes.

## Queries

### 1. `teacher-agenda`

**Purpose:** Weekly/daily session list with completion chips.

**Input**

```json
{
  "academicYearId": "2025-ci",
  "weekStart": "2026-04-14",
  "classGroupIds": ["ci-6a", "ci-6b"]
}
```

**Output (per occurrence)**

- `sessionId`, `kind`, `title`, `classGroupId`, `classLabel`, `subjectLabel`
- `startsAt`, `endsAt`, `roomLabel?`
- `attendanceCompleted`, `logbookCompleted`, `hasPendingSync`

### 2. `teacher-evaluation-summaries`

**Input:** `academicYearId`, `periodId`, optional `classGroupIds`

**Output:** assessment id/title, class/subject labels, `gradedCount`, `totalStudents`, `maxScore`, `dueAt`/`startsAt`

### 3. `teacher-report-card-summaries`

**Input:** `academicYearId`, `periodId`, optional `classGroupIds`

**Output:** class label, generated count, comment-filled count, published count

### 4. `teacher-today-actions`

**Input:** `academicYearId`, `asOf` (date)

**Output:** ordered action items:

- `kind`: `attendance`, `logbook`, `marks`, `report_card_comment`, `announcement`
- `priority`, `title`, `subtitle`, `deepLink` (teacher route path + entity ids)

## Authorization

- Reuse effective grants + teacher assignment merge (same as mobile bootstrap)
- Queries run with request-bound actor; never accept caller-provided `schoolId` as authority
- Homeroom vs subject visibility rules unchanged from entity list filters

## Mobile integration

1. Wave 1: optional `teacher-today-actions` behind feature flag for Today segment
2. Wave 4: replace `EvaluationsController` N+1 loop with `teacher-evaluation-summaries`
3. Deep links in action items use [teacher route paths](../../apps/teacher/lib/navigation/teacher_route_paths.dart)

## Open questions

1. Should agenda include activity sessions and cancelled occurrences?
2. Cache TTL / ETag strategy for mobile (proposed: 60s soft TTL + pull-to-refresh)
3. Publish as OpenAPI query extensions (`x-edaya-query`) matching existing client generator

## Acceptance

- P95 agenda load ≤ 2 round trips for a 6-class teacher on staging
- Query outputs include labels (no extra `classGroups.get` per row on mobile)
- Authorization tests for subject-only, homeroom-only, and mixed teachers
