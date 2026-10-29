# Plan — App UX Consolidation

**Depends on:** `spec.md` approved by owner.
**Delivery model:** Strangler Fig increments; every step leaves the app
deployable. Per AGENTS.md: no payroll/attendance behavior changes, and stop
points are explicit. Arabic-only app (owner decision 2026-10-29) — no
language switcher or i18n scaffolding anywhere in this plan.

## Phase 0 — Inventory & baselines (hard gate)

1. Run the verification greps and record exact counts of
   `CircularProgressIndicator` / `LinearProgressIndicator` / ad-hoc
   `SkeletonList(height: ...)` per file into
   `reports/loading_adoption_inventory.md`, extended with error-surface,
   pull-to-refresh, accessibility (icon-action labeling), and
   component-adoption columns per screen.
2. Walk navigation config vs the six-domain IA; write
   `reports/grouping_leftovers.md`.
3. Fix the search scope list with the owner: which entity surfaces are
   searchable in v1 (requests, employees, tasks, notifications, conversations
   proposed).
4. Extend the guard tests (`test/design_system/` and the guard suite) with:
   (a) spinner-allowlist guard, (b) hand-tuned-skeleton-height guard,
   (c) silent-catch guard, (d) icon-action labeling guard, (e) closed
   i18n guard (no localization packages) — all failing on the current
   baseline as characterization. Baseline numbers must match the inventory.
   This is the proof the guards work before any migration starts.

**Gate:** inventory + leftovers + search scope reviewed by owner; guards
switched on.

## Phase 1 — Loading system core (build beside legacy)

1. FR-L1: add shape-accurate skeleton patterns in
   `lib/design_system/components/skeletons.dart` + height-parity widget tests
   (mobile + 1024 desktop widths). Presentation-safe; no data imports.
2. FR-L2: codify the stale-while-refresh contract as documented behavior on
   the existing Cubit patterns used by migrated screens; add a reusable
   mixin/widget contract and a session-level test that a refresh of loaded
   data inserts no skeleton frame.
3. Finish `_LazyRequestTab`'s keep-mounted behavior into the shared contract
   (move out of `requests_mgmt` into `lib/design_system/components/` or
   `lib/core/` after two consumers exist — per AGENTS.md core rule).

Verification: `flutter analyze`, design-system tests, guards green.

## Phase 2 — Requests Hub (feature slice, beside legacy)

1. Scaffold `lib/features/request_workspace/` domain + data wired to
   `request_visibility` and existing pending/approval services. No behavior
   change; document read budget (FR-R4).
2. Presentation cubits (each < 300 lines): queue, browse, detail.
3. Pages/widgets: hub three views; shared detail page with timeline +
   `ConfirmationSheet`; `DsMasterDetailView` layout on desktop >= 980.
4. Router redirects from legacy requests paths (FR-R3). Route parity test
   extended first (red), then redirects (green).
5. Parity walk per legacy tab: for each of the 18 tabs, enumerate states and
   confirm the hub covers them or file follow-ups. Record in phase report.

**Gate (owner):** hub parity before any retirement planning.

## Phase 3 — Screen sweep: states, feedback, consistency, labels

Migrate one screen per increment, top HR/manager/super-admin surfaces first:
requests family → attendance family → people → performance → payroll →
workspace → auth-adjacent (matching `05_rollout_migration_spec.md` order).
Each increment bundles, and only bundles, these byproduct obligations:

- swap loading UI to named skeleton patterns or `EmptyState`/`ErrorState`,
- apply stale-while-refresh where a Cubit exists or is extracted (focused
  Cubit when the screen's state is extracted; size rule respected),
- surface every catch per FR-S2 (ErrorState/inline/toast; guard stays green),
- add `RefreshIndicator` per FR-S3 where the surface is a Cubit-loaded list,
- promote raw buttons/inputs/cards to `Wolf*` components, replace hardcoded
  colors with token aliases (FR-C, nothing else changes),
- label icon-only actions per FR-A1 (tooltip or `Semantics`).

Verify per increment: RTL + desktop-1024/1440 + states recorded in the
increment log (following `r8_migration_increments_log.md` habit). Legacy
loading code stays until the last importer per pattern is gone.

## Phase 4 — Global search (WS4 core)

1. Scaffold `lib/features/app_search/` (domain/data/presentation) against the
   owner-approved scope list from Phase 0 — existing bounded services only,
   fallback queries ≤10/entity; no new listeners.
2. `AppSearchDelegate` (RTL, Arabic-first copy) + entry points: mobile role
   app bars and web top bar search entry; results deep-link via existing
   routes; recent chips session-only.
3. Read-budget note in `reports/` like FR-R4; route parity unchanged
   (search navigates to existing paths).
4. Widget tests: empty query, Arabic query normalization, deep-link tap into
   hub detail and employee detail paths; guard: no localization imports.

**Gate (owner):** search scope coverage confirmed or reduced in the phase
report before any further entity is added.

## Phase 5 — Accessibility floor closeout

1. Sweep completes icon-action labeling app-wide (guard green with recorded
   allowlist; wherever the sweep touched screens in Phase 3 this is nearly
   done — this phase closes the rest).
2. Manual screen-reader (Arabic) walkthrough of the hub + the top-10 visited
   screens recorded with findings; blockers become follow-ups rather than
   silent gaps.

## Phase 6 — Retirement & closeout (separate reviewed changes)

1. Delete duplicated history surfaces and legacy loading wrappers only after
   zero importers (grep-proven), one cleanup change, with route parity.
2. Dormant `requests_mgmt.dart` retired per the release-cycle + owner sign-off
   rule from `05_rollout_migration_spec.md`.
3. Final program checks per spec acceptance list; write summary report into
   `reports/` citing evidence per criterion (no uncited "done").

## Infra/integration rules inherited

- No new Firestore listeners anywhere (hub and search included); reads are
  bounded queries with documented budgets.
- All state ownership per Cubit-responsibility rule; presentations import
  domain contracts only.
- Arabic-only: no localization packages, ever, in this program (guard
  enforced); Arabic RTL verified per increment, not at the end.

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Hub diverges from monolith behaviors across 18 tabs | Parity walk per tab in Phase 2; uncovered tabs stay on legacy |
| Skeleton patterns drift from real layouts | Height-parity tests enforce; pattern per named layout only |
| Migration sweep re-flashes on legacy setState screens | Contract test in Phase 1 catches before sweep; setState screens migrated to focused Cubits first |
| Consistency byproducts turn sweep increments into rewrites | FR-C is swap-only; guard tests pin the change footprint |
| Search queries explode read cost | No new listeners; ≤10/entity fallback; read budget reviewed at gate |
| Scope creep into business behavior | Non-goals in spec; stop-and-record rule on any behavior surprise |
| Silent catches hide failures during migration | Silent-catch guard (Phase 0) blocks regressions from day one |
