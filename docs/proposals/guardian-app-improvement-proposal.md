# Edaya Guardian app — Improvement proposal

| Field | Value |
|---|---|
| Status | Proposal |
| Date | 12 July 2026 |
| Scope | `apps/guardian`, guardian-facing shared mobile foundations, and supporting API changes |
| Objective | Move the working proof of concept toward a secure, reliable, high-value production guardian experience |

## Executive summary

The Guardian app has a credible technical and functional base and should be evolved rather than rewritten. It already supports authentication, linked-student selection, academic-year context, timetable and school events, attendance history, curriculum progress, class logbook entries, grades, report cards, fees, payment history, inbox messages, push notifications, localization, and appearance preferences.

The principal product gap is not the number of modules. It is that the app behaves as a set of read-only data views rather than as a daily family companion. Guardians must inspect each module to discover what matters, and most issues cannot be acted upon from the app.

The proposed product shift is:

> From “five places where guardians inspect school data” to “one daily action centre that tells guardians what matters and lets them respond.”

The recommended sequence is:

1. Make the current product safe and correct for production.
2. Reorganize the experience around a Home/action centre and guardian goals.
3. Add high-value actions that can reuse existing backend capabilities.
4. Add engagement and payment workflows that require backend/product extensions.
5. Treat AI and Guardians Vault as later differentiation, after the core experience is trusted.

## Proposal goals

- Make the app safe for public distribution and child/family data.
- Reduce the time needed to find important information.
- Let guardians complete common school interactions without calling or visiting administration.
- Keep multi-child and multi-year context explicit and trustworthy.
- Remain usable on slow and intermittent mobile networks.
- Establish a reusable UI and navigation foundation for future guardian features.
- Create measurable product outcomes rather than only screen-completion outcomes.

## Non-goals

- Rewriting the Flutter application or replacing the shared mobile architecture.
- Replicating the complete staff web portal on mobile.
- Giving guardians unrestricted access to staff-only health, incident, or internal-note data.
- Committing Guardians Vault or AI features to the initial production release.
- Introducing online payments before settlement, reconciliation, refund, support, and provider responsibilities are defined.

## Audit basis

This proposal is based on:

- The Guardian app routes, controllers, widgets, models, and configuration.
- Shared authentication, settings, theme, push-notification, and account code.
- The generated mobile API surface and relevant backend domain capabilities.
- Existing Guardian API and widget integration tests.
- A mobile-sized visual inspection of the current sign-in experience.
- `flutter analyze`, which completed with no issues.
- Guardian non-integration tests, which completed successfully (5 tests at the time of the audit).

The local API available during the visual audit authenticated the demo email but did not expose the expected linked guardian actor. Authenticated screens were therefore assessed from their implementation and existing live-integration test coverage rather than from a complete manual visual walkthrough.

## Current product inventory

### Available guardian journeys

| Area | Current capability | Current interaction level |
|---|---|---|
| Account | Email/password sign-in, restored session, profile editing, sign-out | Read/write |
| Preferences | Theme, language, timezone, date format, time format | Read/write |
| Student context | Linked-student list, active-student persistence, class/enrollment context | Read/select |
| Academic context | Academic-year list and persisted selection | Read/select |
| Calendar | Weekly timetable, day selection, week navigation, school events | Read |
| Session detail | Attendance state and class logbook content | Read |
| Attendance | Historical attendance list | Read |
| Learning | Subject selection, programme progress, topic progress, class logbook | Read |
| Evaluations | Period selection, subject groups, grade detail, provisional averages | Read |
| Report cards | Published report-card list and detail | Read |
| Fees | Expected, paid, balance, fee lines, overdue count | Read |
| Payments | Recorded payment history and detail | Read |
| Inbox | Message list, unread state, message detail, mark as read | Read/minor write |
| Notifications | FCM registration, foreground display, basic destination routing | Receive/navigation |

### Technical strengths to preserve

- Feature-oriented Flutter organization.
- Shared auth, bootstrap, theme, settings, push, and UI foundations with the Teacher app.
- Generated domain-shaped API client.
- Reactive student/year context.
- French and English localization.
- Light and dark themes.
- Route guards for authentication.
- Existing live API integration-test harnesses for multiple guardian profiles.
- Backend authorization concepts for guardian-scoped student data.

