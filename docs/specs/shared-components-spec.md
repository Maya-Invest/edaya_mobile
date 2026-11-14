# EDAYA mobile component registry — 1.0.0

Normative for the current Guardian and Teacher apps. Extend these components before adding new shared UI. Controllers, calculations, routing and callback conditions remain unchanged by visual work.

| Component | Source | Reuse contract |
|---|---|---|
| AppTheme / EdayaColors / EdayaTypography | shared `lib/src/app/` | Existing light/dark/system entry points; generated tokens and bundled fonts |
| EdayaBrandLogo | shared `lib/src/ui/` | Supplied color/white horizontal, vertical, symbol artwork; minimum size and clear space; artwork width remains bounded in stretched layouts |
| Android app / notification icons | app `android/app/src/main/res/`; shared `features/push/push_notifications.dart` | Teacher v2 pairs its white adaptive foreground with primary blue; local notifications and FCM metadata use the monochrome `ic_stat_notification` small icon |
| CalendarWeekStrip | shared `lib/src/ui/` | Theme-aware day buttons, 48dp targets, full-date labels and selected semantics; scrolling at large text; optional `daySpacing` (default 0) preserves existing callers; localized week chevrons use caller callbacks |
| ResponsiveMetrics | shared `lib/src/ui/` | Wrap existing metric values by width/text scale; never compute domain totals |
| PersonAvatar | shared `lib/src/ui/` | Preserve names/initials/photo fallback and operational identity; both app wrappers use the shared authenticated download-grant loader, including pending student portraits. Rewrite local storage hosts for emulators; authenticate same-origin memory storage and never forward API credentials to external storage |
| Profile photo crop/upload | shared `lib/src/features/profile_photo/` | Camera/gallery fallback, rotate/export JPEG ≤ 1 MiB, named portrait commands |
| DataState | shared `lib/src/common/widgets/` | Existing ready/loading/empty/error signals and retry callback |
| AccountSheetBody / AccountProfileHeader | shared common/account widgets | Existing account/profile actions and semantics |
| ModalBottomSheetPage | shared `lib/src/common/models/` | Existing modal navigation, safe area and dismissal behavior |
| LoginPage | shared `lib/src/features/auth/` | Shared `PasswordlessLoginForm`: One contact field with automatic email/international-phone detection, WhatsApp first and explicit SMS fallback, a teacher-only eight-character quick-code option, TOTP and recovery; branded logo and existing session callbacks |
| GuardianAppBar / TeacherAppBar | app `design/components/` (`PrototypeAppBar`) | Student/class/year context before decoration; current actions retained |
| SessionTile / TeacherSessionTile | app calendar widgets | Current title, subject, class, kind and time; same detail navigation |
| FeesSummaryCard / GradeSummaryCards | Guardian feature widgets | All totals and labels retained; responsive numeric presentation |
| ConversationMessageBubble | shared `features/messaging/` | Sent/received alignment, selectable body, author and localized date; profile kind + ID classification |
| InboxDeliveryTile | Guardian inbox widgets | Unread status, date, title and body with existing message route |
| AttendanceRowTile | Teacher session widgets | Neutral identity, semantic status label, same edit/record callback |
| MarkRowTile | Teacher evaluations widgets | Existing score and locked condition; edit disabled under the same rule |

Icon-only actions need localized semantic labels. Existing sheet and dialog close buttons use `MaterialLocalizations.of(context).closeButtonTooltip`; actions with another meaning, such as removing an item, retain their own specific label. Do not change callbacks or dismissal results to add a label.

Cover approved variants and default/selected/disabled/busy/error/empty states in current galleries. Add shared presentation only for demonstrated reuse; single-feature needs stay local. Record visual exceptions with rationale, affected components, owner, lifetime, alternatives and responsive/contrast evidence. Changes update tokens, specification, registry and current captures together.

## Marks correction surfaces

Submitted marks remain read-only in the teacher grading list. MarksCorrectionsPanel shows official versus proposed values and terminal review reasons, and opens a scoped batch proposal dialog. Published source marks cannot be selected. Correction requests and withdrawal run online only; author identity and scope are enforced by the backend. Draft outbox conflicts remain visible and must not replace submitted official values on screen.

