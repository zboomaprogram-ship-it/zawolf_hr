# App UX Consolidation — Loading System v2, Requests Hub, Search & Surfaces, Grouping, Accessibility

**Status:** Draft v2 — awaiting owner review before any implementation.
**Delivery model:** Strangler Fig (AGENTS.md). Nothing is deleted in this
change; legacy screens stay reachable until parity is proven and a separate
reviewed cleanup retires them.
**Owner decisions recorded here:**
- App remains **Arabic-only** (decision 2026-10-29). No language switcher and
  no localization scaffolding; nav items that already carry English labels may
  keep them, nothing new is added.
- Loading/flash work builds on `specs/ui_redesign/` (completed phases) instead
  of duplicating it.

## Problem & Audit Findings (2026-10-29 Review)

Yes — several real problems. Here's everything I found, grouped:

### In the 020 remote-work specs (the initial review)

1. **Contradicting completion documents.** `FULL_WORK_REPORT.md` claims all 22 acceptance criteria pass and "100% pilot-ready," while `execution-status.md` says work is unfinished and nothing is fully complete. Both can't be true.
2. **Fabricated evidence.** `acceptance-evidence.md` cites test files (`remote-work-day-mode.test.js`) that don't exist, and a `daily-tasks.js` change that never happened.
3. **Real server-side gaps.** Client-controlled attendance dates (backdating possible), missing eligibility checks in the transaction, no policy snapshots in sessions, hardcoded limits, and a company-scoping hole in `financial-holds.js` — cross-company access possible.
4. **Not everything claimed was done**, though the checks themselves did pass — the Flutter/UI task list had legitimate failures elsewhere.

### In the wider app (the UX audit)

5. **Founded-but-unadopted design system.** Only 26 of 83 screens use the skeleton system — 140 still use spinners. `StatusPill` physically exists but was adopted on 6 screens.
   - `SkeletonList(itemCount: n, itemHeight: h)` is a generic block with guessed dimensions; when real content swaps in, layout shifts — the "flash" felt across dashboards, attendance/employee cards, and analysis cards.
   - Legacy screens hold loading state inside full-screen `setState` scopes, so unrelated rebuilds and tab switches re-trigger loading for data that was just displayed.
6. **Error swallowing.** 77 files catch exceptions; only 8 show `ErrorState`. This is the main reason things "feel broken" with no explanation. Failures appear as generic SnackBars, blank regions, or nothing.
7. **No global search in an 83-screen ERP system.** Search exists ad-hoc in 8 screens only (requests mgmt, employee mgmt, KPI, chats…). The navigation shell has no search handler. In an 83-surface ERP, search IS navigation.
8. **Accessibility nearly absent.** 16 `Semantics` usages vs. 226 unlabeled icon buttons (`IconButton` sites with tooltips in only 72 files).
9. **Monolith screens.** 10,224-line `requests_mgmt.dart` and 5,826-line `employee_requests.dart` concentrate the duplication. Up to 18 conditional tabs, with HR/manager/super-admin branch logic inside the same file; request history duplicated 4 times.
10. **Component drift & weak interaction standards.** 78 files still use raw `ElevatedButton / TextButton` instead of `WolfButton`; raw inputs 63 vs 15; raw `Card` 100 vs 55; 152 hardcoded `Color(0x…)` sites outside token/theme files. Pull-to-refresh present in only 21 of 83 screens.

### In the spec I wrote

11. **Fixed mid-writing:** duplicate phase numbering between `plan.md` and `tasks.md`, phase-by-phase exit-gate criteria, noexit-cleanly errors, and the leftover `C125 retirement` reference that used old IDs after renumbering. Those are corrected.

> **Net:** Nothing here is a blocker to approving the new spec — problems 1–10 are exactly what the spec and its guard tests are designed to fix incrementally. The one you should decide on before Phase 0 is the scope list for what's searchable (requests/employees/tasks/notifications/conversations) in the first search release.

## Goals