## Critical findings and release blockers

### P0.1 — Production authentication still presents development behavior

Current behavior includes:

- Demo email and password defaults compiled into the app.
- Guardian development instructions on the sign-in screen.
- API endpoint switching intentionally enabled in production.
- Local, staging, and production endpoint choices available to end users.
- No password-reset or invitation-activation journey in the Guardian UI.
- No password visibility control, account support path, privacy link, or terms link.

Required change:

- Introduce build flavors/configuration for development, staging, internal QA, and production.
- Production builds must contain no demo credentials and no user-accessible endpoint switcher.
- The production endpoint must be an immutable build/release configuration.
- Add invitation activation, forgot-password, and email OTP sign-in.
- Add privacy, terms, and account-support links.
- Replace development copy with a school/guardian-oriented explanation.

Acceptance criteria:

- A release build contains no demo email, demo password, local URL, staging selector, or developer copy.
- A guardian can recover access without administrator-side manual password intervention.
- Internal QA retains an intentional, visibly non-production endpoint selector.

### P0.2 — Auth cookies are stored in ordinary preferences

Native authentication cookies are currently serialized into `SharedPreferences`. The app contains child attendance, results, and family financial information, so session material must use platform-secure storage.

Required change:

- Store session secrets using Keychain on iOS and Keystore-backed secure storage on Android.
- Define session-expiration, invalid-session, and forced-re-authentication behavior.
- Clear all child/year cached context on sign-out and account change.
- Add server/device session revocation if supported by the auth platform.
- Remove push-token logging from release builds.
- Consider optional biometric re-entry after the base session model is secure.

Acceptance criteria:

- No reusable auth secret is stored in plain application preferences.
- Expired/revoked sessions return to sign-in with a friendly explanation.
- Sign-out clears session credentials, cached private data, and registered push-device state.

### P0.3 — Provisional grade averages can be incorrect across score scales

The app retains `score`, `maxScore`, and `coefficient`, but its weighted-average calculation multiplies the raw score by the coefficient. It does not normalize different maximum scores before displaying an average out of 20.

Example:

- 8/10, coefficient 1
- 14/20, coefficient 1
- Current raw average: 11/20
- Normalized average: 15/20

Required change:

- Prefer backend-authoritative aggregates that use the school’s configured grade scale and rounding rules.
- If the app must compute a provisional average, normalize every result to the configured display scale before applying its coefficient.
- Define behavior for missing results, exempt results, zero/invalid maximums, and non-numeric scales.
- Mark client-calculated values as provisional.

Acceptance criteria:

- Automated tests cover mixed maximum scores, coefficients, missing results, invalid maximums, and rounding.
- Guardian provisional averages match the staff/backend calculation for the same dataset.
- Official report-card averages are visually distinguished from provisional current-period averages.

### P0.4 — Detail routes and notification links are not restart-safe

Session, grade, report-card, payment, and message routes depend on complete Dart objects passed through `state.extra`. These routes cannot be reliably restored from a URL, app restart, cold notification launch, or external link.

Notification navigation is also discarded if the user is signed out when the notification is opened.

Required change:

- Use stable ID-based routes.
- Fetch destination data by ID in the destination controller.
- Preserve an intended notification destination through authentication.
- Validate notification paths against an application-owned allowlist.
- Handle missing, deleted, unauthorized, and no-longer-published resources.

Proposed route shape:

```text
/students/:studentId/sessions/:sessionId
/students/:studentId/attendance/:attendanceId
/students/:studentId/grades/:resultId
/students/:studentId/report-cards/:reportCardId
/students/:studentId/fees/:studentFeeId
/payments/:paymentId
/messages/:deliveryId
```

Acceptance criteria:

- Every supported detail destination can open from a cold start using IDs only.
- Opening a notification while signed out resumes the intended destination after successful sign-in.
- Invalid IDs show a friendly recoverable state instead of a missing-route-data error.

### P0.5 — Raw technical errors and raw API values reach guardians

