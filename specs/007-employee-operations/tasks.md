# Tasks: Employee Operations and Operational Reliability

**Input**: Design documents in `specs/007-employee-operations/`

**Tests**: Characterization and regression tests are required because this phase
touches attendance, payroll-period semantics, authorization, and live
integration behavior.

## Phase 1: Setup and characterization

**Purpose**: Establish flags, boundaries, and failing behavior tests without
changing the live workflow.

- [X] T001 Create Phase 007 feature directories and barrel ownership notes in `lib/features/employee_operations/`, `lib/features/operational_visibility/`, `lib/features/sales_indicators/`, `lib/features/diagnostics/`, `lib/features/assistant/`, and `lib/features/conversations/`
- [X] T002 [P] Add Phase 007 disabled-by-default feature flags and test overrides in `lib/core/feature_flags/phase007_feature_flags.dart` and `test/core/phase007_feature_flags_test.dart`
- [X] T003 [P] Characterize effective-date versus approval-date correction and deduction behavior in `test/permission_cycle_accounting_test.dart` and `test/services/attendance_reconciliation_service_test.dart`
- [X] T004 [P] Characterize current notification badge/deep-link failures in `test/notification_route_test.dart` and `test/services/notification_service_test.dart`
- [X] T005 [P] Characterize historical request/deduction tab visibility and loader behavior in `test/requests_management_regression_test.dart` and `test/services/employee_deduction_service_test.dart`
- [X] T006 [P] Characterize sales matching/filter consistency using fixture rows in `test/sales_kpi_summary_test.dart` and `scripts/test/sales-kpi-sync.test.js`
- [X] T007 [P] Inventory force-update, security-review navigation, and RTL arrow surfaces in `lib/screens/required_update_screen.dart`, `lib/screens/manager/requests_mgmt.dart`, and `test/navigation/route_parity_test.dart`

---

## Phase 2: Foundational safety and integration contracts

**Purpose**: Shared prerequisites that block all Phase 007 vertical slices.

- [X] T008 Define sanitized diagnostic domain entities and repository contracts in `lib/features/diagnostics/domain/entities/diagnostic_event.dart` and `lib/features/diagnostics/domain/repositories/diagnostics_repository.dart`
- [X] T009 [P] Define Arabic safe-error codes and presentation mapper in `lib/features/diagnostics/domain/entities/safe_operation_error.dart` and `lib/features/diagnostics/presentation/safe_error_message_mapper.dart`
- [X] T010 Implement server diagnostic aggregation, fingerprint validation, rate limit, and no-sensitive-field guard in `scripts/diagnostics.js` and `scripts/notification-web.js`
- [X] T011 [P] Add diagnostic contract and redaction tests in `scripts/test/diagnostics.test.js` and `test/features/diagnostics/safe_error_message_mapper_test.dart`
- [X] T012 Define authenticated Hostinger request helper with operation ID, safe envelope parsing, and no-secret logging in `lib/core/sync/authenticated_operation_client.dart` and `test/core/authenticated_operation_client_test.dart`
- [X] T013 Implement Phase 007 server authorization helpers for role/team/self checks and audit actor context in `scripts/phase007-authorization.js` and `scripts/test/phase007-authorization.test.js`
- [X] T014 [P] Add common Arabic RTL/back-arrow and browser-selection regression helpers in `lib/design_system/components/rtl_navigation.dart` and `test/navigation/guarded_back_navigation_test.dart`
- [X] T015 Add a server-side feature-flag/rollback registry for every Phase 007 slice in `scripts/feature-flags.js`, `scripts/notification-web.js`, and `scripts/test/feature-flags.test.js`

**Checkpoint**: Safe errors, authorization, operation idempotency, and rollback
flags are available. No employee-facing behavior is switched yet.

---

## Phase 3: User Story 1 — Understand deductions and correct attendance quickly (P1) 🎯 MVP

