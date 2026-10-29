# Tasks: App UX Consolidation

**Input:** `specs/ux_consolidation/spec.md` + `specs/ux_consolidation/plan.md` (owner-approved prerequisite).  
**Format:** `- [ ] [ID] [P?] — Description with file path`  
**Execution Rule (AGENTS.md):** All tasks uncompleted — this list is generated for owner review. Stop for owner review after specification, plan, and task generation. Do not continue automatically into implementation.

---

## Phase 0: Inventory & Baseline Guards

- [x] C001 Run loading-adoption inventory: grep and record exact counts of spinners (`CircularProgressIndicator`, `LinearProgressIndicator`) and ad-hoc `SkeletonList(itemHeight: ...)` → `reports/loading_adoption_inventory.md`
- [x] C002 Extend `reports/loading_adoption_inventory.md` with per-screen columns: error-surface, pull-to-refresh, icon-action labeling, component adoption (`Wolf*` vs raw), and color-token violations
- [x] C003 Walk navigation config vs six-domain IA and document leftovers → `reports/grouping_leftovers.md`
- [x] C004 Write spinner-allowlist guard test in `test/design_system/spinner_allowlist_guard_test.dart` (red on current baseline)
- [x] C005 Write hand-tuned skeleton height guard test in `test/design_system/skeleton_height_guard_test.dart` (red on current baseline)
- [x] C006 Write silent-catch guard test in `test/architecture/silent_catch_guard_test.dart` (fails on unhandled presentation catch blocks)
- [x] C007 Write icon-action labeling guard test in `test/design_system/icon_action_labeling_guard_test.dart` (fails on `IconButton` missing tooltip and Semantics)
- [x] C008 Write Arabic-only / closed-i18n guard test in `test/architecture/arabic_only_guard_test.dart` (fails on localization packages or imports)
- [ ] C009 Confirm with owner: searchable entity list for v1 global search (requests, employees, tasks, notifications, conversations proposed)

**Gate 0:** Owner reviews inventory + grouping leftovers + search scope; baseline guards activated.

---

## Phase 1: Loading System Core (Build beside legacy)

- [x] C010 [P] Add shape-accurate skeleton patterns (`SkeletonEmployeeRow`, `SkeletonStatCard`, `SkeletonInsightCard`, `SkeletonAttendanceRow`, `SkeletonTableRows`, `SkeletonDetailPane`) in `lib/design_system/components/skeletons.dart`
- [x] C011 [P] Write height-parity widget tests for each skeleton pattern (mobile 390px + desktop 1024px) in `test/design_system/skeleton_height_parity_test.dart`
- [x] C012 Implement stale-while-refresh contract widget and mixin in `lib/design_system/components/stale_while_refresh.dart` + test in `test/design_system/stale_while_refresh_test.dart`
- [x] C013 Extract keep-mounted tab behavior from `_LazyRequestTab` into shared component `lib/design_system/components/keep_mounted_tab_view.dart` (preserving AGENTS.md 2-consumer rule)

**Checkpoint 1:** Design-system tests, `flutter analyze`, and architecture guards green.

---

## Phase 2: Requests Hub (Feature slice beside legacy)

- [x] C014 Scaffold `lib/features/request_workspace/` domain (`request_record.dart`, `request_repository.dart`) and data layer (`request_repository_impl.dart`) over `request_visibility` and existing services; document read budget
- [x] C015 Implement `RequestQueueCubit` (<300 lines) for "طلبات عليا" (pending my action) in `lib/features/request_workspace/presentation/cubits/request_queue_cubit.dart`
- [x] C016 Implement `RequestBrowseCubit` (<300 lines) for "كل الطلبات" (filters, browse, pagination) in `lib/features/request_workspace/presentation/cubits/request_browse_cubit.dart`
- [x] C017 Implement `RequestDetailCubit` (<300 lines) for request details and action handling in `lib/features/request_workspace/presentation/cubits/request_detail_cubit.dart`
- [x] C018 Build Requests Hub page (`RequestsHubPage`) with three views (queue, browse, history) and `FilterBar` in `lib/features/request_workspace/presentation/pages/requests_hub_page.dart`
- [x] C019 Build Shared Detail page (`RequestDetailPage`) with approval timeline + `ConfirmationSheet` + `DsMasterDetailView` (>=980) in `lib/features/request_workspace/presentation/pages/request_detail_page.dart`
- [x] C020 Add router redirects from legacy requests paths in `lib/navigation/router.dart` and write route parity test in `test/navigation/requests_hub_route_parity_test.dart` (red first, then redirects green)
- [x] C021 Conduct parity walk across all 18 legacy tabs in `requests_mgmt.dart`; record coverage and file any follow-ups in `reports/requests_hub_parity_report.md`

**Gate 2:** Owner reviews hub parity before any retirement planning.

---

## Phase 3: Screen Sweep — states, feedback, consistency, labels