Several controllers include `error.toString()` in visible user messages. Attendance statuses, justification statuses, event kinds, and some dates are also rendered directly rather than through localization and formatting rules.

Required change:

- Map API/network errors to stable user-facing error codes and localized copy.
- Send technical detail to structured logs/crash reporting, not the screen.
- Map all status/kind enums to localized labels, icons, and semantic colors.
- Apply the selected date/time and locale format consistently.

Acceptance criteria:

- No stack trace, raw exception, internal entity ID, or API transport message is exposed in normal UI errors.
- All supported statuses and kinds have French and English labels.
- Unknown values use a safe localized fallback and are captured in telemetry.

## Product direction

### Primary guardian jobs

The final information architecture should serve these jobs:

1. Tell me what needs attention for each child.
2. Tell me what is happening today and next.
3. Help me respond to an absence, message, fee, or school request.
4. Let me understand progress without reconstructing it from several screens.
5. Let me retrieve official school documents and payment evidence.
6. Keep me informed even when the network is weak.

### Proposed top-level navigation

```text
Accueil | Agenda | Scolarité | Frais | Messages
```

Rationale:

- Add a Home/action-centre destination.
- Merge the overlapping `Academic` and `Evaluations` destinations into `Scolarité`.
- Use shorter French labels that fit mobile navigation.
- Preserve five destinations while increasing product value.

### Proposed Scolarité structure

```text
Scolarité
├── Vue d’ensemble
├── Notes
├── Programme
├── Cahier de textes
└── Bulletins
```

Use an accessible tab or section pattern rather than placing all submodules in bottom navigation.

### Proposed global header

- Child switcher pill showing avatar, name, and class.
- Profile/account button.
- Screen title below or within the destination content.
- Academic-year filter within screens where it matters.
- A single child-switching affordance instead of both title content and a separate people button.
- An explicit `Tous les enfants` or `Établissement` scope for global messages where applicable.

## Feature proposals

### F1 — Home and action centre

Priority: P0 product foundation

Purpose: answer “What needs my attention?” within five seconds.

Recommended content order:

1. Active child and class.
2. Urgent/action-needed card.
3. Today/next timetable item.
4. Recent grade or published report card.
5. Fee balance and next due date.
6. Unread or important message.
7. Upcoming school event.

Recommended actions:

- Justify an absence.
- Open an urgent message.
- View/download a report card.
- View an overdue fee.
- Download a receipt.
- Switch child.

Rules:

- Show at most one primary urgent item and a small remaining count.
- Hide modules disabled for the school’s plan/configuration.
- Use cached data immediately, then refresh in the background.
- Never show a child-specific action without the child’s name/avatar.

Acceptance criteria:

- A guardian can reach any attention item in one tap.
- Home renders a useful state even if one downstream module fails.
- Items update after child/year changes without showing stale data from the previous child.

### F2 — Attendance summary and justification

Priority: P0 high-value action

Existing foundation:

- Attendance reads exist.
- Attendance records contain justification state and reason.
- The API exposes `requestAttendanceJustification`.

Proposed experience:

- Academic-year summary: present, absent, late, excused.
- Filters: month, status, unresolved justification.
- Resolved session/subject names returned with attendance data.
- `Justifier cette absence` action where permitted.
- Reason entry and optional supporting document/photo.
- Review state: pending, accepted, rejected.
- Notification when review completes.

Backend/API needs:

- Confirm guardian authorization for the request command with negative cross-student tests.
- Return enriched/paginated attendance rather than resolving each occurrence through separate calls.
- Define how attachments associate with justification requests.
- Define whether a rejected request may be revised/resubmitted.

Acceptance criteria:

- A guardian cannot justify attendance for an unlinked student.
- Duplicate submission behavior is defined and idempotent.
- The staff review state is reflected without a full sign-out/restart.

### F3 — Official documents and downloads

Priority: P0 high-value action

Initial document types:

- Published report-card PDF.
- Payment receipt.
- School-provided message/announcement attachment.
- Attendance justification evidence uploaded by the guardian, if enabled.

Proposed experience:

- Preview metadata before download.
- Download/share using expiring authorized URLs.
- Clearly label official versus informational documents.
- Show unavailable/expired/removed states.
- Record document-access telemetry without recording document contents.