**Goal**: Give employees a complete Arabic deduction explanation and an
idempotent shortcut from eligible late attendance to correction request, while
preserving the effective payroll period.

**Independent Test**: Create late/absence/manual deductions in two cycles;
verify only the employee sees details and a retry submits exactly one correction
without moving the cycle.

- [X] T016 [P] [US1] Add deduction explanation and correction-draft domain entities in `lib/features/employee_operations/domain/entities/deduction_explanation.dart` and `lib/features/employee_operations/domain/entities/attendance_correction_draft.dart`
- [X] T017 [P] [US1] Add employee-operations repository contracts for explanation/detail and correction shortcut in `lib/features/employee_operations/domain/repositories/employee_operations_repository.dart`
- [X] T018 [P] [US1] Write effective-cycle, authorization, and dedupe characterization tests in `test/features/employee_operations/deduction_explanation_test.dart` and `test/features/employee_operations/attendance_correction_shortcut_test.dart`
- [X] T019 [US1] Implement bounded Firestore data adapters that merge attendance, permission, and manual deductions by stable source key in `lib/features/employee_operations/data/firestore_employee_operations_data_source.dart` and `lib/features/employee_operations/data/employee_operations_repository_impl.dart`
- [X] T020 [US1] Add server-side correction operation-ID/dedupe enforcement and audit event without changing payroll-cycle allocation in `scripts/notification-web.js` and `scripts/test/attendance-correction-operation.test.js`
- [X] T021 [US1] Create focused deduction-details and correction-shortcut Cubits in `lib/features/employee_operations/presentation/cubit/deduction_details_cubit.dart` and `lib/features/employee_operations/presentation/cubit/attendance_correction_cubit.dart`
- [X] T022 [US1] Migrate employee deduction detail route and Arabic evidence/period/status UI in `lib/features/employee_operations/presentation/pages/employee_deduction_details_page.dart` and `lib/screens/employee/employee_deductions_screen.dart`
- [X] T023 [US1] Add discipline-card and late-attendance shortcut navigation in `lib/screens/employee/employee_dashboard.dart` and `lib/features/employee_operations/presentation/widgets/late_correction_shortcut.dart`
- [X] T024 [US1] Add widget/regression coverage for deduction detail, correction retry, Arabic safe failures, and role isolation in `test/features/employee_operations/employee_deduction_details_page_test.dart`

**Checkpoint**: Flagged employee flow can be demonstrated independently; old
deduction list remains available as rollback.

---

## Phase 4: User Story 2 — Work from one practical task and KPI workflow (P1)

**Goal**: Link task progress and KPI contribution through one work outcome while
retaining all legacy history.

**Independent Test**: Assign an outcome linked to one task/KPI, update it once,
and verify task/KPI/report projections agree without duplicate assignment.

- [X] T025 [P] [US2] Define `WorkOutcome` entity, state transitions, and repository contract in `lib/features/employee_operations/domain/entities/work_outcome.dart` and `lib/features/employee_operations/domain/repositories/work_outcome_repository.dart`
- [X] T026 [P] [US2] Write compatibility and idempotent-progress tests in `test/features/employee_operations/work_outcome_test.dart` and `test/services/task_service_test.dart`
- [X] T027 [US2] Implement Firestore outcome adapter and legacy task/KPI projection adapter in `lib/features/employee_operations/data/work_outcome_repository_impl.dart` and `lib/features/employee_operations/data/legacy_task_kpi_projection.dart`
- [X] T028 [US2] Implement focused work-outcome Cubit and employee/manager outcome pages behind `work_outcomes_v2` in `lib/features/employee_operations/presentation/cubit/work_outcome_cubit.dart`, `lib/features/employee_operations/presentation/pages/work_outcomes_page.dart`, `lib/screens/employee/employee_tasks_screen.dart`, and `lib/screens/manager/tasks_mgmt.dart`
- [X] T029 [US2] Add outcome/KPI parity report and widget tests in `test/features/employee_operations/work_outcomes_page_test.dart` and `test/services/kpi_service_test.dart`