`SurfaceCard` in both apps defaults to the active theme surface, keeping text and input contrast consistent in light and dark mode. Login canvases follow the same theme. Shared login guidance uses translated email-only or email/phone copy according to server capabilities.

## Account authentication

Shared `LoginPage` and `LoginController` implement automatic email/international-phone detection and validation in one login contact field, email/phone OTP, authenticator verification/enrollment, recovery-code replacement and one-time recovery-code display for both apps. `AccountSecurityPage` links/unlinks verified contacts and enrolls an optional authenticator. Identifier removal requires the shared confirmation dialog. Auth challenges and TOTP secrets remain transient controller/client state; only the completed opaque renewal credential is persisted by the existing session storage.

Before email verification the shared login form must not disclose Account existence. For a verified email without an Account, replace the OTP controls with a registration step. Explain the absence once. Offer Create account as the primary action only when the server permits it; otherwise give invitation guidance. Offer Use another email in either case. Creating an Account reuses the verified email and does not accept an invitation, grant a school role or bypass MFA. Preserve the pending invitation or existing app destination. Existing-account and authenticated contact-linking flows do not show registration.

Keep the registration proof in transient workflow memory. Email change, restart, departure or expiry requires fresh verification. Changed terms require fresh consent, not another OTP while the proof is valid. On an uncertain completion response check for an established session, then restart verification if none exists. A confirmed email send failure shows one inline contact-step error with the server retry time; a confirmed failed resend also clears the invalid code and challenge. Distinguish an unconfirmed network outcome and do not send automatically. Announce each error once; move focus to the new step and keep its actions reachable with large text and the keyboard open.

## Integration coverage maintenance

Feature changes must update their registered action scenarios and executable assertions in the same PR. Shared authentication components are exercised through their production forms and captured local delivery transport. Route inventory, action registration and successful execution are all required; reviewers verify that assertions establish the intended behavior. See [integration testing](../reference/integration-testing.md).

`OtpDeliveryControls` and `OtpDeliveryState` share server countdown, delivery guidance and explicit resend/SMS/retry actions between login and contact linking. The owning controller closes the timer and reactives with its route. Poll only on the visible active verification screen; clear the code text controller after each replacement.

`OtpDeliveryControls` shares the test-code panel for login and contact linking. Teacher_v2 enables test OTP discovery in debug builds and automatically pulls a pending test code during visible login or contact-linking status checks. Debug iOS Simulator launches default to the local API on port 9999. An explicit `TEST_OTP_ACCESS=false` disables it. Other clients opt in with `TEST_OTP_ACCESS=true`. Every client requires the server to advertise OTP access. Profile and release builds disable test OTP requests. In teacher_v2, an empty verification field receives the current test code and displays a localized test-mode hint. The user can edit it and must tap Verify. Other clients retain their explicit reveal and copy actions. `OtpDeliveryState` clears it on replacement, expiry, completion, reset, departure, backgrounding and closure, and discards stale lookups. No OTP enters session storage, telemetry or test artifacts. Both French and English labels are required.

Identity advertises phone availability. Until discovery succeeds with phone available, authentication and contact-linking forms display email-only labels, omit phone choices and country hints, and reject pasted phone identifiers locally with translated feedback. Discovery failures fail closed to email-only; phone controls return when availability is explicitly restored. Email OTP, authenticator verification/enrollment and recovery remain available.

## Teacher correction forms

Teacher correction forms show proposed editable fields and a single required correction reason. Grade corrections include score/designation/comment and homework deadline status; pending requests can be revised without withdrawing first. Attendance explanation belongs to the teacher and is separate from reviewed family justification. Initial attendance autosaves a private draft; Finish requires every student, and Mark remaining present preserves recorded absence/late statuses. An actual arrival has its own action during the active occurrence. Submitted records remain official until an independent decision. Published comments and validated logbooks use Request correction; editable drafts use Save. Incident facts/participants remain editable by their author until staff takeover or a formal decision; follow-ups append without approval.

