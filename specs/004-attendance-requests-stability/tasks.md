# Tasks: Attendance and Requests Stability

**Input**: Design documents from `/specs/004-attendance-requests-stability/`  
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`,
`contracts/`, `quickstart.md`

## Phase 1: Baseline and safety characterization

- [X] T001 Characterize the existing automatic-attendance event path, background restoration, and check-in identity without changing live behavior in `lib/services/automatic_attendance_service.dart`, `android/app/src/main/kotlin/com/zbooma/zawolfhr/MainActivity.kt`, `ios/Runner/AppDelegate.swift`, and `scripts/auto-attendance.js`
- [X] T002 Characterize every HR/manager/admin request tab, its source collection, legacy salary-deduction fields, and current search/filter behavior in `lib/screens/hr/`, `lib/screens/manager/`, and `lib/services/`
- [X] T003 Add regression fixtures covering historical requests, confirmed salary deductions, late-arrival deductions, and mixed timestamp encodings in `test/fixtures/request_visibility_fixtures.dart`
- [X] T004 Add a non-production attendance-device/location fixture and baseline tests for device reset, map fallback, and Cairo-day identity in `test/services/attendance_service_regression_test.dart`

## Phase 2: Shared foundation

- [X] T005 Extend safe Arabic failure mapping for attendance and request mutations so raw provider exceptions cannot reach UI in `lib/core/errors/` and `test/core/errors/`
- [X] T006 Create the immutable request visibility read-model entities and status classifiers described by the contract in `lib/features/request_visibility/domain/entities/` and `test/features/request_visibility/domain/`
- [X] T007 Implement a role-, status-, and date-bounded request visibility repository contract with pagination and explicit loaded/empty/retry/access-denied states in `lib/features/request_visibility/domain/` and `lib/features/request_visibility/data/`
- [X] T008 Add query/lifecycle guard tests preventing unbounded request listeners, listener creation inside `build`, and a `.get()` call within a snapshot transform in `test/firestore_query_guard_test.dart`
- [X] T009 Add server contract tests for idempotent attendance, authorized request decisions, and authorized device-reset mutations in `scripts/test/attendance-request-gateway.test.js`

## Phase 3: User Story 1 — Reliable location check-in (Priority: P1)

**Goal**: Manual and opt-in automatic location check-in create at most one
canonical Cairo-day attendance record and render only safe Arabic status.

**Independent test**: Validate in-range, out-of-range, temporary outage,
automatic event, duplicate event, and account-switch scenarios using non-live
fixtures.

- [X] T010 [P] [US1] Add tests for automatic-event opt-in, permission denial, duplicate prevention, and manual fallback in `test/services/automatic_attendance_service_test.dart`
- [X] T011 [P] [US1] Add tests for saved/pending/actionable Arabic attendance outcomes and local outbox account isolation in `test/features/attendance_checkin/`
- [X] T012 [US1] Route automatic native event signals through the same reliable, idempotent check-in boundary as manual attendance in `lib/services/automatic_attendance_service.dart` and `lib/features/attendance_checkin/`
- [X] T013 [US1] Preserve Android/iOS background restore behavior while requiring user opt-in, OS permission, location validation, and a manual fallback in `android/app/src/main/kotlin/com/zbooma/zawolfhr/MainActivity.kt` and `ios/Runner/AppDelegate.swift`
- [X] T014 [US1] Harden the authoritative attendance gateway against duplicate/replayed automatic events and return only semantic outcomes in `scripts/attendance-gateway.js` and `scripts/auto-attendance.js`
- [X] T015 [US1] Replace technical attendance dialogs/snackbars with safe Arabic states and retry/pending-sync actions in `lib/screens/employee/employee_dashboard.dart` and attendance presentation code

## Phase 4: User Story 2 — Request visibility and decisions (Priority: P1)

**Goal**: Eligible requests, including historical confirmed deductions, are
visible to the correct decision makers and all tabs complete deterministically.

**Independent test**: Create each request type and verify its approval chain;
load historical/confirmed deduction fixtures; exercise tab changes, search,
empty state, retry, approval, rejection, cancellation, and modification.

- [X] T016 [P] [US2] Add classification and Arabic employee-explanation tests for current, historical, confirmed salary-deduction, late-arrival deduction, and incomplete legacy records in `test/features/request_visibility/data/request_visibility_repository_test.dart` and `test/services/employee_deduction_service_test.dart`
- [X] T017 [P] [US2] Add request-tab state tests for search, fast tab changes, empty state, retryable failure, and access-denied state in `test/screens/hr/requests_management_screen_test.dart`
- [X] T018 [US2] Implement bounded legacy-aware request visibility queries, deterministic tab classification, and read-only salary-deduction explanation normalization in `lib/features/request_visibility/data/request_visibility_repository.dart` and `lib/services/employee_deduction_service.dart`
- [X] T019 [US2] Refactor HR request management to own stable bounded sources, show all appropriate active/history records, and apply search locally to loaded pages in `lib/screens/hr/`
- [X] T020 [US2] Refactor manager/admin request views to consume the same visibility contract and keep approver scope separate from historical reporting scope in `lib/screens/manager/` and `lib/screens/admin/`
- [X] T021 [US2] Route create, approve, reject, cancel, and modify operations through guarded semantic outcomes while retaining existing approval/audit history in `lib/services/` and `scripts/attendance-gateway.js`
- [X] T022 [US2] Add compatibility tests for attendance-correction, leave, permission, advance, and salary-deduction approval paths in `test/services/` and `scripts/test/`
- [X] T041 [US2] Render each employee salary deduction with an Arabic details view showing source, policy/admin reason, Cairo date or period, fraction/amount, and review status without altering payroll records in `lib/screens/employee/`

## Phase 5: User Story 3 — Productivity and KPI correctness (Priority: P1)

**Goal**: Productivity and KPI totals are scoped to the chosen employee/team
and period, include approved attendance-policy effects, and identify incomplete
inputs instead of silently showing zero.

**Independent test**: Compare known fixture records for two employees and two
periods, including approved leave/permission and unavailable inputs.

- [X] T023 [P] [US3] Add employee/team/period-scoping and approved leave/permission fixtures in `test/services/productivity_service_test.dart` and `test/services/kpi_service_test.dart`
- [X] T024 [P] [US3] Add regression tests that reject a month-wide `.get()` inside a KPI/productivity snapshot transformation in `test/firestore_query_guard_test.dart`
- [X] T025 [US3] Replace broad KPI reads and snapshot-time month queries with explicitly bounded/cached snapshot inputs in `lib/services/kpi_service.dart`
- [X] T026 [US3] Refactor productivity input collection to use selected employee/team and period filters only, returning complete/partial/unavailable input status in `lib/services/productivity_service.dart`
- [X] T027 [US3] Render consistent totals, drill-down records, selected-filter labels, and incomplete-input guidance in `lib/screens/hr/`, `lib/screens/manager/`, and employee KPI/productivity screens

## Phase 6: User Story 4 — Device and location management (Priority: P1)

**Goal**: Authorized HR/IT can reset a device with an audit reason and select
a reviewed company location on web with a safe fallback.

**Independent test**: Reset a test device, bind a replacement, select/save a
web map point, then force map unavailability and preserve reviewed coordinates.

- [X] T028 [P] [US4] Add authorization, audit-reason, stale-binding, and replacement-binding tests in `test/services/attendance_device_management_test.dart`
- [X] T029 [P] [US4] Add web map selection and coordinate fallback tests in `test/screens/company_location_picker_test.dart`
- [X] T030 [US4] Implement an auditable server-authoritative device-reset command with role checks and semantic response in `scripts/attendance-gateway.js`
- [X] T031 [US4] Connect employee management device reset UI to the guarded command and safe Arabic outcome state in `lib/screens/hr/employee_mgmt.dart` and `lib/services/attendance_service.dart`
- [X] T032 [US4] Fix web map initialization/selection and save coordinates plus radius atomically, retaining a reviewed coordinate fallback in `lib/screens/` and the location service

## Phase 7: User Story 5 — Safe mobile back navigation (Priority: P2)

**Goal**: Mobile back actions return to the prior in-app screen and guard work
that is still pending rather than unexpectedly exiting or losing it.

**Independent test**: Navigate list → detail → form on Android/iOS-compatible
test harnesses, invoke back, and verify retained/confirmed behavior.

- [X] T033 [P] [US5] Add navigation tests covering nested back, root behavior, dirty request forms, and pending attendance submission in `test/navigation/guarded_back_navigation_test.dart`
- [X] T034 [US5] Add a shared guarded-back policy that distinguishes nested routes, dirty form state, and pending attendance sync in `lib/navigation/guarded_back_navigation.dart`
- [X] T035 [US5] Apply guarded back handling to employee request, attendance, request-detail, and relevant manager/HR detail routes in `lib/screens/` and navigation wrappers

## Phase 8: Verification, documentation, and handoff

- [X] T036 Run focused Flutter tests for attendance, request visibility, productivity/KPI, device/location, and navigation; record the command/results in `specs/004-attendance-requests-stability/quickstart.md`
- [X] T037 Run `flutter analyze` and the full Flutter suite; resolve only Phase 004 regressions and record results in `specs/004-attendance-requests-stability/quickstart.md`
- [X] T038 Run the Node test suite for attendance/request gateway behavior and record results in `specs/004-attendance-requests-stability/quickstart.md`
- [ ] T039 Perform non-production manual acceptance for automatic check-in, request history tabs/search, device reset, web map, productivity/KPI filters, and mobile back; record outcomes without touching live employee data in `specs/004-attendance-requests-stability/quickstart.md`
- [ ] T040 Review the Phase 004 diff for raw error leakage, unbounded Firestore reads/listeners, and unauthorized/deferred Workspace work; prepare deployment instructions but do not deploy in `specs/004-attendance-requests-stability/`

## Dependencies and implementation order

1. Complete T001–T009 before user-story mutation work.
2. US1 and US2 can then proceed independently; US3 begins after T008.
3. US4 can proceed in parallel with US1/US2 after T009.
4. US5 can proceed after T005.
5. T036–T040 are the final quality gate. Company Workspace/Google Workspace
   work remains out of scope until this gate passes.