Existing foundation:

- Attachment entities and authorized download URLs exist.
- Guardian `ReadAttachments` capability exists.

Acceptance criteria:

- Guardians can only download attachments associated with resources they may read.
- Expired URLs are refreshed without exposing the storage URL as a permanent link.
- Report-card and receipt downloads use stable file names.

### F4 — Production account lifecycle

Priority: P0

Scope:

- School invitation activation.
- Email/password sign-in.
- Email OTP sign-in.
- Forgot/reset password.
- Expired/revoked invitation messaging.
- Account support/contact school path.
- Secure sign-out and optional session/device management.

Acceptance criteria:

- Every account state has a guardian-understandable next step.
- Account recovery does not disclose whether unrelated email addresses exist.
- OTP resend, expiry, throttling, and error handling are defined.

### F5 — Notification centre and preferences

Priority: P0/P1

Proposed notification categories:

- Attendance and justification.
- Results and report cards.
- Fees and payment receipts.
- Messages and announcements.
- Calendar events and reminders.
- Homework/deadlines when available.

Proposed capabilities:

- Unread badge on Messages.
- In-app notification history aligned with inbox/delivery records.
- Per-category preferences where school policy permits.
- Quiet hours for non-urgent notifications.
- Child-specific notification context.
- Cold-start and signed-out destination recovery.

Acceptance criteria:

- Push open-to-destination success is measurable.
- A foreground, background, terminated, and signed-out notification path is tested.
- Denied OS notification permission has a clear recovery explanation.

### F6 — Offline and weak-network support

Priority: P1

Minimum offline-readable data:

- Current week timetable.
- Upcoming school events.
- Recent grades and latest report card metadata.
- Recent messages.
- Current fee balance and recent payments.
- Active student/year selection.

Behavior:

- Show cached content immediately with `Mis à jour …` metadata.
- Refresh in the background.
- Keep a visible offline/stale indicator.
- Queue only safe, idempotent actions; otherwise require connectivity before submission.
- Encrypt private local cache where platform threat modeling requires it.

Acceptance criteria:

- The app launches to useful recent content in airplane mode after prior successful use.
- Child data cannot bleed between accounts after sign-out/sign-in.
- A stale cache is never presented as freshly synchronized.

### F7 — Guardian-initiated payments

Priority: P1; commercial/backend dependency

Recommended initial methods should match target markets and contracts, including Mobile Money where appropriate.

Required product decisions:

- Payment provider and settlement ownership.
- Currency and provider fees.
- Pending/failed/expired flows.
- Partial payment and instalments.
- Duplicate-payment prevention.
- Reconciliation and receipt generation.
- Refund/reversal responsibilities.
- Guardian and school support processes.

Proposed experience:

- `À payer`, `À venir`, and `Payé` grouping.
- Due-date timeline and instalment detail.
- `Payer` action only for eligible fee lines.
- Provider handoff or embedded secure payment.
- Pending confirmation state.
- Official receipt after confirmed settlement.

Acceptance criteria:

- Payment status is backend-authoritative.
- Reopening the app safely resumes a pending transaction.
- Retrying cannot create an unintentional duplicate charge.
- Financial events have an auditable reference shared by app, backend, provider, and staff UI.

### F8 — Richer family communication

Priority: P1; messaging-model extension

Recommended staged capabilities:

1. Explicit acknowledgement (`J’ai pris connaissance`).
2. School forms, polls, and consent requests.
3. Controlled replies for conversations enabled by the school.
4. Attachments and action links.

Avoid presenting all announcements as open chat. Schools should control replyability, closure, moderation, response deadline, and responsible staff destination.

Multi-child requirements:

- Label each child-specific message.
- Separate establishment/global messages from child-scoped messages.
- Do not imply that the active child filters a global guardian inbox unless it actually does.

### F9 — Homework and deadlines

Priority: P1; requires backend redesign

The current Guardian UI has a `homework` field in its session model, but the live logbook loading path does not populate it, and dedicated homework tables were removed from the backend. This should not be treated as a small mobile-only change.

Required domain decisions:

- Assignment versus assessment semantics.
- Class/subject/student targeting.
- Due date and late rules.
- Instructions and attachments.
- Submission requirements and status.
- Guardian visibility versus student ownership.
- Reminder rules.

Proposed guardian experience:

- Upcoming deadlines grouped by date.
- Clear subject, child, teacher instructions, and attachments.
- Missing/late/turned-in state only when the data is authoritative.
- Add to device calendar/reminder.

### F10 — Learning insights

Priority: P1/P2

Recommended insights:

- Period-over-period subject trend.
- New grade since last visit.
- Curriculum progress by subject and topic.
- Teacher comment emphasis.
- Areas improving, stable, or needing attention.

Guardrails:

- Use backend-authoritative aggregates.
- Do not infer student ability or make high-stakes recommendations from sparse data.
- Avoid overemphasizing rank.
- Explain how averages/trends are calculated.

### F11 — Wellbeing, incidents, health, forms, and appointments

Priority: P2; policy and authorization work

Potential value exists, but these areas contain sensitive information and should follow explicit school policy and data-minimization decisions.

Possible guardian-safe capabilities:

- Guardian-visible incident summary and required follow-up.
- Appointment request with teacher/administration.
- Review of guardian-provided emergency contacts.
- Consent and permission forms.
- Guardian-submitted updates that require staff approval.

Do not expose staff-only internal notes, third-party student information, clinical notes, or disciplinary details without an explicit legal/product decision and authorization coverage.

### F12 — Guardians Vault and AI

Priority: Later differentiation

Guardians Vault should begin as a narrowly scoped secure document area after official report-card/receipt downloads are mature. Define document ownership, retention, export, account closure, encryption, signing, emergency access, and school-versus-guardian responsibility before implementation.

The AI student portal should remain a separate safeguarded student experience. It should not be used to compensate for missing core guardian journeys, data correctness, or school workflow design.

## UX and UI proposal

### Design principles

1. Action before navigation.
2. Child context is always visible when it matters.
3. Official data and provisional calculations are clearly distinguished.
4. Urgency is conveyed by copy, icon, and structure—not color alone.
5. Long content uses full-screen details.
6. Cached/stale/offline states are explicit.
7. Empty states explain why content is empty and what to do next.
8. School configuration can hide unavailable modules without leaving broken navigation.

### Sign-in and onboarding

Replace the current development-oriented sign-in screen with:

- Edaya Guardian brand/logo.
- Welcome text explaining school-provided access.
- Email field.
- Password field with show/hide control.
- Primary sign-in action.
- `Use a one-time code` alternative.
- `Forgot password?` action.
- School/account support link.
- Privacy and terms links.
- Clear staging/internal build badge only outside production.

### Home layout

```text
┌─────────────────────────────────────┐
│ [Avatar] Aïcha Koné · 6e A      [●] │
│ Année 2025–2026                    │
├─────────────────────────────────────┤
│ Action requise                     │
│ Absence à justifier · aujourd’hui  │
│                         [Justifier] │
├─────────────────────────────────────┤
│ Aujourd’hui                        │
│ 10:00 Mathématiques · Salle 12     │
│ 14:00 Activité sportive            │
├─────────────────────────────────────┤
│ Dernière note       Solde frais    │
│ 16/20 Français      35 000 FCFA    │
├─────────────────────────────────────┤
│ 2 nouveaux messages                │
└─────────────────────────────────────┘
```

This is conceptual, not a pixel specification.

### Component system

Add reusable components for:

- Guardian context switcher.
- Attention/action card.
- Status chip with semantic icon and label.
- Summary metric.
- Timeline row.
- Amount and balance presentation.
- Score with scale and provisional/official label.
- Child/global scope badge.
- Skeleton list/card.
- Offline/stale banner.
- Empty state with action.
- Error state with support/reference code.
- Document row and download state.

### Visual hierarchy

The current design uses similar outlined cards for most information. The final design should reserve prominent surfaces for important or actionable content.