- One loading/state system, adopted everywhere, that does not flash.
- One Requests Hub for HR / manager / super admin replacing the 18-tab
  monolith, with ONE request history.
- One global search across core entities; per-surface search is absorbed into
  it or kept as a surface-local filter.
- Every failure is visible and recoverable; every list is refreshable.
- Labeled, focusable icon actions app-wide (accessibility floor).
- Verify and complete the six-domain grouping rollout; document leftovers.

## Non-goals

- No business-logic change: payroll cycle, attendance behavior, permission
  accounting, approval semantics, and Firestore rules behavior are untouched.
- No route removal. Old paths keep resolving; removal is a separate reviewed
  change after a release cycle.
- No new Firestore collections. The hub reads through the existing
  `request_visibility` domain layer plus the services it already wraps.
- No light mode, no brand change.
- **No language switcher, no i18n/l10n scaffolding — Arabic-only app**
  (owner decision 2026-10-29). A guard ensures no localization package is
  introduced and English surfaces are not added.

---

## Workstream 1 — Loading System v2

### FR-L1 Shape-accurate skeletons

Extend `lib/design_system/components/skeletons.dart` with layout-mirroring
patterns: `SkeletonEmployeeRow`, `SkeletonStatCard`, `SkeletonInsightCard`,
`SkeletonAttendanceRow` (row + status pill + ring), `SkeletonTableRows`
(web >=980), `SkeletonDetailPane`. Each pattern's intrinsic height matches the
real widget it stands in for (widget test asserts equal height for the
skeleton and the real pattern at mobile and desktop widths). Motion stays:
opacity pulse via `DsMotion`, static under `MediaQuery.disableAnimationsOf`.

### FR-L2 Stale-while-refresh (no-reflash contract)

- A Cubit/widget holding previously loaded data never shows a skeleton on
  refresh: it keeps rendering stale content and marks data as refreshing
  (subtle indicator allowed).
- Skeletons appear only on first load per screen session.
- Tab/list switches keep mounted state and scroll position (finish the
  `_LazyRequestTab` pattern into the shared contract).
- Full-screen setState screens migrating under this workstream move their
  loading state into the shared contract or a focused Cubit.

### FR-L3 Spinner eradication

- `CircularProgressIndicator`/`LinearProgressIndicator` are allowed only as
  inline button-loading indicators (`WolfButton.loading`) and page-level
  blocking actions with no layout to preserve.
- Everything else uses the state contract from
  `specs/ui_redesign/04_screen_states_polish_spec.md`.
- A repo guard test (extends the existing guard suite) fails the build when a
  spinner appears outside the allowlist, and when `SkeletonList` is called
  with hand-tuned `itemHeight` values instead of a named pattern.
- Migration follows the phase-4 order in `05_rollout_migration_spec.md`
  (requests → attendance → people → performance → payroll → workspace),
  one screen per deployable increment, parity per screen.

### FR-L4 Adoption inventory

Before migration, produce `reports/loading_adoption_inventory.md`: every file
with a spinner, its screen, role reach (HR/manager/super-admin hit first), and
target skeleton pattern. Extended with error-surface, accessibility, and
component-adoption columns (see WS4/WS5 inventories). This is the migration
order source of truth and the completion evidence base.

---

## Workstream 2 — Requests Hub

New feature under `lib/features/request_workspace/` per
spec-feature structure:

```
lib/features/request_workspace/
  domain/     unified request record (view/reply/aggregation, no behavior change)
  data/       implements domain over request_visibility + existing services
  presentation/
    cubits/   request_queue_cubit, request_browse_cubit, request_detail_cubit
              (each < 300 lines; one UI-state responsibility each)
    pages/    hub_page.dart, request_detail_page.dart
    widgets/  shared filter bar, timeline, action buttons
```

### FR-R1 Three views, not 18 tabs

- `طلبات عليا` — pending my action for the signed-in actor, newest first,
  grouped by urgency source (existing pending providers; no new queries).
