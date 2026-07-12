# Edaya Teacher App — Final-Form Improvement Proposal

**Status:** Proposed  
**Date:** 2026-07-12  
**Scope:** `apps/teacher`, shared mobile foundations, and supporting API capabilities  
**Audience:** Product, design, Flutter, backend, QA, school implementation, and commercial teams

## 1. Executive summary

The current teacher application is a working proof of concept with a credible product foundation. It already supports the essential chain from timetable to session detail, attendance, teaching logbook, evaluations, marks, teaching progress, and report-card visibility. Static analysis is clean, the default automated test suite passes, the app supports English and French, and its role-aware data access distinguishes subject teachers from homeroom teachers.

The next stage should not be a collection of unrelated modules. The application should become the teacher's daily command center: it should show what needs attention, make repetitive classroom work exceptionally fast, remain safe under unreliable connectivity, and complete the workflows already represented in Edaya's functional offer.

The recommended priorities are:

1. Complete the currently partial core workflows.
2. Reorganize the experience around daily teacher jobs rather than backend modules.
3. Make attendance, logbook entry, grading, and report-card comments faster and safer.
4. Add an inbox and repair notification navigation.
5. Add offline-safe writes, responsive tablet layouts, accessibility coverage, and production hardening.
6. Introduce AI assistance only after the underlying structured manual workflows and data quality are stable.

## 2. Review basis and assumptions

This proposal is based on a review of:

- The teacher Flutter application's routes, screens, controllers, models, state handling, localization, and tests.
- Shared mobile authentication, settings, theme, push notification, and API layers.
- The teacher live-integration harness and current sprint notes.
- Related web application workflows for assessments, attendance, teaching, students, report cards, announcements, and inbox.
- Backend domains for assessments, attendance, report cards, messaging, student notes, incidents, health records, resources, and teacher unavailability.
- Edaya's English and French functional offer documents.

The proposal assumes:

- Subject teachers and homeroom teachers remain distinct personas with different capabilities.
- Phones are the primary personal device, while tablets are an explicit supported form factor because Connect Plus includes classroom iPads.
- Some schools will operate with intermittent or expensive connectivity.
- The web application remains the administrative surface; the teacher app should focus on classroom execution and teacher-scoped decisions.
- Sensitive student information must be capability-gated and minimized for the teacher's task.

## 3. Current product assessment

### 3.1 Existing strengths

- Weekly teacher calendar with academic-year and class filtering.
- Session details for lesson and activity occurrences.
- Sequential attendance capture with progress and completion summary.
- Per-student attendance editing.
- Session note and curriculum progress recording.
- Teaching progress overview and historical logbook.
- Evaluation creation by period, class/subject, type, and score scale.
- Per-student marks entry and grading completion counts.
- Protection against editing marks after a report card has been published.
- Report-card class summaries and student rosters.
- Teacher and homeroom authorization scopes.
- English and French localization.
- Light/dark theme and date, time, timezone, and language preferences.
- Push registration and foreground/background notification plumbing.
- Typed API client and shared mobile packages.
- Clean `flutter analyze` result.
- Passing default test suite: 27 tests passed; the live API integration suite is skipped unless its environment is configured.

### 3.2 Workflow maturity

| Workflow | Current maturity | Principal limitation |
|---|---|---|
| Authentication | Proof of concept | Password-only UI, development credentials and endpoint controls remain visible |
| Calendar | Functional | Browsing-oriented; it does not prioritize current work or incomplete tasks |
| Attendance | Functional | Missing bulk defaults, reasons, justification visibility, audit history, and offline safety |
| Session logbook | Partial | Primarily session note and curriculum percentage; commercially described structure is incomplete |
| Teaching progress | Functional read view | Limited planning, pacing, and follow-up actions |
| Evaluations | Partial | Creation omits dates, coefficient, instructions, attachments, and lifecycle actions |
| Marks | Functional but inefficient | One dialog and immediate network write per student |
| Report cards | Partial/read-only | No homeroom or subject comment editor |
| Notifications | Infrastructure only | No teacher inbox; some parsed routes do not exist in the teacher app |
| Student context | Missing | No class roster or teacher-scoped student quick profile |
| Homework | Partial data model | No dedicated assignment/submission experience |
| Offline use | Missing | Classroom writes depend on immediate connectivity |
| Tablet use | Unproven | Layouts and navigation are predominantly phone-oriented |