Personal inboxes load all pages with their existing recipient and school scope before sorting newest first, so review notifications remain visible beyond the default entity page. Profile switches and sign-out continue to discard late responses.

## Conversation messaging

`MessagingInbox`, `ConversationPage` and route-scoped `ConversationController` share guardian/teacher conversation presentation and transactional command interactions. `ConversationNotificationNavigation` retains an in-memory pending push destination and selects its authorized school/profile before opening. Current message previews are merged with announcements; conversation delivery alerts never create duplicate rows. Draft text and retry identities remain scoped to account/profile, recipient and thread. Failed sends preserve drafts; conflicts show fresh activity before an explicit retry. French and English labels, busy/error/empty states, large text, keyboard-safe scrolling and localized semantics are required.

## Teacher signature profile extension

`AccountProfilePage.profileActions` is an optional presentation slot for app-owned profile actions. Teacher Profile uses it to open the local `TeacherSignaturePage`; guardian Profile has no signature action. `TeacherSignatureController` follows the route-scoped Levit lifecycle. The signature editor uses the existing buttons, dialogs, busy indicators, EDAYA tokens and localization, with a white paper preview for dark signature ink. It stays in `apps/teacher/lib/features/signature` because no other product uses this flow.

### Conversation message bubbles

`ConversationMessageBubble` is shared by Guardian and Teacher. `isOutgoingConversationMessage` matches both `authorKind` and `authorId` to the active profile; names never determine direction. Sent messages align right using `primaryContainer/onPrimaryContainer`, received left using `surface/onSurface`, with token surface radii and spacing. Keep authors (including the school staff prefix), selectable multiline bodies and smaller dates at the bottom. Dates use existing short-date/time preferences and timezone conversion. Localized semantic descriptions identify sent/received, author and timestamp without suggesting delivery/read receipts.

Limit width to 90% below 600 logical pixels of available space, 75% above, capped at 560. At 200% text scale allow all available width up to the cap. Wrap long words/URLs, retain complete 10,000-character messages and chronological reading order. Composer, paging, polling, drafts and command behavior are unchanged. `conversation_message_bubble_test.dart` is the current screenshot fixture for both profiles, FR/EN, light/dark, compact/wide and 200% text; set `EDAYA_MESSAGE_CAPTURES` to save PNGs when running it.


## Grading policy readers

`GradingPolicyView` and `gradingAverage` own shared numeric/mention display rules. Use full-precision calculated values with existing coefficients; round or truncate only the displayed result. Never normalize mention points into percentages. Suppress provisional averages when the policy is updating or input revisions differ. Legacy numeric records retain existing normalization.

Teacher entry and corrections select stable mention IDs for mention-first policies and include the displayed grading revision in commands and offline payloads. Numeric editors retain the original decimal input. Guardian report views use captured published grading metadata and do not display revised drafts. No mobile scale editor is introduced.

Continuous grading policies match the greatest minimum threshold at or below the rounded value; the final interval includes the scale maximum. Empty scales, non-finite values and values outside the scale return no mention. Legacy captured scales continue to use closed upper bounds and preserve gaps. The server supplies derived upper bounds for older readers; policy/report snapshots remain immutable when the reusable catalog changes.

School profile selection displays the server-provided persisted short name. Changing the full school name must not change this label; older responses without a short name retain the full-name fallback.

The shared account profile editor permits an empty first name for guardian profiles with a nonblank last name. Teacher/staff name requirements remain unchanged. Saving contact changes must preserve a guardian’s single-token name.

## Subject participation

Guardian consumers resolve subject participation for the selected child. Shared family scopes may include siblings with different optional choices: never infer child participation from a class-wide list. Use the student timetable endpoint across historical placements and the shared `StudentSubjectParticipation` Annual/period selection helper for curriculum, homework and progress. Teacher attendance and marks use authoritative backend rosters and retain existing offline revision conflicts. Enrollment management is staff-web-only.

