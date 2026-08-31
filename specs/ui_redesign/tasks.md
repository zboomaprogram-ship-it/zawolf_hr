# Tasks: UI Redesign Program

**Input**: Design documents from `specs/ui_redesign/`
**Prerequisites**: 00_overview.md, 01–06 phase specs (owner-approved)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelizable (different files, no dependencies)
- **[USx]**: user story label

---

## Phase 1: Setup

- [x] T001 Create `lib/design_system/` structure: `tokens.dart`, `components/`, `README.md` pointing at `specs/ui_redesign/01_design_system_spec.md`
- [x] T002 [P] Add debug-only component gallery route rendering all design-system parts in RTL + desktop widths

## Phase 2: Foundational (Blocking)

**⚠️ No user story work until complete.**

- [x] T003 Define `DsSpacing`, `DsRadius`, `DsMotion` tokens in `lib/design_system/tokens.dart`
- [x] T004 [P] Add semantic color aliases (`successSoft`, `warningSoft`, `errorSoft`, `info`, `surfaceElevated`, `disabled`, `onDisabled`) and status→color mapping helper beside `ZaWolfColors` in `lib/theme/theme.dart`
- [x] T005 Wire typography scale (display 28/h1 22/h2 18/body 15/secondary 14/caption 12) into `lib/theme/theme.dart` ThemeData
- [x] T006 Complete Material 3 colorScheme in darkTheme keeping brand palette
- [x] T007 Widget tests for tokens/theme (status mapping, text styles) in `test/design_system/`

**Checkpoint**: foundation ready.

---

## Phase 3: US1 — Design System Components (Priority: P1)

**Goal**: 15 reusable components replace per-screen duplication.
**Independent Test**: gallery route renders every component; widget tests pass.

- [x] T008 [P] [US1] Extend `WolfButton` variants primary/secondary/destructive/ghost with loading+disabled states in `lib/components/wolf_button.dart`
- [x] T009 [P] [US1] Standardize `WolfCard` recipe (radius 12, surface01, border surface03, padding 16, web hover no layout shift) in `lib/components/wolf_card.dart`
- [x] T010 [P] [US1] Add icon/error/helper slots to `WolfInputField` in `lib/components/wolf_input_field.dart`
- [x] T011 [P] [US1] Create `StatCard` in `lib/design_system/components/stat_card.dart`
- [x] T012 [P] [US1] Create `StatusPill` with status→semantic color mapping in `lib/design_system/components/status_pill.dart`
- [x] T013 [P] [US1] Create `SectionHeader(title, {actionLabel, onAction})` in `lib/design_system/components/section_header.dart`
- [x] T014 [P] [US1] Create `EmptyState` and `ErrorState({message, onRetry})` offline-aware in `lib/design_system/components/feedback_states.dart`
- [x] T015 [P] [US1] Create `SkeletonList`/`SkeletonCard` in `lib/design_system/components/skeletons.dart`
- [x] T016 [US1] Create `AppDataTable` (PlutoGrid wrapper ≥980px) + `AppListTile` pair sharing one row model in `lib/design_system/components/data_presentations.dart` (depends T011–T015)
- [x] T017 [P] [US1] Create `FilterBar(chips)` in `lib/design_system/components/filter_bar.dart`
- [x] T018 [P] [US1] Create `PriorityStrip(items)` tappable alert banner in `lib/design_system/components/priority_strip.dart`
- [x] T019 [P] [US1] Create `Avatar(name, {size, roleColor})` in `lib/design_system/components/avatar.dart`
- [x] T020 [P] [US1] Create `ConfirmationSheet` destructive-action sheet in `lib/design_system/components/confirmation_sheet.dart`
- [x] T021 [P] [US1] Create `Badge(count)` in `lib/design_system/components/badge.dart`
- [x] T022 [US1] Widget tests for StatusPill mapping, WolfButton states, Empty/Error/Skeleton in `test/design_system/`

**Checkpoint**: gallery shows all components; required checks green.

---

## Phase 4: US2 — Navigation & IA (Priority: P2)

**Goal**: six-domain grouping; web sidebar; mobile nav regrouped; zero route breakage.
**Independent Test**: route parity test passes; sidebar at 1024/1440; bottom nav <980.

- [x] T023 Extract shared role-filtered `NavigationItem` source list consumed by both shells in `lib/navigation/navigation_wrapper.dart`
- [x] T024 Build web sidebar shell (6 domain groups, collapsible, active indicator) replacing `_DesktopManagementShell` internals preserving public contract
- [x] T025 Build top bar: search entry, notifications bell with `Badge`, profile menu
- [x] T026 Regroup mobile bottom nav to role tab sets (employee/TL+manager/HR) in `lib/navigation/navigation_wrapper.dart`
- [x] T027 Redesign More sheet as grouped grid of ≤6 domain cards from `WolfCard`
- [x] T028 [P] Create six domain hub screens under `lib/screens/shared/hubs/` linking existing routes
- [x] T029 Decompose `navigation_wrapper.dart` so each file/state holder respects size rules
- [x] T030 Route parity test enumerating all router paths before/after in `test/navigation/route_parity_test.dart`
- [x] T031 Verify back behavior (`PopScope`) unchanged on mobile; RTL check of shells

---

