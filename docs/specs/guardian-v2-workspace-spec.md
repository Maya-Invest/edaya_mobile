# Guardian v2 workspace

This is the normative contract for `apps/guardian`. It uses the EDAYA tokens and bundled Poppins/Inter typography.

## Navigation and child context

Home is the navigation root. Feature pages have a localized Back action. Children, profile/settings and individual fee/payment/message/questionnaire records use routed, scrollable sheets with Close. The picker lists authorized children grouped by school with class/year context and portrait fallback; it never offers unrelated pupils. Selection loads the correct school guardian profile and current published year before exposing a child’s data. Per-account/per-school child preferences are revalidated. The page data scope resets on account, guardian, school, child or current-year changes; requests use captured headers and obsolete responses cannot repopulate the new selection. The Navigator survives switching.

Home has exactly two groups:

| Scolarité | Vie scolaire |
|---|---|
| Agenda → `/calendar` | Présences → `/attendance` |
| Progression → `/scolarite/progress` | Frais → `/fees` |
| Résultats → `/scolarite/notes` | Messages → `/inbox` |
| | Avis → `/inbox/avis` |
| | Dossier de l’enfant → `/child` |

Each menu card contains an icon, title and a concise contextual highlight. Errors remain distinguishable from zero counts, with refresh available. There is no additional alert feed or bottom navigation. Existing attendance, finance, conversations, survey submission, photo moderation and document actions retain their authorization and outcomes. Progression retains the curriculum/logbook flow. Messages and Avis are distinct destinations.

Detail content retains its record identity beneath the shared chrome: session name/date, logbook subject and charge label. Sheets have destination-specific titles. Attendance history preserves the school calendar date without converting it to the device timezone and labels daily calls explicitly. Receipt details resolve charge labels from the selected child/year's settlement history. Closing a read message refreshes the inbox's unread state.

## Home sessions

Use the child timetable and school timezone. Show the current occurrence and the next occurrence today, or the next two today when none is current. A session ending exactly now is finished; cancelled occurrences and other dates are excluded. Lessons, activities and assessments are supported. Refresh on entry/resume, every minute while visible, and at occurrence/midnight boundaries. Attendance belongs to the exact selected child and occurrence. Missing records say not recorded; failed reads say unavailable. Daily attendance is never substituted for session attendance.

## Unified results

Results has a local school-year selector and period selector. Changing an archive year does not change Home or another reader. The selected period shows the report module structure, modules initially collapsed, ungrouped subjects as root rows. Subject rows show the captured result, coefficient and available published feedback. Subject identities are stable IDs, never labels. Selecting a subject opens all guardian-visible marks in that period, newest first; each mark expands to coefficient, available assessment description and teacher notes. Absence/exemption and an absent grade remain distinct from a numeric zero.

`get-guardian-period-results(studentId, periodId)` is a read-only guardian query with fresh child relationship, school and selected-year authorization. Before report publication it computes provisional results from submitted, family-visible marks using existing grading/module policies. Draft marks and private report comments are excluded. Incomplete policy/configuration retains subject and mark access while withholding averages. Enrollment history and subject participation determine eligible offerings. Annual report configuration uses existing period weights and visible sources. A published report’s snapshot values and comments remain unchanged by later submitted marks or private revisions. Download uses the existing periodic/annual document workflow. No report generation, publication, teacher-comment or grading administration is available here.

Legacy report and mark URLs resolve to this workspace using the same authorized child/year checks. Inaccessible links show an unavailable state. Fees and attendance keep their own archive year; nested finance routes preserve that year.

## Presentation and verification

Use EDAYA semantic surfaces, one child-context card, consistent spacing and clear empty/loading/error states. Phone cards use two columns; large text uses one; wide screens arrange Home’s sessions and menu side by side. Content is bounded on tablets, with sheets capped at 640 logical pixels. Text must wrap at 200%, controls retain accessible targets, and the new shell/results copy is localized in French and English. Existing feature-local language behavior is retained.

Current examples: `lib/app/workspace_shell.dart`, `features/context/child_picker.dart`, `features/context/archive_workspace.dart`, `features/home/home_page.dart`, `features/scolarite/results_page.dart`, and `features/scolarite/subject_grades_page.dart` in Guardian v2. Its integration scenarios live under the `guardian_v2` registry key; original Guardian and Teacher suites stay independent.
