# EDAYA mobile component registry — 1.0.0

Normative for the current Guardian and Teacher apps. Extend these components before adding new shared UI. Controllers, calculations, routing and callback conditions remain unchanged by visual work.

| Component | Source | Reuse contract |
|---|---|---|
| AppTheme / EdayaColors / EdayaTypography | shared `lib/src/app/` | Existing light/dark/system entry points; generated tokens and bundled fonts |
| EdayaBrandLogo | shared `lib/src/ui/` | Supplied color/white horizontal, vertical, symbol artwork; minimum size and clear space |
| ResponsiveMetrics | shared `lib/src/ui/` | Wrap existing metric values by width/text scale; never compute domain totals |
| PersonAvatar | shared `lib/src/ui/` | Preserve names/initials/photo fallback and operational identity |
| Profile photo crop/upload | shared `lib/src/features/profile_photo/` | Camera/gallery fallback, rotate/export JPEG ≤ 1 MiB, named portrait commands |
| DataState | shared `lib/src/common/widgets/` | Existing ready/loading/empty/error signals and retry callback |
| AccountSheetBody / AccountProfileHeader | shared common/account widgets | Existing account/profile actions and semantics |
| ModalBottomSheetPage | shared `lib/src/common/models/` | Existing modal navigation, safe area and dismissal behavior |
| LoginPage | shared `lib/src/features/auth/` | Email OTP only (email → code); logo and form hierarchy; existing session callbacks |
| GuardianAppBar / TeacherAppBar | app `design/components/` (`PrototypeAppBar`) | Student/class/year context before decoration; current actions retained |
| SessionTile / TeacherSessionTile | app calendar widgets | Current title, subject, class, kind and time; same detail navigation |
| FeesSummaryCard / GradeSummaryCards | Guardian feature widgets | All totals and labels retained; responsive numeric presentation |
| InboxDeliveryTile | Guardian inbox widgets | Unread status, date, title and body with existing message route |
| AttendanceRowTile | Teacher session widgets | Neutral identity, semantic status label, same edit/record callback |
| MarkRowTile | Teacher evaluations widgets | Existing score and locked condition; edit disabled under the same rule |

Icon-only actions need localized semantic labels. Existing sheet and dialog close buttons use `MaterialLocalizations.of(context).closeButtonTooltip`; actions with another meaning, such as removing an item, retain their own specific label. Do not change callbacks or dismissal results to add a label.

Cover approved variants and default/selected/disabled/busy/error/empty states in current galleries. Add shared presentation only for demonstrated reuse; single-feature needs stay local. Record visual exceptions with rationale, affected components, owner, lifetime, alternatives and responsive/contrast evidence. Changes update tokens, specification, registry and current captures together.

## Marks correction surfaces

Submitted marks remain read-only in the teacher grading list. MarksCorrectionsPanel shows official versus proposed values and terminal review reasons, and opens a scoped batch proposal dialog. Published source marks cannot be selected. Correction requests and withdrawal run online only; author identity and scope are enforced by the backend. Draft outbox conflicts remain visible and must not replace submitted official values on screen.