- `كل الطلبات` — browse with `FilterBar` type chips + status filter +
  delegated-by (super admin) filter.
- `السجل` — the single history: resolved requests + search, replacing the
  four duplicated history surfaces *inside the hub*. Legacy surfaces remain
  reachable until retirement.

Role differences come from capabilities and `request_visibility` scope, not
from role-branched copies: HR, manager, super admin share one widget lineage.

### FR-R2 One detail experience

One `request_detail_page` with the shared approval timeline widget and
`ConfirmationSheet`-routed actions for every request type, desktop >=980
using `DsMasterDetailView` (already exists). Employee flows are untouched in
this workstream.

### FR-R3 Redirects

`router.dart` adds redirects from the recognized old requests-management
paths to the hub. Route parity test enumerates old and new paths; no path is
removed. The monolith stays dormant-but-reachable as a rollback path.

### FR-R4 Bounded reads

Hub queries are bounded (limit + cursor), documented read-budget note in the
feature `data` implementation comments and in `reports/` — same discipline as
`r3_notifications_read_budget.md`.

---

## Workstream 3 — Grouping verification and leftovers

- Walk the six-domain IA against the live navigation config; produce
  `reports/grouping_leftovers.md` listing any feature surface that still lives
  outside its domain or duplicates another domain's function.
- Each leftover gets one of: filed under the Requests Hub workstream, filed as
  a follow-up spec, or explicitly accepted as-is by the owner.
- No regrouping happens inside this spec beyond what the hub redirects cover.

---

## Workstream 4 — Search, error surfacing, refresh & feedback

### FR-S1 Global search

Shared search entry (mobile: search icon in each role's app bar; web: the
top-bar search entry point) opening `AppSearchDelegate` under
`lib/features/app_search/` (domain/data/presentation). Rules:

- Searches requests, employees, tasks, notifications, conversations via the
  existing bounded query services — **no new Firestore listeners**, fallback
  targeted queries limited to ≤10 per entity type; per-surface cached sets
  searched client-side first.
- Each result row is a design-system row (`AppListTile`) and deep-links to its
  detail page; recent-search chips (session-only, no persistence contracts).
- Read budget documented like FR-R4.
- Per-surface search fields remain as *filters inside their screens*; they are
  not removed, and the delegate is the single global entry.

### FR-S2 Error-surface contract

- Every `catch` reachable from presentation must produce a visible outcome:
  `ErrorState` (list/detail bodies), an inline destructive-styled message in
  the context of a form/dialog, or an error toast — never silence.
- Silent catch and `catch (e) {}`-style swallows fail an extension of the
  state guard test.
- The contract is applied to each screen during the Phase 3 sweep increments,
  not as a separate risky rewrite.

### FR-S3 Pull-to-refresh standard

Every scrollable list surface that loads through a Cubit exposes
`RefreshIndicator` wired to the Cubit's refresh action. Stream-driven lists
document their live-refresh contract instead. Coverage is enumerated per
surface in the Phase 0 inventory and verified per increment.

### FR-S4 Action feedback

Success confirmations are standardized toasts; destructive actions already
route through `ConfirmationSheet`; long operations show `WolfButton.loading`.
Asynchronous submit failures follow FR-S2.

### FR-C Consistency byproducts (absorbed by the sweep)

As each screen passes through the Phase 3 sweep it also: replaces raw
`ElevatedButton`/`TextButton`/`OutlinedButton` with `WolfButton`, raw inputs
with `WolfInputField`, raw `Card` with `WolfCard`, and replaces hardcoded
`Color(0x…)` with token aliases. Nothing else changes in that increment.
A final grep proves zero violations outside token/theme files and the design
system itself.

---

## Workstream 5 — Accessibility floor (labeled, reachable)

- FR-A1 Every icon-only action exposes a tooltip or `Semantics` label; a guard
  test fails on `IconButton`/icon-action sites lacking both (allowlist: the
  design system itself). Sweep applies labels screen by screen.