*Each increment bundles: skeleton patterns, stale-while-refresh, error surfacing (FR-S2), pull-to-refresh (FR-S3), Wolf* component swaps (FR-C), token color replacement (FR-C), and icon labels (FR-A1).*

- [x] C022 Migrate Requests family screens in `lib/screens/requests/` and `lib/features/request_workspace/` (bundle sweep)
- [x] C023 Migrate Attendance family screens in `lib/screens/attendance/` and `lib/features/remote_work/` (bundle sweep, presentation only, no payroll/attendance behavior change)
- [x] C024 Migrate People & Employees screens in `lib/screens/employee/` and `lib/screens/hr/employees/` (bundle sweep)
- [x] C025 Migrate Performance & KPI screens in `lib/screens/kpi/` and `lib/screens/performance/` (bundle sweep)
- [x] C026 Migrate Payroll & Reports screens in `lib/screens/payroll/` and `lib/screens/reports/` (bundle sweep, no business behavior change)
- [x] C027 Migrate Workspace & Company OS screens in `lib/screens/company_os/` and `lib/screens/workspace/` (bundle sweep)
- [x] C028 Migrate Auth-adjacent & Profile screens in `lib/screens/auth/` and `lib/screens/profile/` (bundle sweep)
- [x] C029 Maintain per-increment evidence log with exact grep counts and test runs in `reports/ux_consolidation_increments_log.md`

---

## Phase 4: Global Search (WS4 core)

- [ ] C030 Scaffold `lib/features/app_search/` (domain/data/presentation) against the approved C009 scope list; bounded services only (≤10/entity queries, zero new listeners)
- [ ] C031 Implement `AppSearchDelegate` with Arabic-first copy, session-only recent chips, and RTL support in `lib/features/app_search/presentation/app_search_delegate.dart`
- [ ] C032 Connect search entry points in mobile role app bars and web top bar in `lib/navigation/` (results deep-link to existing routes)
- [ ] C033 Document search read budget and query boundaries in `reports/search_read_budget.md`
- [ ] C034 Write widget tests for search: empty query, Arabic normalization, deep-link navigation in `test/features/app_search/app_search_test.dart`

**Gate 4:** Owner confirms search coverage in phase report.

---

## Phase 5: Accessibility Floor Closeout

- [ ] C035 Finish icon-action labeling app-wide; assert `icon_action_labeling_guard_test.dart` passes with recorded allowlist
- [ ] C036 Conduct and record manual Arabic screen-reader walkthrough of hub + top-10 visited screens in `reports/accessibility_screen_reader_walkthrough.md`

---

## Phase 6: Retirement & Closeout (Separate reviewed changes)

- [ ] C037 Delete deprecated loading wrappers with 0 callers (verified by grep) in a dedicated cleanup commit
- [ ] C038 Retire orphaned duplicate request-history surfaces (`requests_log_screen.dart` etc.) no longer referenced
- [ ] C039 Prepare dormant `requests_mgmt.dart` retirement proposal after one release cycle with owner sign-off
- [ ] C040 Run final component-parity greps: zero `Color(0x…)` outside tokens/theme; zero raw buttons/inputs/cards outside design system
- [ ] C041 Verify all acceptance criteria of `spec.md` with cited evidence (test names, grep counts) in `reports/final_ux_consolidation_report.md`

---

## Dependencies & Execution Order

```
[Phase 0: Inventory & Baseline Guards] (C001–C009)
                  │
                  ▼ (Gate 0: Owner Approval)
[Phase 1: Loading Core] (C010–C013)
        │                 │
        ▼                 ▼
[Phase 2: Requests Hub]  [Phase 4: Global Search] (C030–C034)
  (C014–C021)                     │
        │                         │
        ▼ (Gate 2: Parity)        │
[Phase 3: Screen Sweep] ◄─────────┘
  (C022–C029)
        │
        ▼
[Phase 5: Accessibility Floor] (C035–C036)
        │
        ▼
[Phase 6: Retirement & Closeout] (C037–C041)
```

## Parallel Execution Opportunities

- Once **Phase 0** passes Gate 0, **C010** (Skeleton patterns) and **C011** (Height parity tests) can be built in parallel.
- **Phase 4** (Global Search, C030–C034) can be developed in parallel with **Phase 3** (Screen Sweep, C022–C029) since it touches distinct feature directories (`lib/features/app_search/`).
- Inside **Phase 3**, each screen family increment (C022 through C028) is an isolated, deployable vertical slice.

## Definition of Done (Per Incremental Change)

1. `flutter analyze` clean (0 errors, 0 warnings).
2. Architecture guards (`test/architecture_guard_test.dart` and `test/firestore_query_guard_test.dart`) and all 5 new guards green.
3. Every Cubit remains strictly < 300 lines with single UI-state responsibility.
4. Presentation imports domain contracts only (never data/Firebase/Dio).
5. Arabic RTL and Desktop Web (1024/1440) states verified per surface.
6. Evidence recorded in `reports/` with verifiable grep commands and test outputs.
