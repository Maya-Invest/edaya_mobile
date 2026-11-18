# Guardian v2 workspace

This is the normative contract for `apps/guardian`. It uses the EDAYA tokens and bundled Poppins/Inter typography.

## Navigation and child context

Home is the navigation root. Feature pages have a localized Back action. Children, profile/settings and individual fee/payment/message/questionnaire records use routed, scrollable sheets with Close. The picker lists authorized children grouped by school with class/year context and portrait fallback; it never offers unrelated pupils. Each school’s pupil record remains a separate card. Card selection loads the profile and current published enrollment year, or the latest enrollment year. One year selects directly without a chevron; multiple years have a separate expansion control, year selector and Apply. Zero-year children remain visible with No enrollment and academic empty states. Choices come from authorized enrollments, including closed records. Cross-school identity linking and account-synced grouping are deferred. The page data scope resets on account, guardian, school, child or selected-year changes; requests use captured headers and obsolete responses cannot repopulate the new selection. The Navigator survives switching.

Home has exactly two groups:

| Scolarité | Vie scolaire |
|---|---|
| Agenda → `/calendar` | Frais → `/fees` |
| Progression → `/scolarite/progress` | Messages → `/inbox` |
| Résultats → `/scolarite/notes` | Avis → `/inbox/avis` |
| | Dossier de l’enfant → `/child` |

Each menu card contains an icon, title and a concise contextual highlight. Errors remain distinguishable from zero counts, with refresh available. There is no additional alert feed or bottom navigation. Existing attendance, finance, conversations, survey submission, photo moderation and document actions retain their authorization and outcomes. Progression retains the curriculum/logbook flow. Messages and Avis are distinct destinations.

Detail content retains its record identity beneath the shared chrome: session name/date, logbook subject and charge label. Sheets have destination-specific titles. Attendance history preserves the school calendar date without converting it to the device timezone and labels daily calls explicitly. Receipt details resolve charge labels from the selected child/year's settlement history. Closing a read message refreshes the inbox's unread state.

## Home sessions

Use the child timetable and school timezone. Show the current occurrence and the next occurrence today, or the next two today when none is current. A session ending exactly now is finished; cancelled occurrences and other dates are excluded. Lessons, activities and assessments are supported. Refresh on entry/resume, every minute while visible, and at occurrence/midnight boundaries. Attendance belongs to the exact selected child and occurrence. Missing records say not recorded; failed reads say unavailable. Daily attendance is never substituted for session attendance.

## Unified results

Results has a period selector and uses the global pupil/school/year context. Explicit historical years persist across navigation; fresh launches choose the current enrollment context. The selected period shows the report module structure, modules initially collapsed, ungrouped subjects as root rows. Subject rows show the captured result, coefficient and available published feedback. Subject identities are stable IDs, never labels. Selecting a subject opens all guardian-visible marks in that period, newest first; each mark expands to coefficient, available assessment description and teacher notes. Absence/exemption and an absent grade remain distinct from a numeric zero.

`get-guardian-period-results(studentId, periodId)` is a read-only guardian query with fresh child relationship, school and selected-year authorization. Before report publication it computes provisional results from submitted, family-visible marks using existing grading/module policies. Draft marks and private report comments are excluded. Incomplete policy/configuration retains subject and mark access while withholding averages. Enrollment history and subject participation determine eligible offerings. Annual report configuration uses existing period weights and visible sources. A published report’s snapshot values and comments remain unchanged by later submitted marks or private revisions. Download uses the existing periodic/annual document workflow. No report generation, publication, teacher-comment or grading administration is available here.

Legacy report and mark URLs resolve to this workspace using the same authorized child/year checks. Inaccessible links show an unavailable state. Fees and Agenda use this same context; legacy year URLs pass through enrollment-authorized context selection. Switching context from a record returns to its feature root.

## Presentation and verification

Use EDAYA semantic surfaces, one child-context card, consistent spacing and clear empty/loading/error states. Phone cards use two columns; large text uses one; wide screens arrange Home’s sessions and menu side by side. Content is bounded on tablets, with sheets capped at 640 logical pixels. Text must wrap at 200%, controls retain accessible targets, and the new shell/results copy is localized in French and English. Existing feature-local language behavior is retained.

Current examples: `lib/app/workspace_shell.dart`, `features/context/child_picker.dart`, `features/context/archive_workspace.dart`, `features/home/home_page.dart`, `features/scolarite/results_page.dart`, and `features/scolarite/subject_grades_page.dart` in Guardian v2. Its integration scenarios live under the `guardian_v2` registry key; original Guardian and Teacher suites stay independent.

## Compact feature pages and history

Both Home layouts retain their original typography, headers, context cards and spacing. Only the Guardian Presence tile is removed. Feature headers use 20sp titles and a constrained, ellipsized context picker on the same row, with full accessible labels and 48dp targets. Enlarged text may simplify controls.

Agenda uses route-backed Schedule / History tabs, initially Schedule. History shows ended sessions newest first, including sessions ending today, with attendance and justification information. Eligible sessions with no saved attendance say Not recorded. Daily calls retain their school date and explicit daily label. Load older reads backward in windows of at most 31 days, stopping at the selected year start. Detail returns preserve tab and list scroll. `/attendance` and `/calendar/attendance` redirect to `/calendar?tab=history`.

Progression lists subjects with prominent progress values. `/scolarite/progress/:subjectId` uses the stable class-subject ID, shows chapters as Not started / In progress / Completed, and links to the same offering’s logbook at `/scolarite/progress/:subjectId/cahier`. Legacy logbook names resolve when they identify one authorized offering. Messages uses Conversations / Notifications tabs, initially Conversations. Composition belongs in Conversations; both tabs support pull-to-refresh even when empty. Surveys remain separate. Preserve unread receipts, pagination and existing notification links.