---

## Phase 5: User Story 3 — Reliable notifications, help, and governed communication (P1)

**Goal**: Fix unread badges/deep links and establish safely governed Arabic help
and employee-management conversation foundations.

**Independent Test**: Mark all read, open an approver request notification,
ask a policy question with provider disabled, and upload a governed attachment.

- [X] T030 [P] [US3] Define unread state, route destination, assistant, conversation, and attachment domain contracts in `lib/features/employee_operations/domain/entities/notification_read_state.dart`, `lib/features/assistant/domain/`, and `lib/features/conversations/domain/`
- [X] T031 [P] [US3] Add notification bulk-read/role-route contract tests in `scripts/test/notification-routing.test.js` and `test/features/employee_operations/notification_read_state_test.dart`
- [X] T032 [US3] Implement bounded server bulk-read, canonical counter repair, and authorized deep-link resolver in `scripts/notification-web.js` and `scripts/dispatch-notifications.js`
- [X] T033 [US3] Replace client badge counting and stored-route trust with repository/Cubit state in `lib/features/employee_operations/data/notification_operations_repository_impl.dart`, `lib/features/employee_operations/presentation/cubit/notification_badge_cubit.dart`, `lib/services/notification_service.dart`, and `lib/navigation/router.dart`
- [X] T034 [US3] Implement disabled-by-default Arabic guidance assistant with access-limited local help corpus and safe refusal states in `lib/features/assistant/data/`, `lib/features/assistant/domain/`, and `lib/features/assistant/presentation/`
- [X] T035 [US3] Implement conversation metadata, member checks, idempotent message state, and Company Workspace attachment bridge in `lib/features/conversations/data/`, `scripts/notification-web.js`, and `scripts/workspace/drive-operations.js`
- [X] T036 [US3] Add conversation/assistant authorization, Drive-link redaction, badge, and deep-link tests in `scripts/test/conversations.test.js`, `test/features/assistant/employee_assistant_test.dart`, and `test/features/conversations/conversation_test.dart`

---

## Phase 6: User Story 4 — Accurate scoped operational control (P1)

**Goal**: Let authorized operational users hide test accounts, inspect one
employee over a period, see all authorized history, and manage attendance
policies from the correct location.

**Independent Test**: Hide a test account, review a cross-period employee
timeline, confirm all historical tabs, and verify non-HR/admin cannot reach
security review.

- [X] T037 [P] [US4] Define operational visibility and employee timeline entities/contracts in `lib/features/operational_visibility/domain/entities/` and `lib/features/operational_visibility/domain/repositories/operational_visibility_repository.dart`
- [X] T038 [P] [US4] Add visibility/timeline effective-date and role-scope tests in `test/features/operational_visibility/operational_visibility_test.dart` and `test/features/operational_visibility/employee_timeline_test.dart`
- [X] T039 [US4] Implement audited hide/restore and paginated timeline Hostinger routes in `scripts/notification-web.js`, `scripts/phase007-authorization.js`, and `scripts/test/operational-api.test.js`
- [X] T040 [US4] Implement operational visibility and timeline data adapters/Cubits in `lib/features/operational_visibility/data/`, `lib/features/operational_visibility/domain/`, and `lib/features/operational_visibility/presentation/cubit/`
- [X] T041 [US4] Add HR/admin hide/restore controls, employee period explorer, and default hidden-account filtering in `lib/features/operational_visibility/presentation/pages/`, `lib/screens/manager/team_attendance.dart`, and `lib/screens/hr/attendance_summary_details_screen.dart`
- [X] T042 [US4] Replace management request/deduction tab query paths with bounded merged repository state and explicit loading/error/empty/pagination UI in `lib/features/request_visibility/` and `lib/screens/manager/requests_mgmt.dart`
- [X] T043 [US4] Relocate checkout policy to Attendance and Work Policy while keeping leave permissions independent in `lib/screens/hr/attendance_policy_settings_screen.dart`, `lib/features/checkout_policy/`, and `test/checkout_policy_inventory_test.dart`
- [X] T044 [US4] Gate security-review navigation/rendering to HR/admin at route and server level in `lib/navigation/router.dart`, `lib/screens/manager/requests_mgmt.dart`, `scripts/notification-web.js`, and `test/navigation/route_parity_test.dart`

