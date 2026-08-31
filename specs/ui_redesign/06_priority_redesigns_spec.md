# Phase 5 — Priority Redesigns: Home, Requests, Notifications, Full RTL, Branding

**Status:** Draft for owner review.
**Depends on:** Phase 0 components; integrates with Phase 1 navigation and
Phase 2 dashboards.

## R1 — Home screen redesign (employee-facing "home")

Goal: one glance answers "what is my status today and what needs me".

Anatomy (mobile and web share structure):

1. Header: greeting + date + avatar; company logo per R5 rules.
2. My-status card: today's check-in/out state, work window, location — single
   prominent card, largest tap target on the screen.
3. PriorityStrip (from Phase 2): my pending requests, tasks due today.
4. Quick actions grid: exactly 4 items max (check-in context, new request,
   tasks, payroll) using `WolfCard` recipe.
5. Recent activity: last 5 relevant events (approvals results, announcements)
   via `SectionHeader` + list.

Rules:

- Nothing above quick actions requires horizontal scrolling except the
  metrics/strip row if used.
- All counts come from existing providers/cubits; gaps are recorded, not
  silently added.

## R2 — Requests page redesign

Applies to `employee_requests` and role-scoped request management screens
(`requests_mgmt`) with shared building blocks.

- Top: `FilterBar` chips (status: all/pending/approved/rejected; type;
  date range). Selected chip = filled accent pill.
- New-request entry point pinned: floating action button on mobile, primary
  button in toolbar on web. One tap to the most-used request type, long list
  of types in a bottom sheet / dropdown.
- List rows: type icon, Arabic title, date, amount/hours when applicable,
  `StatusPill`. Tap opens detail with approval timeline (`request_approval_
  timeline` component reused).
- Detail actions (approve/reject/cancel) use `ConfirmationSheet`; buttons
  disable during submission; success returns to the same filtered list
  position.
- Empty state explains where requests go after submission; pending-sync rows
  show `StatusPill` consistent with sync feature behavior.
- Web >=980: table presentation via `AppDataTable` with row tap opening a
  side detail panel instead of full-page navigation.

## R3 — Notification center redesign

Applies to `notifications_screen.dart`.

- Grouped by day (today / yesterday / earlier) with sticky date captions.
- Row anatomy: unread dot, category icon (approval result, announcement,
  task, system), title, body preview, relative timestamp.
- Unread state visually distinct but not color-only (dot + weight).
- Interactions: tap → deep-link to related entity (existing routes only);
  swipe-to-mark-read on mobile; hover action on web; "mark all read" in
  header with confirmation-free idempotent action.
- Filter chips: all / unread / category.
- Pagination must remain bounded (page size + load-more); no unbounded
  listeners; read-budget implications checked per AGENTS.md scheduled/integra
  tion rules.
- Badge count source unchanged; center redesign is presentation only unless
  an addendum specifies read-state model changes.

## R4 — Full RTL and Arabic-first support

The app and web dashboard are Arabic-first; RTL is the default layout, not a
mirrored afterthought.

Requirements:

- `Directionality` explicitly set app-wide from locale; every custom
  `Row`/`Padding`-based nav and card audited so start/end edges flip
  correctly (no hardcoded `left/right` EdgeInsets or Alignment).
- Icons with direction meaning must flip: back arrows (`arrow_forward`
  becomes the back affordance in RTL), chevrons, list trailing arrows,
  timeline connectors. Use logical icons (`Icons.arrow_back_ios_new` handled
  via Directionality-aware wrappers or `matchTextDirection: true`).
- Progress/timeline/radar widgets audited for mirrored drawing.
- Numerals, phone numbers, amounts render LTR inside RTL text using proper
  bidi isolation (no mixed-direction glitches like "EGP ١٢٣").
- All remaining English-only strings get Arabic; language toggle (if any)
  keeps Arabic as default.
- Fonts: IBM Plex Sans Arabic everywhere including numbers contexts chosen
  deliberately.

Acceptance additions for this requirement:

- [ ] Dedicated RTL audit checklist run over: nav shells, home, requests,
      notifications, attendance details, payroll, workspace editor.
- [ ] Screenshot pass at mobile width and desktop-web width documented.

## R5 — Branding: unified logo

- The approved logo is the cyan-gradient geometric wolf head supplied by the
  owner (black background version). It is added once as
  `assets/images/wolf_logo_gradient.png` (+ `.webp` variant) and referenced
  through a single `AppLogo` widget (`lib/design_system/components/`) with
  size variants (nav 24–28px, header 32–40px, login large).
- Replace all current usages of `assets/images/wolf_head_geometric.png`
  **except** `splash_screen.dart`, which keeps its existing artwork untouched.
  Known usages to replace: `navigation_wrapper.dart:1088`, `login_screen.dart:
  183`, `hr_dashboard.dart:237`, `placeholder_screens.dart:57`,
  `employee_dashboard.dart:473`, `profile_settings.dart:422`.
- Web: favicon and any web-shell header mark switch to the new asset.
- Splash remains byte-for-byte unchanged in this program.
- Old asset file removal happens only in the Phase 4 retirement step after no
  importer remains outside splash.

## Acceptance criteria (phase level)

- [ ] Home, Requests, Notifications redesigned per anatomies above on mobile
      and web widths.
- [ ] Full RTL audit passed (R4 checklist) with icon/direction fixes verified.
- [ ] Single `AppLogo` widget used everywhere outside splash; old asset has
      zero importers outside `splash_screen.dart`.
- [ ] Notification pagination bounded; read-budget impact noted.
- [ ] Required checks pass.