- Use a strong attention surface for unresolved absences, urgent messages, and overdue fees.
- Use lightweight list rows for ordinary history.
- Use consistent semantic states: success, information, warning, overdue/error, pending, unread.
- Use subject accents carefully and consistently.
- Use typography to distinguish title, context, value, and metadata.
- Bundle fonts as application assets; do not depend on runtime font fetching.
- Use guardian-specific iconography and brand artwork in onboarding and empty states.

### Long details and modal usage

Bottom sheets should be limited to short choices such as:

- Child selection.
- Academic-year selection.
- A compact filter selector.

Use full-screen routes for:

- Report cards.
- Message detail.
- Session/logbook detail.
- Attendance justification.
- Fee and instalment detail.
- Payment receipt.
- Documents.

### Accessibility

Required validation:

- Screen readers on iOS and Android.
- 200% text scaling.
- Minimum 44×44 iOS and 48×48 Android touch targets.
- No status conveyed by color alone.
- Logical focus order.
- Semantic labels for progress indicators, scores, unread state, and amounts.
- Contrast validation in light and dark themes.
- Reduced-motion behavior.
- Keyboard and navigation-rail support for tablet/web layouts.

Known layout pressure points:

- Five long bottom-navigation labels.
- Seven weekday controls in one row.
- Up to four academic periods in a segmented control.
- Student name, class, year, account, and student switcher in one app bar.
- Three fee summary metrics in one row.

### Responsive design

Suggested breakpoints/behaviors:

- Compact phone: bottom navigation, single-column content.
- Large phone/small tablet: constrained content width and wider cards.
- Tablet/web: navigation rail, optional master/detail layout, max content width.
- Landscape: preserve usable vertical content and avoid oversized global app bars.

## Data, performance, and architecture proposal

### Preserve state per destination

Use a stateful indexed shell so switching destinations does not unnecessarily recreate controllers, reset filters, or lose scroll position.

State to preserve:

- Calendar week/day and timetable/events selection.
- Scolarité period/subject/subsection.
- Fee grouping/filter.
- Inbox filter and scroll position.

### Prevent stale child/year responses

Student and academic-year changes currently trigger several reactive reloads. Add request versioning/cancellation so a slower response for the previous child/year cannot overwrite the current context.

Acceptance criteria:

- Rapidly switching children cannot display the first child’s data under the second child’s header.
- Loading indicators identify which context is loading.

### Reduce request fan-out

Current examples include:

- One request per distinct attendance occurrence to resolve its title.
- One request per fee ID to resolve fee names.
- Several sequential evaluation and curriculum entity reads.

Recommended API additions:

- `getGuardianHome(studentId, academicYearId)` with independently optional sections.
- Enriched paginated attendance feed.
- Enriched fee/account statement.
- Guardian academic overview for period/subject aggregates.
- Message feed with child/global scope metadata.

Do not build a single unbounded “everything” payload. Home sections should be independently cacheable and capable of partial failure.

### Pagination

Required for:

- Attendance history.
- Messages.
- Payments for long-lived accounts.
- Documents.

Use stable cursor-based pagination where backend ordering may change.

### Observability

Add:

- Crash reporting.
- Structured application logs.
- API request timing and error classification.
- Push lifecycle events.
- Navigation/deep-link success events.
- Product analytics for high-level guardian journeys.

Privacy rules:

- Do not put student names, message bodies, grades, medical data, or payment details in analytics/crash breadcrumbs.
- Use tenant-safe pseudonymous identifiers only where needed.
- Define retention and access controls.

## Delivery roadmap

Effort ranges assume one cross-functional squad and are planning ranges, not commitments.

### Phase 0 — Production safety and correctness

Estimated range: 2–3 weeks

- [ ] Introduce production-safe build flavors/configuration.
- [ ] Remove demo credentials and developer UI from production.
- [ ] Move auth secrets to secure storage.
- [ ] Fix or server-source grade averages.
- [ ] Convert detail navigation to ID-based routes.
- [ ] Preserve notification destinations through sign-in.
- [ ] Map errors and API states to localized presentation.
- [ ] Remove sensitive debug output.
- [ ] Add crash reporting and baseline instrumentation.
- [ ] Add focused controller/navigation/security tests.

Exit criteria:

- No known sensitive-storage issue.
- No development-only behavior in release.
- Mixed-scale grades are correct.
- Cold-start and signed-out notification links work.
- Critical errors are observable without exposing technical details to guardians.

### Phase 1 — Experience foundation

Estimated range: 3–5 weeks

- [ ] Add Home/action centre.
- [ ] Merge Academic and Evaluations under Scolarité.
- [ ] Simplify global header and context controls.
- [ ] Adopt stateful destination navigation.
- [ ] Add guardian component library.
- [ ] Add skeleton, empty, error, offline, and stale states.
- [ ] Add responsive navigation rail and content constraints.
- [ ] Run accessibility and French large-text audits.

Exit criteria:

- Important attention items appear on Home.
- Core information is reachable within two taps.
- Navigation fits supported French/English phone sizes.
- Destination state persists across tab changes.

### Phase 2 — High-value guardian actions

Estimated range: 4–6 weeks

- [ ] Attendance summary and filters.
- [ ] Attendance justification submission and review status.
- [ ] Report-card download/share.
- [ ] Payment receipt download/share.
- [ ] Message attachments and scope labels.
- [ ] Notification badges and preferences.
- [ ] Cached read-only access to recent critical data.

Exit criteria:

- Guardians can resolve an absence in-app.
- Official documents can be retrieved without administration assistance.
- Multi-child messages cannot be misattributed.
- Core recent information remains visible offline.

### Phase 3 — Engagement and revenue

Estimated range: 6–10 weeks, depending on providers and backend scope

- [ ] Guardian-initiated Mobile Money/card payments.
- [ ] Message acknowledgement, forms, polls, and controlled replies.
- [ ] Homework/deadline domain and Guardian experience.
- [ ] Academic trends using authoritative aggregates.
- [ ] Guardian-safe wellbeing/follow-up workflows.

Exit criteria:

- Payment status and reconciliation are auditable end-to-end.
- Communication workflows have clear ownership and closure.
- Homework data has an authoritative domain model.

### Phase 4 — Differentiation

- [ ] Guardians Vault discovery and threat model.
- [ ] Secure document ownership/retention/export workflows.
- [ ] Dedicated student experience.
- [ ] Safeguarded AI learning assistance.

## Prioritized backlog summary

| ID | Item | Priority | Value | Relative effort | Primary dependency |
|---|---|---:|---:|---:|---|
| G-001 | Production-safe auth/build configuration | P0 | Critical | M | Release configuration |
| G-002 | Secure session storage | P0 | Critical | S–M | Secure-storage package/platform QA |
| G-003 | Correct/backend-authoritative averages | P0 | Critical | S–M | Assessment rules |
| G-004 | ID-based routes and deep-link recovery | P0 | High | M | Detail read endpoints |
| G-005 | Localized error/status system | P0 | High | M | Error taxonomy |
| G-006 | Crash/product observability | P0 | High | M | Privacy decisions |
| G-007 | Home/action centre | P0 | Very high | L | Aggregate/read-model design |
| G-008 | Navigation/Scolarité consolidation | P0 | High | M | UX design |
| G-009 | Attendance justification | P0 | Very high | M | Authorization/attachment decisions |
| G-010 | Report-card and receipt downloads | P0 | High | M | File generation/association |
| G-011 | Message scope and unread badge | P0 | High | S–M | Message metadata |
| G-012 | Offline recent-data cache | P1 | High | L | Cache/security design |
| G-013 | Enriched/paginated attendance | P1 | High | M | API read model |
| G-014 | Enriched fee statement | P1 | High | M | API read model |
| G-015 | Notification preferences | P1 | Medium–high | M | Backend preference storage |
| G-016 | Guardian-initiated payment | P1 | Very high | XL | Provider/reconciliation |
| G-017 | Message acknowledgement/forms/replies | P1 | High | L | Messaging domain extension |
| G-018 | Homework and deadlines | P1 | High | XL | Homework domain redesign |
| G-019 | Academic trends | P1 | Medium–high | M–L | Authoritative aggregates |
| G-020 | Guardian-safe wellbeing workflows | P2 | Medium | L | Policy/authorization |
| G-021 | Guardians Vault | P2 | Strategic | XL | Security/legal/product discovery |
| G-022 | AI student experience | Later | Strategic | XL | Student product/safeguarding |