## 4. Product gaps and risks

### 4.1 Gap between commercial positioning and mobile implementation

The functional offer describes the teacher app as supporting structured lesson content, objectives, homework, assessment coefficient/dates/attachments, report-card comments, inbox, and push navigation to the relevant screen. The current Flutter application implements only part of that surface.

The following items should therefore be treated as completion of the promised core rather than optional expansion:

- Teacher inbox and message history.
- Valid notification navigation with safe fallbacks.
- Structured session content, objectives, and homework.
- Complete assessment metadata and lifecycle.
- Report-card commenting.
- Attachments and resources in the relevant workflows.

### 4.2 Notification navigation risk

The shared notification parser can produce paths such as `/inbox`, `/inbox/message`, `/fees`, and `/academic`. The teacher router does not define those destinations. A notification tap can consequently lead to a route error or nowhere useful.

Required resolution:

- Define teacher-specific typed notification targets.
- Add a teacher inbox and message detail route.
- Reject destinations that do not belong to the teacher app.
- Fall back to message detail or Today when a referenced entity no longer exists.
- Test foreground, background, cold-start, authenticated, and unauthenticated notification openings.

### 4.3 Assessment data integrity and UX risk

The assessment creation form currently omits date/time, due date, coefficient, description, and attachments. The payload layer silently supplies a same-day default: in-class work is placed from 09:00 to 10:00, while homework is due on the current date.

This can create incorrect timetable entries, reminders, and family expectations. The UI must collect or explicitly confirm every scheduling field used by the backend.

### 4.4 Report-card workflow stops before the teacher action

The report-card roster displays average, rank, status, and comment presence, but the student row has no comment action. This leaves teachers unable to complete the task that the page is measuring.

### 4.5 Production configuration risk

Development API switching is intentionally enabled in release builds, development credentials are passed to the login UI, and the push layer logs an FCM token in debug output.

Production builds should:

- Use fixed, signed environment configuration.
- Never prefill development accounts.
- Remove token and sensitive payload logging.
- Put diagnostics behind a protected internal build, staff PIN, or deliberate hidden gesture.
- Display environment identity only in non-production builds.

### 4.6 Performance and scalability risk

Calendar, evaluation, and report-card screens make sequential requests per class, subject, assessment, or class result set. This will become noticeably slow for teachers with multiple classes and for schools with higher network latency.

The backend should provide aggregate teacher-workspace queries for:

- Weekly teacher agenda with labels and completion state.
- Evaluation summaries and result counts for a period.
- Report-card completion summaries across teacher-visible classes.
- Today action items.

These queries should return display-ready identifiers and labels while preserving capability checks.

### 4.7 Classroom data-loss risk

Attendance, logbook, marks, and report-card comments are operational writes. Without a local outbox, a connectivity interruption can force the teacher to repeat work or leave the UI in an uncertain state.

The final app needs explicit local, pending, synchronized, conflict, and failed states.

## 5. Product principles

The final app should follow these principles:

1. **Today's work first.** The first screen should prioritize current sessions and incomplete tasks.
2. **Fast normal case, clear exceptional case.** Common actions should take one tap; reasons and corrections can use a deeper flow.
3. **No silent defaults with external consequences.** Dates, publication, family visibility, and notification behavior must be explicit.
4. **Offline is a state, not an error page.** Teachers should be able to continue core classroom work.
5. **Context is always visible.** Academic year, class, subject, period, and publication status should never be ambiguous.
6. **Capability-driven UI.** Hide or explain unavailable actions before the user encounters a server rejection.
7. **Long forms are pages.** Bottom sheets are for quick choices, not complex, stateful workflows.
8. **Every status is textual and visual.** Never rely on color alone.
9. **AI proposes; teachers decide.** AI-generated content must remain reviewable and editable.