Selected-child subject consumers must discard stale asynchronous responses after a child, class, year or timetable range change, and on controller disposal. Timetable, curriculum and lesson-detail controllers clear the previous child’s subject data while loading the new context.

Current eligibility excludes soft-deleted selections and honors each period's activation and calendar bounds. Guardian lesson details use the child-specific timetable to retain saved historical access without leaking a sibling's subjects. Marks and report readers retain saved results independently of current selection. Teacher sheets include retained marks and attendance draft entries; stale offline versions must refresh before retry. No mobile enrollment management or restoration controls are introduced.

## Authentication terms

Both teacher and guardian login screens use `TermsAcceptance` inside `PasswordlessLoginForm`. `LoginController` owns route-local loading, retry and checkbox state; `TermsAcceptance` owns the transient terms dialog. The document comes from the identity terms endpoint in the active FR/EN locale. When enforcement is enabled, an unchecked checkbox and handler validation block sending the code until accepted; opening the terms dialog is optional. Its bottom Accept action closes the dialog and checks the box without sending a code. Close, Back and outside dismissal preserve the prior checkbox value. Acceptance applies only to the displayed document and login identity. Loading failures block fresh sign-ins with a localized retry action. The dialog scrolls independently of the unchanged login form, keeps its bottom actions reachable, and preserves 48dp targets, theme colors and large text.

Changing the identifier, restarting authentication or changing the document/locale clears acceptance. OTP retries, SMS fallback, MFA and recovery retain the server-pinned document; only completed authentication saves one durable receipt per account/version. Existing sessions and authenticated linking/enrollment do not acquire new acceptance. Draft previews are labeled and unavailable in production.

## Guardian profile contacts

The shared account profile form exposes the main phone, alternative phone and email with independent email, SMS and push switches for guardians. Guardian identity names remain read-only. SMS uses only the main phone; email uses only the saved address; in-app messages remain available. Saving a contact preserves every unedited preference and never updates login identifiers. The shared profile controller preserves failed drafts, guards dirty dismissal and ignores responses after profile/school changes or disposal.

### Flat report modules

Guardian report sections render published snapshot names, module weighting mode/effective weight, subject coefficients and captured grades. Modules have only subject children; ungrouped subjects remain root rows. Categories do not define result grouping. Teacher comment controls keep subject/homeroom permissions and stable `module:` / `subject:` identities. Local comment drafts carry format version 2 and the base report version; a changed report requires refresh before restoration. No template selector or mobile module administration is provided.

## Teacher v2 component variants

The copy uses app-local `WorkspaceShell` for full-page destinations, `WorkspaceSheet` and `RecordSheetPage` for routed bottom sheets, and `ClassSections` for the selected class. These reuse Flutter Material with the existing EDAYA theme. `MarksCorrectionsPanel` in the copy keeps revision editing in the current sheet and displays active proposals with official marks. `NewRecordForm` preserves composed text on failed sends and retains the incident ID and successful pupil associations on partial failure. Home’s role-dependent tiles use the same size within each viewport and grow with text scaling. Teaching tiles appear under Enseignement and class activities under Vie en classe. WorkspaceShell displays a 68 dp profile button with the same account portrait in every school. The teacher profile and contact sheet use the same image. For accounts with only school portraits, use the first available portrait in stable school ID and actor ID order, and request the attachment with its owning teacher grant. Show the account icon when no portrait is available. Teacher_v2 login places the staff web language control at the top right with EN/FR, flags and the selected-language checkmark. Selection uses the app-wide language preference. Message and incident forms filter their authorized pupil choices by name and keep selected pupils visible.

Teacher v2's `SurfaceCard` wraps its tappable content in an internal InkWell with button semantics, preserving focus, hover and press feedback on the actual surface. Home tiles use this component instead of outlined buttons. Selected-class surfaces and daily-work cards share its existing fill, radius and shadow. The `ClassContextPicker` has school headings and selectable class–subject leaves, including titulaire badges. It exposes only authorized teacher assignments and displays the automatically resolved published year as text, with loading/error feedback while switching. A class-only titulaire leaf exists only without a subject assignment. `TeacherGradebookPage` combines period/result selectors, an accessible creation action, server-calculated pupil averages and a fixed save/submission panel for draft evaluations only. The average sheet changes content to the existing subject-comment editor; Bulletins uses the general-comment editor.