- FR-A2 Touch targets ≥ 44×44 are upheld per the existing P3 contract.
- FR-A3 Manual screen-reader walkthrough of the hub and the top-10 visited
  screens (Arabic) recorded in the final report.
- FR-A4 No localization scaffolding is added (Arabic-only, owner decision);
  a guard test fails if localization packages/imports appear.

---

## Evidence discipline (learned from the 020 review)

- No `execution-status.md` or report may claim an acceptance criterion passes
  unless it cites verifiable evidence: test name, grep count with command, or
  recorded diff. Contradicting completion documents are a review-blocking bug,
  not a formatting issue.
- `reports/` files in this spec carry status dates and must match each other;
  the oldest honest status wins.

---

## Acceptance criteria (measurable)

- [ ] `grep -rn "CircularProgressIndicator\|LinearProgressIndicator" lib/` —
      zero hits outside the allowlist recorded in the guard test.
- [ ] Skeleton/real height-parity widget tests pass for FR-L1 patterns at
      mobile and desktop-1024 widths.
- [ ] Stale-while-refresh: session test shows a refresh of already-loaded data
      inserts no skeleton frame.
- [ ] Analysis/insight cards (attendance employee card, insights, dashboards)
      show named-pattern skeletons, verified per screen in the phase report.
- [ ] Requests Hub: `flutter analyze` clean; Cubits < 300 lines; presentation
      layer imports no `data`/Firebase/Dio (architecture guard extended and
      green); Cubit line-count guard green.
- [ ] Hub covers the requests reachable from the 18 legacy tabs, or each
      uncovered one is listed in the phase report with a filed follow-up.
- [ ] Route parity test passes with hub redirects added.
- [ ] Global search: reachable from the mobile app bar and web top bar;
      delegate returns deep-linking results from bounded queries only; read
      budget documented; RTL + desktop walkthrough recorded.
- [ ] Error-surface guard green: zero silent `catch` in presentation of
      lib/screens and lib/features (allowlist: rethrow/log-only sites recorded).
- [ ] Pull-to-refresh present on every Cubit-loaded list surface enumerated in
      the inventory (grep evidence per surface).
- [ ] Accessibility guard green: zero icon-only actions without
      tooltip/Semantics outside the allowlist; screen-reader walkthrough of
      hub + top-10 screens recorded.
- [ ] Component parity: zero `Color(0x…)` outside token/theme/design-system
      files; zero raw layout-interactive buttons/fields outside the design
      system and its allowlist (grep evidence).
- [ ] Arabic-only guard green: no localization packages/imports introduced;
      no English-only new surfaces. (No language switcher exists, by decision.)
- [ ] RTL (Arabic) and desktop web (1024/1440) walkthrough recorded for the
      hub, search, and each migrated loading surface.
- [ ] Full required checks green: `flutter analyze`, `architecture_guard`,
      `firestore_query_guard`, full `flutter test`, and `scripts npm test`
      where touched.
- [ ] `reports/loading_adoption_inventory.md` and
      `reports/grouping_leftovers.md` exist and are internally consistent.

## Verification commands

```bash
grep -rn "CircularProgressIndicator\|LinearProgressIndicator" lib/ --include="*.dart"
grep -rn "SkeletonList(" lib/ --include="*.dart" | grep "itemHeight"
grep -rn "Color(0x" lib/ --include="*.dart" | grep -v "lib/design_system/\|lib/theme/"
grep -rnE "^import ('|\\\")package:intl|package:easy_localization|flutter_localizations" lib/ --include="*.dart"
flutter analyze
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test
(cd scripts && npm test)   # only if scripts touched
```

## Review gates

1. Owner review of this spec (and plan/tasks) — no implementation before it.
2. Owner review after Phase 0 inventories are produced (confirms order and
   the search scope list).
3. Owner review after the hub reaches feature parity with the legacy tabs —
   before any retirement change is planned.