## Testing strategy

### Unit tests

- Grade normalization and coefficients.
- Status/error mapping.
- Money/date formatting.
- Home priority rules.
- Child/year stale-response protection.
- Notification destination parsing and allowlisting.

### Widget tests

- Compact French navigation at supported text scales.
- Child and academic-year switching.
- Empty, error, stale, and offline states.
- Attendance-justification validation.
- Full-screen detail loading by ID.
- Screen-reader semantics for status, score, progress, and unread state.

### Integration tests

- Invitation/OTP/password account lifecycle.
- Multi-child scope isolation.
- Notification open in foreground/background/terminated/signed-out states.
- Attendance justification submission and staff review.
- Report-card and receipt downloads.
- Offline launch after a prior successful synchronization.
- Payment success, pending, failure, retry, and duplicate-prevention paths.

### Visual regression tests

- Light/dark themes.
- French/English.
- Small Android phone, standard iPhone, tablet.
- Default and 200% text scale.
- Home, Scolarité, Fees, Messages, and key details.

### Security tests

- Cross-student and cross-school access denial.
- Unauthorized attachment download.
- Attendance justification for unrelated student.
- Expired/revoked session behavior.
- Local cache removal on account change.
- Malformed/untrusted notification paths.

## Product metrics

Define baselines before Phase 1 and segment by school and app version.

### Activation and reliability

- Invitation-to-successful-activation rate.
- Sign-in success and recovery completion rate.
- Crash-free sessions.
- API error rate by journey.
- Screen-load p50/p95 on representative mobile networks.
- Push delivery-to-open and open-to-destination success.

### Engagement

- Weekly active guardians.
- Percentage of linked students viewed.
- Home attention-item open and completion rate.
- Unread-message age.
- Report-card view/download rate.

### Operational value

- Attendance justification completion rate.
- Median justification review time.
- Guardian support contacts per 100 active guardians.
- Receipt self-service rate.
- Fee reminder-to-payment conversion after payment launch.
- Reduction in school-side routine calls/messages for information already available in the app.

## Open product decisions

Resolve these before committing Phase 2/3 scope:

1. Is the product named Guardian, Parent, Family, or Parent/Student in each market?
2. Which modules can a school enable/disable by plan or configuration?
3. Is the inbox guardian-global, child-filterable, or both?
4. Which attendance states may a guardian justify, and for how long?
5. Can guardians attach evidence, and what retention applies?
6. What is the authoritative current-period average and rounding rule?
7. Which documents are official, who generates them, and how are they signed/versioned?
8. Which payment providers, countries, currencies, and fee models are supported first?
9. Are guardian replies directed to a teacher, administration queue, or conversation owner?
10. What health/incident information is legally and operationally appropriate for guardians?
11. What offline retention duration is acceptable for child data?
12. Which analytics events are permitted under the privacy policy?

## Definition of production-ready Guardian beta

The Guardian beta is ready when:

- Production builds contain no demo credentials or endpoint-switching UI.
- Session secrets use secure platform storage.
- Grade calculations are verified against backend rules.
- ID-based cold-start navigation works for supported notifications.
- Child/year context cannot show stale data from another selection.
- Errors and statuses are fully localized and non-technical.
- Home exposes the most important guardian information and actions.
- Attendance justification and official document retrieval work end-to-end.
- Core recent content has defined weak-network/offline behavior.
- Crash reporting, privacy-safe analytics, and support diagnostics are operational.
- French/English accessibility and responsive-layout checks pass.
- Security tests verify guardian, student, school, and attachment isolation.

## Recommended next planning artifact

Convert Phase 0 and Phase 1 into implementation epics containing:

- User story and user value.
- UX flow and screen states.
- API/read-model changes.
- Authorization requirements.
- Analytics events.
- Localization copy.
- Accessibility requirements.
- Unit/widget/integration acceptance tests.
- Rollout and migration plan.

Phase 0 should be scheduled before adding major net-new guardian modules. Phase 1 should establish the final navigation and component foundation so later features do not deepen the current proof-of-concept structure.