Teacher v2 opts into `CalendarWeekStrip.daySpacing = 4` and both week callbacks. Its Agenda is the current example of this variant; the shared calendar accessibility fixture covers the spaced strip in light/dark themes and enlarged text.

Teacher v2 Agenda places completion reminders on a wrapping text line below the session time, leaving the trailing chevron unobstructed when the full localized logbook name is displayed.

Teacher v2 uses a 1168 dp page limit and aligns the labeled Home profile action with the assignment card. `WorkspaceColumns` keeps the same field elements across width changes. Sections wrap below 840 dp of available content width or with enlarged text, and each side retains at least 320 dp. `ResponsiveRosterTile` and `ComparisonRow` align record fields at medium widths. Attendance keeps one scrollable roster with its controls beside it when space permits. Regular record sheets are capped at 640 dp, with up to 960 dp for reports, summaries, communication forms, incidents and lesson work.

Teacher v2 uses one roll-call roster and pupil-photo view for daily and lesson attendance. The list is the only submission surface. Session details use full-page attendance and logbook tabs, with the logbook editor in a single routed sheet.

The teacher v2 attendance roster and pupil-details sheet share an animated choice-chip picker. Présent, Absent and Retard use green, red and orange selected fills, a checkmark and a visible label. Unmarked roster rows leave both chips unselected without a status subtitle or reserved blank line beneath the pupil’s name. Roster chips show each tap immediately and save changes in order. Keep other pupil controls active and hold their row positions while a draft saves; a rejected change restores the affected pupil’s previous value. Detail chips commit with their form. Show the compact marked/total count above one right-aligned, wrapping action row: Photo mode / Mode photo, Rest present / Restants présents, and the primary Finish / Terminer. Keep all three actions grouped below the count. On wide landscape tablets these controls occupy the left panel. Show a retry notice when synchronization needs attention.

Teacher v2's `GradebookMarksView` renders stable inline `DraftMarkRow` inputs with explicit batch saving and one footer. Its assessment-scoped `LiveMarksController` keeps raw local entries separate from confirmed or queued results. Save-before-leave guards cover selectors, context switching, route exit and browser-history changes to the assessment query. `PupilMarkCorrectionSheet` replaces the class-wide correction form in the gradebook; official values stay visible and only the selected pupil is changed. Named request IDs and revisions preserve retry safety. Shared mark outbox entries accept either legacy single-result payloads or batch `results` payloads; both teacher apps can restore them.

Draft and submitted evaluation rows share the same full-width card, name/result/action columns and responsive wrapping. Submitted results use a plain text label and the same three-dot menu as draft rows, with the individual edit action inside the menu; pending proposals remain beside their result. Show the official-state heading once above the roster and omit routine missing-entry subtitles beneath pupil names. Validation errors and synchronization notices remain visible when needed.

## Guardian v2 workspace components

`apps/guardian` follows [Guardian v2 workspace](guardian-v2-workspace-spec.md). `WorkspaceShell` owns page chrome; `ChildContextCard` and `ChildPicker` provide the selected child. `ChildWorkspace` owns captured request headers and child-specific page lifetimes. `ArchiveWorkspace` owns a local academic year for Results, Attendance and Fees. `GuardianSheetPage` provides routed Close sheets. `SurfaceCard` supplies a clipped Material/InkWell target with semantic theme colors. Period modules and expandable marks reuse `ExpansionTile`; published values use the shared grading formatter. The original Guardian shell primitives retain their original app scope.

Guardian v2's Home watch runs inside its layout builder and subscribes to menu highlights before deferred grid builds. Session, logbook and charge detail bodies retain their record headings when `PrototypeDetailScaffold` delegates chrome to the workspace. Routed sheet titles identify the destination; message-sheet dismissal refreshes the owning inbox.