## 6. Recommended information architecture

The current bottom navigation mirrors product modules: Calendar, Evaluations, Teaching, and Report cards. A mature teacher product should mirror the teacher's jobs.

### 6.1 Phone navigation

#### Today

- Current and next sessions.
- Incomplete attendance.
- Logbooks still to complete.
- Evaluations awaiting marks.
- Report-card comments awaiting completion.
- Urgent announcements.
- Offline/synchronization status.

#### Classes

- Teacher-visible class and subject selector.
- Roster.
- Attendance history.
- Teaching progress and logbook.
- Student quick profiles.
- Notes and incidents when permitted.

#### Assess

- Evaluations and homework.
- Marks entry.
- Missing/late work.
- Report-card comments.

#### Inbox

- Announcements.
- Automated notifications.
- Read/unread state.
- Deep links.
- Notification preferences.

#### More

- Full calendar.
- Teacher availability.
- Resources.
- Account, settings, support, and diagnostics.

### 6.2 Tablet navigation

Use a `NavigationRail` and master-detail layouts:

- Agenda at left and session detail at right.
- Student roster at left and student quick profile at right.
- Assessment list at left and marks table at right.
- Report-card roster at left and comment editor at right.

Retain bottom sheets only for short selections and confirmations. Use full pages or detail panes for assessment creation, logbook editing, marks entry, and report-card commenting.

## 7. Prioritized feature set

### P0 — Complete and harden the core

#### 7.1 Teacher inbox

**Value:** Completes the communication promise and makes push useful after the initial notification disappears.

**Scope:**

- Unread badge and unread/all filters.
- Announcement and automated notification list.
- Message detail with sender/type/date.
- Mark read/unread.
- Filters by class and type.
- Deep link to session, assessment, student, or report card.
- Safe fallback when the target is unavailable.
- Notification category preferences.

**Acceptance criteria:**

- Every teacher notification opens a valid teacher route.
- Cold-start notifications wait for authentication and context initialization.
- Opening a message records read state.
- Invalid or stale entity references show the message and a non-fatal explanation.
- Unread count is consistent after refresh and across devices.

#### 7.2 Structured session logbook

**Value:** Makes the application a real teaching record rather than a progress-only tool.

**Scope:**

- Content covered.
- Learning objectives.
- Curriculum chapters and cumulative progress.
- Homework title, instructions, and due date.
- Teacher-only note.
- Family-visible summary.
- Attachments/resources.
- Draft and autosave.
- Copy previous session.
- Reuse for another class where permitted.
- Last-saved and sync status.

**Acceptance criteria:**

- A teacher can save a note without recording curriculum progress and vice versa.
- Unsaved text survives navigation and app restart.
- Family-visible content is clearly distinguished from staff-only content.
- Progress cannot decrease unless a permitted correction workflow exists.
- A synchronized entry appears in the Teaching history and the family-facing surface as appropriate.

#### 7.3 Complete assessment lifecycle

**Value:** Prevents bad scheduling data and removes reliance on the web app for routine teacher work.

**Creation fields:**

- Class and subject.
- Academic period.
- Assessment type.
- Date and time or linked lesson.
- Homework due date.
- Maximum score.
- Coefficient.
- Instructions/description.
- Attachments.
- Family visibility or publication policy.

**Lifecycle actions:**

- Edit.
- Duplicate.
- Complete.
- Cancel/archive.
- Delete when allowed.
- View grading progress.
- Explain why an action is locked after marks or report-card publication.

**Acceptance criteria:**

