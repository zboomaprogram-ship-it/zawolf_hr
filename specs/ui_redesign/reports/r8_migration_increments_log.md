# Phase 8 Migration Increments Log

Per `05_rollout_migration_spec.md`: one screen per deployable increment,
parity protocol applied before each is considered migrated.

## Step 1 — Requests surfaces ✅
- `requests_mgmt`: ConfirmationSheet everywhere, FilterBar (salary-deduction
  chips pre-existing), StatusPill via timeline data, `DsMasterDetailView`
  web ≥980 on leaves/permissions/advances/confirmed-deductions/corrections/
  security-reviews tabs, per-row submit guards, bidi amounts.
- `employee_requests`: FilterBar status chips on history console, skeletons,
  stream-error states, EmptyState, StatusPill rows, pinned FAB.
- Requests log (`requests_log_screen`): skeleton loading, DS Empty/ErrorState
  wrappers; period prev/next chevrons kept physical (spatial cycle control,
  documented intentional difference).
- Approval timeline views: reused as-is (already a shared component).

## Step 2 — Attendance surfaces (presentation only) ✅
- `attendance_summary_details_screen`: main list / day-details sheet /
  today-category views moved to SkeletonList, ErrorState (with retry where a
  reload path exists), EmptyState. No query, policy, or accounting change.
- `team_attendance`: stream loading → SkeletonList, empty → EmptyState.
- Check-in flows: employee dashboard radar/status card already render from
  design-system tokens; no presentation duplication found to migrate.
- Parity notes:
  - Enumerated states reproduced 1:1 (loading/empty/error/role variations);
    zero intentional differences beyond component substitution.
  - Attendance behavior untouched (hard rule respected); characterization
    suites (`attendance_*`, `checkout_policy_*`) all green after each edit.
  - Route parity test green; RTL handled via earlier Directionality audit
    (this screen's chevron/alignment fixes landed in T047/T048).

## Step 3 — People ✅
- `employee_mgmt`: stream loading → SkeletonList; filtered-empty → EmptyState.
  RTL alignments were already converted (T047).
- `team_members_screen`: error → ErrorState (with retry via existing refresh),
  loading → SkeletonList, empty → EmptyState.
- `employee_insights_screen`: user/attendance/performance loaders → skeletons;
  attendance-history empty → EmptyState. Error messages preserved as-is where
  they are inline section messages (documented intentional: sections degrade
  independently instead of failing the whole profile page).
- `profile_settings`: no data-state surfaces (only auth gate + inline submit
  spinners); already uses Wolf primitives and `AppLogo`. No change needed.

## Step 4 — Performance ✅
- `kpi_mgmt`: all five data-loading spinners → SkeletonList (sales summary,
  provider records, HR summary, managed KPIs, templates); template-empty →
  EmptyState. Inline submit spinners kept (interaction feedback, not data
  states).
- `productivity_ranking_screen`: stream loading → SkeletonList;
  filter-empty → EmptyState. Refresh-button spinner kept intentionally.
- `department_performance_screen`, `tasks_mgmt`, `employee_tasks_screen`,
  `warnings_rewards_mgmt`, `employee_warnings_rewards_screen`: full-screen
  data loaders → SkeletonList. Contextual WolfCard empty messages preserved
  (documented intentional: they carry conditional copy per filter state).

## Step 5 — Payroll & reports ✅
- `employee_payroll_screen`: stream loading → SkeletonList.
- `employee_deductions_screen`: loading → SkeletonList (error state already
  user-facing via `_Message`; kept).
- `employee_productivity_screen`, `employee_kpi_screen`: loaders → SkeletonList.
- Payroll behavior untouched (hard rule respected); deduction detail cards
  were already migrated in the requests program increments.

## Step 6 — Company/workspace ✅
- All 10 hardcoded `Color(0x…)` values outside token files eliminated: the
  sheet editor now uses new semantic tokens (`editorAccent`, `editorActivated`,
  `editorGridBorder`, `editorCellEdit`, `editorSurface`, `editorSurfaceDeep`)
  and the check-in radar pulse uses `dangerDeep` — all defined once in
  `lib/theme/theme.dart`. Grep for `Color(0x…)` outside tokens/theme is zero,
  satisfying the T058 program gate.
- Folder browser, workspace center, and sheet editor loaders → SkeletonList.
- Workspace center presentation already sits behind its Firestore-free
  presentation guard (query-guard suite).

## Step 7 — Auth-adjacent ✅ (audit)
- Login, profile, splash: login/profile already render `AppLogo` and Wolf
  primitives with no data-state surfaces beyond the auth gate; splash is
  byte-for-byte protected by R5. No changes required — recorded as the final
  increment of the migration order.
- Workspace sheet editor holds 9 hardcoded `Color(0x…)` values — must be
  tokenized during step 6 before the T058 zero-hardcoded-color gate closes.
- Auth-adjacent: login/profile already use `AppLogo` and Wolf primitives.