---

## Phase 7: User Story 5 — Trust sales indicators, updates, and Arabic product behavior (P1)

**Goal**: Make sales attribution/filtering deterministic and safely explain
source gaps; make force updates recoverable Arabic UI.

**Independent Test**: Query mapped/unmapped/ambiguous fixtures with different
filters; compare every visual/export result; recover from mandatory-update retry.

- [X] T045 [P] [US5] Define sales identity mapping, filter, snapshot, and source-health domain contracts in `lib/features/sales_indicators/domain/`
- [X] T046 [P] [US5] Add server sales mapping/filter echo/ambiguous-row contract tests in `scripts/test/sales-kpi-sync.test.js` and `scripts/test/sales-indicators-contract.test.js`
- [X] T047 [US5] Implement server-only mapping registry, filter-versioned snapshot persistence, and reconciliation response in `scripts/sales-analytics-client.js`, `scripts/sync-sales-kpis.js`, and `scripts/notification-web.js`
- [X] T048 [US5] Implement sales indicator data adapter, Cubit, filter sheet, source-health state, and authorized mapping review UI in `lib/features/sales_indicators/data/`, `lib/features/sales_indicators/presentation/`, and `lib/screens/manager/kpi_mgmt.dart`
- [X] T049 [US5] Replace forced-update loop with an explicit Arabic retry/update/unsupported-release state machine in `lib/screens/required_update_screen.dart`, `lib/core/feature_flags/`, and `test/screens/required_update_screen_test.dart`
- [X] T050 [US5] Add end-to-end filter consistency and Arabic/RTL screenshot/widget tests in `test/features/sales_indicators/sales_indicators_filter_test.dart` and `test/screens/required_update_screen_test.dart`

---

## Phase 8: User Story 6 — Detect problems before employees report them (P2)

**Goal**: Turn safe diagnostic events into actionable authorized reports while
keeping employee errors brief and Arabic.

**Independent Test**: Trigger repeated permission/unavailable/deep-link/update/
sales failures and verify one sanitized aggregate per fingerprint/release.

- [X] T051 [P] [US6] Add diagnostic aggregation query/report domain contracts in `lib/features/diagnostics/domain/entities/diagnostic_report.dart` and `lib/features/diagnostics/domain/repositories/diagnostics_repository.dart`
- [X] T052 [P] [US6] Add redaction/dedup/rate-limit regression tests in `scripts/test/diagnostics.test.js` and `test/features/diagnostics/diagnostic_event_test.dart`
- [X] T053 [US6] Implement diagnostic report API and HR/admin-only dashboard with release/feature/safe-code grouping in `scripts/notification-web.js`, `lib/features/diagnostics/data/`, and `lib/features/diagnostics/presentation/pages/diagnostics_report_page.dart`
- [X] T054 [US6] Wire safe-error reporting through check-in, requests, sales, notifications, and update paths in `lib/features/attendance_checkin/`, `lib/features/request_visibility/`, `lib/features/sales_indicators/`, `lib/services/notification_service.dart`, and `lib/screens/required_update_screen.dart`

---

## Phase 9: User Story 7 — Safe in-app developer tools (P2)

**Goal**: Give a named employee time-limited app diagnostic tools only, without
weakening mock-location, USB-debug, device binding, or attendance controls.

**Independent Test**: Grant then revoke/expire the entitlement; only menu access
changes and mock/USB attendance safeguards behave exactly as before.