- No assessment scheduling field is silently invented.
- Homework requires a future or explicitly confirmed due date.
- In-class work requires a linked lesson or explicit time range.
- Editing respects backend rules once marks exist.
- Duplicate copies content but requires new date confirmation.

#### 7.4 Efficient marks entry

**Value:** Reduces one of the most repetitive teacher tasks.

**Scope:**

- Inline score fields.
- Previous/next keyboard navigation.
- Immediate maximum-score validation.
- Ungraded-only filter and student search.
- Missing, exempt, absent, or not-submitted state when supported.
- Bulk fill and clear.
- Per-row save state.
- Local outbox.
- Class average, median, range, and completion count.
- Tablet grade grid.

**Acceptance criteria:**

- A teacher can grade a class without opening a dialog for each student.
- Invalid values never leave the local form.
- Each row displays saved, pending, failed, or locked status.
- Keyboard navigation works on hardware and software keyboards.
- Published report-card locks are visible before editing.

#### 7.5 Report-card comments

**Value:** Completes the report-card workflow already measured by the UI.

**Scope:**

- Student report-card detail.
- Homeroom teacher comment.
- Subject-section comment based on capability.
- Editable comment templates.
- Draft autosave.
- Completion progress.
- Report-card preview.
- Published and locked state.

**Acceptance criteria:**

- Teachers see only the comment fields they are authorized to edit.
- Published report cards are read-only.
- Draft comments survive app closure.
- Completion counts update immediately after synchronization.
- Publication remains an administrative action unless the teacher has an explicit capability.

#### 7.6 Attendance completion

**Value:** Makes the highest-frequency classroom action faster and more informative.

**Scope:**

- Mark all present, then record exceptions.
- Present, absent, and late.
- Reason and notes.
- Justification state where permitted.
- Optional late minutes if the school adopts it.
- Search and alphabetical jump.
- Completion review.
- Controlled correction and audit metadata.
- Daily class mode and per-session mode.
- Offline capture.

**Acceptance criteria:**

- Normal attendance for 30 students can be completed in under 90 seconds.
- The teacher can review all exceptions before finishing.
- Pending writes are never represented as server-confirmed.
- Corrections identify the responsible staff member and time.
- Attendance summary is consistent across session, class, and student views.

#### 7.7 Offline-safe writes

**Value:** Prevents data loss and supports real school connectivity conditions.

**Initial outbox scope:**

- Attendance.
- Logbook drafts and saves.
- Marks.
- Report-card comments.

**Required states:**

- Saved locally.
- Waiting to sync.
- Synchronizing.
- Synchronized.
- Conflict.
- Failed with retry.

**Acceptance criteria:**

- Pending operations survive app restart.
- Operations are idempotent.
- The app does not discard a local write when the session expires.
- Conflicts show both local and server context with a safe resolution action.
- The account screen shows pending operation count and last synchronization time.

### P1 — High-value expansion

#### 7.8 Today dashboard and action queue

The launch screen should answer:

- What am I teaching now and next?
- Which attendance registers remain incomplete?
- Which session logbooks remain incomplete?
- Which evaluations still need marks?
- Which report-card comments are due?
- Did the school publish an urgent announcement?

Avoid passive KPI cards. Every item should lead to the exact completion flow.

#### 7.9 Class and student workspace

Provide a teacher-scoped roster with:

- Photo and identity.
- Recent attendance pattern.
- Recent marks and missing work.
- Teacher notes.
- Positive recognition and behavior incidents.
- Critical health alert only where capability and school policy permit.
- Controlled guardian contact action.

Do not expose the full administrative or health record when a compact task-specific alert is sufficient.

#### 7.10 Homework tracking

- Due date and instructions.
- Attachments.
- Submitted, missing, and late state.
- Reminder action.
- Link to the originating session/logbook.
- Family-visible state.
- Completion summary for the teacher.

#### 7.11 Resources and attachments

