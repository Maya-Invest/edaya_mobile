# EDAYA mobile component registry — 1.0.0

Normative for the current Guardian and Teacher apps. Extend these components before adding new shared UI. Controllers, calculations, routing and callback conditions remain unchanged by visual work.

| Component | Source | Reuse contract |
|---|---|---|
| AppTheme / EdayaColors / EdayaTypography | shared `lib/src/app/` | Existing light/dark/system entry points; generated tokens and bundled fonts |
| EdayaBrandLogo | shared `lib/src/ui/` | Supplied color/white horizontal, vertical, symbol artwork; minimum size and clear space; artwork width remains bounded in stretched layouts |
| CalendarWeekStrip | shared `lib/src/ui/` | Theme-aware day buttons, 48dp targets, full-date labels and selected semantics; scrolling at large text; preserves caller selection and week callbacks |
| ResponsiveMetrics | shared `lib/src/ui/` | Wrap existing metric values by width/text scale; never compute domain totals |
| PersonAvatar | shared `lib/src/ui/` | Preserve names/initials/photo fallback and operational identity; both app wrappers use the shared authenticated download-grant loader, including pending student portraits. Rewrite local storage hosts for emulators; authenticate same-origin memory storage and never forward API credentials to external storage |
| Profile photo crop/upload | shared `lib/src/features/profile_photo/` | Camera/gallery fallback, rotate/export JPEG ≤ 1 MiB, named portrait commands |
| DataState | shared `lib/src/common/widgets/` | Existing ready/loading/empty/error signals and retry callback |
| AccountSheetBody / AccountProfileHeader | shared common/account widgets | Existing account/profile actions and semantics |
| ModalBottomSheetPage | shared `lib/src/common/models/` | Existing modal navigation, safe area and dismissal behavior |
| LoginPage | shared `lib/src/features/auth/` | Shared `PasswordlessLoginForm`: One contact field with automatic email/international-phone detection, WhatsApp first and explicit SMS fallback, TOTP and recovery; branded logo and existing session callbacks |
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

## Integration coverage maintenance

Feature changes must update their registered action scenarios and executable assertions in the same PR. Shared authentication components are exercised through their production forms and captured local delivery transport. Route inventory, action registration and successful execution are all required; reviewers verify that assertions establish the intended behavior. See [integration testing](../reference/integration-testing.md).

`OtpDeliveryControls` and `OtpDeliveryState` share server countdown, delivery guidance and explicit resend/SMS/retry actions between login and contact linking. The owning controller closes the timer and reactives with its route. Poll only on the visible active verification screen; clear the code text controller after each replacement.

`OtpDeliveryControls` also shares the explicitly enabled testing panel for login and contact linking. `TEST_OTP_ACCESS=true` requires a debug build and server capability discovery; staging alone enables nothing. **Show test code** reveals a transient challenge-bound capture; **Copy** writes it to the clipboard without filling or submitting the input. `OtpDeliveryState` clears it on replacement, expiry, completion, reset, departure, backgrounding and closure, and discards stale lookups. No OTP enters session storage, telemetry or test artifacts. Both French and English labels are required.

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