- [X] T055 [P] [US7] Define developer-tools entitlement entity, scope allowlist, and repository contract in `lib/features/diagnostics/domain/entities/developer_tools_entitlement.dart` and `lib/features/diagnostics/domain/repositories/developer_tools_repository.dart`
- [X] T056 [P] [US7] Add entitlement expiry/revocation and no-attendance-bypass tests in `test/features/diagnostics/developer_tools_entitlement_test.dart` and `test/services/attendance_security_service_test.dart`
- [X] T057 [US7] Implement HR/admin-only audited grant/revoke server route with mandatory expiry and no bypass field in `scripts/notification-web.js`, `scripts/phase007-authorization.js`, and `scripts/test/developer-tools-entitlement.test.js`
- [X] T058 [US7] Implement entitlement data adapter/Cubit, HR/admin grant screen, and employee in-app diagnostics menu behind a feature flag in `lib/features/diagnostics/data/`, `lib/features/diagnostics/presentation/`, and `lib/navigation/router.dart`
- [X] T059 [US7] Verify USB debugging/mock location/device/geofence controls remain independent of entitlement in `lib/services/attendance_security_service.dart`, `lib/services/attendance_service.dart`, and `test/services/attendance_security_service_test.dart`

---

## Phase 10: Polish, migration gates, and release readiness

- [X] T060 [P] Complete Phase 007 Arabic copy, RTL arrows, semantics, browser selection/copy/Ctrl+F, and responsive empty-space regression audit in `lib/features/`, `lib/screens/`, and `test/design_system/`
- [X] T061 [P] Add Firestore listener/query-budget guards for all new repositories in `test/firestore_query_guard_test.dart`, `test/stream_subscription_lifecycle_test.dart`, and `scripts/test/firestore-read-budget.test.js`
- [X] T062 Add legacy/V2 parity fixtures, feature-flag rollout controls, and rollback runbook in `test/fixtures/phase007_fixtures.dart`, `scripts/HOSTINGER_DEPLOYMENT.md`, and `specs/007-employee-operations/quickstart.md`
- [X] T063 Run full required verification and record release evidence in `specs/007-employee-operations/quickstart.md`, `flutter analyze`, `flutter test`, and `scripts/package.json`
- [ ] T064 Conduct owner-reviewed pilot per vertical slice, retain legacy fallback, rotate the shared sales key in Hostinger secret storage, and document cutover/rollback evidence in `specs/007-employee-operations/quickstart.md`

## Dependencies and Execution Order

- Setup T001–T007 precedes the foundation.
- Foundation T008–T015 blocks every user story.
- US1, US2, US3, US4, and US5 can begin after foundation; implement US1/US4
  before switching any attendance/request/deduction view.
- US6 provides observability and should be enabled before a wide pilot.
- US7 depends on diagnostics authorization (T008–T015 and T051–T054).
- T060–T064 follow all desired vertical slices; no V2 default switch occurs
  without owner-approved pilot and rollback evidence.

## Parallel Opportunities

- T002–T007 can proceed in parallel after T001.
- T008–T015 split across Dart contracts, Node safeguards, and test work.
- After foundation, US1, US2, US3, US4, and US5 are separate slices; each `[P]`
  task has no dependency on an unfinished task in its phase.
- US6 reporting and US7 domain/tests may proceed in parallel once their shared
  diagnostics foundation is stable.

## Implementation Strategy

1. Ship no behavior change until T001–T015 are green.
2. Start MVP with US1 and US4: employee deduction clarity plus management
   request/attendance visibility resolve the most urgent fairness problems.
3. Add US3 notification consistency and US5 sales reliability behind flags.
4. Enable diagnostics before limited pilot, then introduce work outcomes,
   assistant/chat foundations, and developer tools only under explicit flags.
5. Keep the legacy route as fallback until parity, read-budget, Arabic RTL,
   authorization, and owner pilot evidence pass.