- Upload or reuse worksheets, links, photos, and lesson files.
- Attach resources to sessions, homework, and assessments.
- School resource library with search and recent items.
- Capability-gated upload, download, and removal.

#### 7.12 Availability and substitution

- Recurring unavailable periods.
- One-off unavailability.
- Reason.
- Affected sessions.
- Administrative confirmation when an approval workflow is introduced.
- Substitute and timetable-change notification.

### P2 — Differentiation after core adoption

- Action-oriented class analytics and at-risk signals.
- Voice-assisted logbook entry with teacher confirmation.
- Smart report-card comment suggestions.
- Assessment drafting assistance.
- Calendar export.
- Resource recommendations.
- Substitute coordination.

Unrestricted parent-teacher chat should not be an early priority. It introduces moderation, expected response times, privacy, safeguarding, and school-policy requirements. Begin with announcements, inbox, and controlled contact templates.

## 8. UX specification by area

### 8.1 Global interaction patterns

- Display active academic year, class, subject, and period as visible context chips.
- Preserve selected context and scroll position across navigation.
- Keep existing content visible during refresh.
- Use skeletons for first-load lists and inline progress for background refresh.
- Translate API failures into teacher-facing language; do not show raw exceptions.
- Use explicit `Saved`, `Saved locally`, and `Synced` feedback.
- Warn about unsaved changes and autosave long forms.
- Use empty-state actions such as `Create evaluation`, `Take attendance`, or `Choose another period`.
- Make locked states explain the rule and responsible role.
- Avoid opening a modal before prerequisite data has loaded.

### 8.2 Login and account

- Remove development copy and controls from production.
- Add show/hide password.
- Add forgot-password or email OTP recovery.
- Show school identity after tenant resolution.
- Explain unauthorized role/account-link errors with a support path.
- Add notification preferences, synchronization status, app version, privacy, and support.
- Keep internal diagnostics separated from user settings.

### 8.3 Today and calendar

- Add Today button and day/agenda/week modes.
- Emphasize current and next sessions.
- Show attendance and logbook completion on session cards.
- Show room/resource, cancellation, replacement, and timetable changes.
- Allow configurable five-, six-, or seven-day school weeks.
- Surface quick actions for the current session.
- Use subject color only as a secondary cue.

### 8.4 Attendance

- Default to mark-all-present plus exception editing.
- Retain sequential focus mode as an alternative for schools that prefer it.
- Make student, status, and pending sync state readable at a glance.
- Use a dedicated exception form for reason, note, justification, and correction context.
- Announce save failures accessibly and keep the affected student in view.

### 8.5 Logbook and teaching progress

- Split structured content into clear sections rather than one long card stack.
- Show previous session context and planned next chapter.
- Allow draft completion after the lesson.
- Distinguish cumulative program progress from progress covered in this session.
- Provide a family-visible preview.
- Make the Teaching history a timeline with content search and incomplete filters.

### 8.6 Assessments and marks

- Use a full page for assessment creation/editing.
- Change fields dynamically by type: homework requires due date; in-class work requires time or linked lesson.
- Show grading completion as a progress bar and count.
- Put score fields directly in roster rows.
- Keep a sticky save/sync summary visible.
- Support large-screen grid entry without forcing phone card layouts onto tablets.

### 8.7 Report cards

- Make every generated student result actionable.
- Show average, rank, draft/published state, and comment completion.
- Separate subject comment, homeroom comment, and principal comment visually.
- Keep templates as suggestions rather than automatic final text.
- Show which role owns publication.

### 8.8 Inbox

- Group messages by recent date.
- Distinguish announcement, attendance, assessment, report-card, incident, and event notifications.
- Include unread and priority indicators with text and icons.
- Preserve the message even if its target deep link is unavailable.

## 9. UI system and responsive design

The shared Material theme provides a good base, but a final app needs a small, explicit teacher component system:

- Session card.
- Action/task card.
- Student row.
- Status badge.
- Completion bar.
- Context selector.
- Sync indicator.
- Empty, error, offline, and permission states.
- Form section.
- Sticky action footer.
- Master-detail scaffold.

### Visual hierarchy

- Use one dominant action per screen.
- Reduce repeated generic bordered cards when grouping or dividers are sufficient.
- Keep metadata subordinate to class, subject, student, or task identity.
- Use consistent spacing and type roles rather than local one-off styles.
- Reserve error red for actual failure or destructive state.
- Do not color all student text according to attendance status; use a badge or leading status marker.

### Accessibility quality bar

- Support 200% text scaling without clipping.
- Add screen-reader labels for progress, status, avatars, and icon-only actions.
- Maintain at least 48dp interactive targets.
- Use logical focus and keyboard order.
- Validate contrast in light and dark themes.
- Pair every color with text or iconography.
- Test French layouts and longer school/class names.
- Respect reduced-motion settings.
- Test phone portrait, phone landscape, tablet portrait, and tablet landscape.

## 10. Technical foundation recommendations

### 10.1 API and data loading

- Add aggregated teacher agenda, evaluation summary, report-card summary, and Today action queries.
- Batch entity lookups and result counts.
- Cancel or ignore stale requests when context changes.
- Avoid clearing usable content during refresh failure.
- Define explicit cache freshness policies.

### 10.2 Local persistence and synchronization

- Introduce an encrypted local database where supported.
- Store read models for agenda, rosters, active assessments, and message headers.
- Implement a transactional outbox for classroom writes.
- Use idempotency keys for retried commands.
- Define server conflict versions or updated-at checks.
- Redact sensitive records from logs and crash reports.

### 10.3 Capability-driven presentation

- Fetch effective capabilities during bootstrap.
- Map capabilities to visible actions, read-only states, and explanations.
- Do not use failed API calls as the primary mechanism for discovering permissions.
- Test subject-teacher, homeroom-teacher, mixed, substitute, and unauthorized profiles.

### 10.4 Navigation

- Replace object-only route extras with identifier-based routes where deep linking matters.
- Load session, assessment, message, or report-card detail from route identifiers.
- Define a typed teacher deep-link registry.
- Add restoration and cold-start tests.

### 10.5 Observability

- Capture screen load time, API errors, outbox age, retry count, and synchronization conflicts.
- Track task starts and completions without logging student content.
- Add crash reporting with strict PII scrubbing.
- Add a support diagnostics export containing configuration and health metadata, not student data.

## 11. Delivery plan

The sprint counts below are sequencing guidance. They should be recalibrated after interaction prototypes and backend query design are completed.

### Wave 0 — Product definition and foundations (1–2 sprints)

**Scope:**

- Validate subject, homeroom, substitute, and coordinator personas.
- Prototype Today/Classes/Assess/Inbox navigation.
- Establish responsive layout and component tokens.
- Remove production development controls and sensitive logging.
- Define typed notification targets and repair navigation.
- Design aggregate API queries.
- Select the local database/outbox architecture.
- Define analytics and baseline task measurements.
- Add release, accessibility, and tablet test matrices.

**Exit gate:**

- Production configuration is safe.
- Every push target resolves or falls back safely.
- Phone and tablet navigation prototypes are approved.
- Offline write and conflict behavior is specified.

### Wave 1 — Daily classroom workflow (2–3 sprints)

**Scope:**

- Today dashboard.
- Improved agenda and session cards.
- Mark-all-present attendance and exception handling.
- Structured logbook.
- Draft/autosave.
- Initial attendance and logbook outbox.
- Session resources/attachments.

**Exit gate:**

- A teacher can complete attendance and logbook work during unreliable connectivity without data loss.
- Attendance for a normal 30-student class meets the target completion time.

### Wave 2 — Assessment and reporting (2–3 sprints)

**Scope:**