## Phase 5: US3 — Dashboards (Priority: P3)

**Goal**: prioritized-work dashboards for all four roles.
**Independent Test**: anatomy verified mobile + web; strip hidden when empty.

- [x] T032 Integrate `PriorityStrip` data sources from existing pending providers (no new queries)
- [x] T033 Rebuild HR dashboard: header/strip/metrics(≤4)/grouped sections in `lib/screens/hr/hr_dashboard.dart`
- [x] T034 Rebuild Manager dashboard with team metrics in `lib/screens/manager/manager_dashboard.dart`
- [x] T035 Rebuild Team Leader dashboard in `lib/screens/team_leader/team_leader_dashboard.dart`
- [x] T036 Decompose employee dashboard (~1437 lines) into focused widgets + focused Cubit (<300 lines)
- [x] T037 Rebuild Employee dashboard anatomy (my-status card first) in `lib/screens/employee/employee_dashboard.dart`
- [x] T038 Widget tests: strip zero-item hidden, StatCard tap navigation, section "عرض الكل"
- [x] T039 Record any missing-count gaps in phase report instead of adding queries

---

## Phase 6: US4 — Priority Redesigns (Priority: P4)

**Goal**: Home, Requests, Notifications redesigns; full RTL audit; unified logo.
**Independent Test**: R1–R5 acceptance items pass on mobile + web.

### Home (R1)
- [x] T040 Redesign employee home: my-status card, strip, ≤4 quick actions, recent activity
### Requests (R2)
- [x] T041 Redesign `lib/screens/employee/employee_requests.dart`: FilterBar chips, pinned FAB new-request, row anatomy with StatusPill
- [x] T042 Redesign requests management screens with shared blocks; web table + side detail panel ≥980 (ConfirmationSheet everywhere; `DsMasterDetailView` on leaves, permissions, advances, confirmed-deductions, corrections, and security-reviews tabs — see reports/r6_states_polish_report.md)
- [x] T043 Wire approve/reject/cancel through `ConfirmationSheet`; disable during submit; return to filtered position
### Notifications (R3)
- [x] T044 Redesign `lib/screens/shared/notifications_screen.dart`: day groups, unread dot+weight, category icons, relative timestamps
- [x] T045 Add filter chips (all/unread/category), swipe-to-read mobile, hover action web, mark-all idempotent
- [x] T046 Verify pagination bounded; document read-budget impact per AGENTS.md
### Full RTL (R4)
- [x] T047 App-wide Directionality audit: remove hardcoded left/right EdgeInsets/Alignment in migrated surfaces
- [x] T048 Fix directional icons/arrows via Directionality-aware wrappers (`matchTextDirection`); audit timelines/radar drawing
- [x] T049 Bidi-isolate numerals/amounts/phones inside Arabic text; Arabic-first copy sweep
### Branding (R5)
- [x] T050 Create `AppLogo` widget with size variants reading `assets/images/wolf_logo_gradient.png` (+webp) in `lib/design_system/components/app_logo.dart`
- [x] T051 Replace all `wolf_head_geometric.png` usages EXCEPT `splash_screen.dart`: navigation_wrapper:1088, login_screen:183, hr_dashboard:237, placeholder_screens:57, employee_dashboard:473, profile_settings:422; update web favicon/shell mark

**Checkpoint**: RTL screenshot pass documented; logo single-sourced outside splash.

---

## Phase 7: US5 — States & Polish (Priority: P5)

**Goal**: five-state contract uniform on migrated surfaces.
**Independent Test**: airplane-mode pass; per-screen state checklist recorded.

- [x] T052 Apply loading skeleton / EmptyState / ErrorState contract to all screens migrated in Phases 4–6
- [x] T053 Pending-sync `StatusPill` rows aligned with sync feature behavior; no silent loss
- [x] T054 Reduced-motion respect; focus-visible rings web-wide; hover without layout shift
- [ ] T055 Offline airplane-mode verification pass on mobile build; record results

---

## Phase 8: US6 — Rollout & Retirement (Priority: P6)

- [ ] T056 Migrate remaining screens in order: requests → attendance → people → performance → payroll/reports → workspace → auth-adjacent (one screen per increment, parity protocol per `specs/ui_redesign/05_rollout_migration_spec.md`) - [x] T056 Migrate remaining screens in order: requests → attendance → people → performance → payroll/reports → workspace → auth-adjacent (one screen per increment, parity protocol per `specs/ui_redesign/05_rollout_migration_spec.md`) — steps 1–6 complete; step 7 audited as already compliant (see reports/r8_migration_increments_log.md)
- [ ] T057 Retirement cleanup change: delete legacy duplicated builders once zero importers; retire Phase-1 redirects after one release cycle + owner sign-off
- [ ] T058 Program final checks: zero hardcoded Color(0x…) outside tokens; full required checks; owner walkthrough mobile RTL + desktop web all roles

---

## Dependencies & Execution Order

Setup → Foundational → US1 → US2 → US3 → US4 → US5 → US6.
Within US1, T016 depends on T011–T015; everything else parallelizable as marked.
Each phase ends with required checks: `flutter analyze`,
architecture/firestore guards, relevant Flutter tests.

## MVP Scope

Phases 1–3 (foundation + components) deliver immediate value; US2 navigation is
the first user-visible milestone.
