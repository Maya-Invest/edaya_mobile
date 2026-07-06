# Teacher app — Teaching & Report cards sprint

## Locked decisions

| # | Decision |
|---|----------|
| 1 | **4 bottom-nav tabs**: Calendar, Evaluations, Teaching, Report cards |
| 2 | **Empty states**: show all assigned classes/subjects even when no data |
| 3 | **Report card comments**: homeroom `teacherComment` + subject section `comment`, gated by capabilities |
| 4 | **Teaching filters**: independent from global calendar class filter |

## Screen 1 — Teaching (`/teaching`)

### Journey

```
Teaching tab
  → Pick class (assigned classes)
  → Pick subject (accessible class-subjects for that class)
  → Tab [Progress] | [Logbook]
       Progress: class-subject aggregate + matter breakdown
       Logbook: lesson sessions for subject → tap opens session detail sheet
```

### Data reads

| Entity | Filter |
|--------|--------|
| `classSubjects` | Selected `classSubjectId` |
| `classSubjectMatters` | `{ classSubjectId }` |
| `subjectMatters` | By ids from matters |
| `lessonSessions` | `{ classGroupId, classSubjectId }` |
| `classSubjectProgress` | `progressForLessonSessions(sessionIds)` |

Writes: none (navigate to calendar session detail for edits).

### Phases

- [x] P1 — Shell tab, routes, scope pickers, Progress tab
- [x] P2 — Logbook tab + session navigation
- [ ] P3 — Integration tests (read probes)
- [ ] P4 — Polish (filter sheet optional)

## Screen 2 — Report cards (`/report-cards`)

### Journey

```
Report cards tab
  → Academic period picker
  → Class list (all assigned classes, empty state if no generated results)
  → Student roster with draft results
  → Assess → comment sheet (homeroom + subject sections per capability)
```

### Data reads

| Entity | Filter |
|--------|--------|
| `results` | `reportCardResultsForClassPeriod(classGroupId, periodId)` |
| `definitions`, `sections` | For labels and writable sections |
| `students` | Class roster |

### Write

`results.save` with comment-only diff (`teacherComment`, section `comment`).

### Phases

- [x] P1 — Tab, period picker, class list with counts / empty states
- [ ] P2 — Student roster (draft results)
- [ ] P3 — Comment sheet (homeroom + subject capabilities)
- [ ] P4 — Integration tests + publish lock UX

## Reference

- Web: `edaya_web/apps/webapp/src/lib/api/teaching-log-data.ts`
- Web: `edaya_web/apps/webapp/src/lib/api/report-cards-data.ts`
- Mobile session logbook: `apps/teacher/lib/features/session/`
- Backend: `report-card-comment-access.ts`, `session-content-model-plan.md`