- Complete assessment form and lifecycle.
- Inline/bulk marks entry.
- Missing and late work states.
- Marks outbox.
- Report-card student detail and comments.
- Comment outbox, locks, and completion progress.

**Exit gate:**

- The assessment-to-report-card teacher loop can be completed without the web application.
- Published and capability-restricted states are correctly enforced and explained.

### Wave 3 — Communication and student context (2–3 sprints)

**Scope:**

- Teacher inbox and unread state.
- Notification preferences.
- Class roster and student quick profile.
- Teacher notes and incidents.
- Homework tracking.
- Resource library.
- Controlled guardian contact.

**Exit gate:**

- Teachers can understand and act on relevant student context without navigating through administrative modules.
- Sensitive information is minimized and capability-gated.

### Wave 4 — Pilot hardening (1–2 sprints plus pilot observation)

**Scope:**

- Real-device pilots with subject and homeroom teachers.
- Large-school performance optimization.
- Sync conflict and recovery testing.
- Accessibility review.
- Security and privacy review.
- Crash, performance, and operational dashboards.
- Support and diagnostics workflows.
- Store release readiness.

**Exit gate:**

- No known data-loss path.
- Pilot task completion and performance targets are met.
- Release security, accessibility, and store checklists pass.

### Wave 5 — Differentiation

- Voice-assisted logbook with teacher validation.
- Smart comment suggestions.
- Action-oriented analytics.
- Substitute coordination.

## 12. Backlog structure

Every implementation epic should include:

1. User problem and affected persona.
2. Primary journey and exceptional journeys.
3. Capability and privacy rules.
4. Data reads, writes, and offline behavior.
5. Loading, empty, stale, error, locked, and conflict states.
6. Phone and tablet layouts.
7. English and French copy.
8. Accessibility requirements.
9. Analytics events and success measure.
10. Unit, widget, golden, integration, and live-API test cases.
11. Rollout/feature-flag plan.
12. Acceptance criteria and release gate.

## 13. Success measures

### Product metrics

- Median time to complete attendance.
- Percentage of sessions with attendance completed within 15 minutes.
- Percentage of session logbooks completed the same day.
- Median time to grade a class.
- Percentage of evaluations fully graded by deadline.
- Report-card comment completion rate.
- Notification open-to-valid-destination rate.
- Weekly active teachers.
- Teacher task completion rate by persona.

### Reliability metrics

- Crash-free sessions.
- P95 warm screen-load time.
- Offline write success rate.
- Outbox retry rate.
- Age of oldest unsynchronized operation.
- Synchronization conflict rate.
- Failed deep-link rate.
- Support requests per 100 active teachers.

### Guardrails

- Zero silent data loss.
- Zero unauthorized student or health-record access.
- Zero invalid production notification destinations.
- No accidental publication or editing of locked records.
- No production exposure of API switching or seeded credentials.
- No sensitive tokens or student content in logs or analytics.

## 14. Recommended immediate decisions

Before implementation begins, product and engineering should lock these decisions:

1. Whether the final phone navigation uses five destinations or keeps Inbox behind a top-level action.
2. Which logbook fields are staff-only versus family-visible.
3. Whether teachers may review attendance justifications or only record reasons.
4. Which homework submission states exist in the backend contract.
5. Whether teachers may publish report cards or only comment on drafts.
6. Which student health alerts are appropriate in a teacher quick profile.
7. The offline conflict policy for attendance, marks, and comments.
8. The supported tablet breakpoints and minimum OS/device matrix.
9. The production authentication recovery method: password reset, email OTP, or both.
10. Which commercially described features are release commitments for the next customer launch.

## 15. Final recommendation

The strongest next milestone is not the addition of the greatest number of features. It is a coherent, task-oriented, offline-safe teacher workflow that completes attendance, logbook, grading, report-card comments, and communication with less friction than the web application.

Once that foundation is reliable and adopted, student context, homework tracking, resources, availability, analytics, and AI assistance can add meaningful differentiation without increasing operational risk.
