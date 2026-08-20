# Tasks: Check-out Policy Control

**Input**: Design documents from `specs/003-checkout-retirement/`

**Prerequisites**: [spec.md](spec.md), [plan.md](plan.md),
[research.md](research.md), [data-model.md](data-model.md),
[contract](contracts/checkout-policy-control-contract.md), and
[quickstart.md](quickstart.md)

**Tests**: Required. Attendance, permissions, and payroll consequences are
critical business rules. Add characterization/contract tests before changing the
corresponding behavior.

**Organization**: Tasks are grouped by user story. The current policy default
is disabled; no task authorizes a production data migration, rules change,
deployment, or policy activation.

## Phase 1: Setup and Characterization

**Purpose**: Establish the legacy behavior baseline and a complete inventory of
check-out producers/consumers before changing the policy.

- [X] T001 Document each check-out write, reminder, automation, deduction, approval, report, and notification producer in `specs/003-checkout-retirement/research.md`.
- [X] T002 [P] Add legacy checkout-boundary and existing late-permission characterization cases in `test/attendance_policy_config_test.dart`.
- [X] T003 [P] Add legacy check-out gateway characterization cases in `scripts/test/attendance-gateway.test.js`.
- [X] T004 [P] Add reminder/automatic-attendance/daily-job check-out characterization fixtures in `scripts/test/notification-routing.test.js`.
- [X] T005 Record the required Flutter and Node test commands and baseline results in `specs/003-checkout-retirement/quickstart.md`.

---

## Phase 2: Foundational Policy and Safe Outcome Handling

**Purpose**: Implement the default-off, role-protected, revisioned policy that
blocks all later work. No user story starts before this phase is complete.

- [X] T006 Add immutable policy/audit field definitions and evaluation-point rules in `specs/003-checkout-retirement/data-model.md`.
- [X] T007 [P] Create the `CheckoutPolicy` value object, default-off parser, and snapshot type in `lib/features/checkout_policy/domain/entities/checkout_policy.dart`.
- [X] T008 [P] Define the authenticated checkout-policy repository contract in `lib/features/checkout_policy/domain/repositories/checkout_policy_repository.dart`.
- [X] T009 [P] Add default-off, malformed-document, revision, and policy-snapshot unit tests in `test/features/checkout_policy/domain/checkout_policy_test.dart`.
- [X] T010 Implement the Firestore/gateway-backed policy repository with cached presentation state only in `lib/features/checkout_policy/data/checkout_policy_repository_impl.dart`.
- [X] T011 Add normal-HR/super-admin authorization, transaction revision checks, and append-only policy-event writes in `scripts/notification-web.js`.
- [X] T012 Add authenticated read/change policy routes matching `contracts/checkout-policy-control-contract.md` in `scripts/notification-web.js`.
- [X] T013 Add server contract tests for default-off, authorization, revision conflicts, and one-event-per-change in `scripts/test/checkout-policy.test.js`.
- [X] T014 Add a shared server policy resolver that fails closed for check-out-only work in `scripts/checkout-policy.js`.
- [X] T015 Add a typed safe attendance outcome mapper for `checkout_disabled`, transient failures, and request-status guidance in `lib/features/attendance_checkin/presentation/attendance_outcome_mapper.dart`.
- [X] T016 Add widget/unit coverage proving raw Firebase/transport strings cannot be rendered by the new attendance outcome mapper in `test/features/attendance_checkin/presentation/attendance_outcome_mapper_test.dart`.

**Checkpoint**: A missing policy is disabled, only authorized HR can change it,
and every authorized change creates one ordered audit event.

---

## Phase 3: User Story 1 — Submit Leave and Valid Attendance Requests (Priority: P1) 🎯 MVP

**Goal**: Employees can always submit official leave, late-arrival, and
early-leave requests using the normal approval chain, whether check-out is on or
off.

**Independent Test**: With policy disabled, submit all three request types and
approve early leave. Confirm the approval chain runs, but no check-out event,
reminder, review, or deduction is created.

### Tests for User Story 1

- [X] T017 [P] [US1] Add disabled-policy request-form tests for official leave, late arrival, and early leave in `test/leave_request_policy_test.dart`.
- [X] T018 [P] [US1] Add approval-chain regression tests proving early leave remains valid independently of checkout status in `test/request_approval_policy_test.dart`.
- [X] T019 [P] [US1] Add payroll-cycle attribution cases for late approval and early leave across payroll periods in `test/permission_cycle_accounting_test.dart`.
- [X] T020 [P] [US1] Add no-check-out-consequence reconciliation tests for approved early leave while disabled in `test/services/attendance_reconciliation_service_test.dart`.

### Implementation for User Story 1

- [X] T021 [US1] Preserve official leave, late-arrival, and early-leave choices regardless of policy and add disabled-policy Arabic guidance in `lib/screens/employee/employee_requests.dart`.
- [X] T022 [US1] Keep early-leave approval independent from checkout creation and persist the applicable policy snapshot on any new decision in `lib/services/request_approval_policy_service.dart`.
- [X] T023 [US1] Prevent disabled-policy early leave from creating a synthetic checkout or checkout-only deduction in `lib/services/attendance_reconciliation_service.dart`.
- [X] T024 [US1] Preserve the request's attendance/payroll attribution date rather than approval date in `lib/services/attendance_service.dart`.

**Checkpoint**: The three employee request types are independently usable while
check-out is disabled, and early leave authorizes departure without a checkout.

---

## Phase 4: User Story 2 — Control Check-out from the HR Dashboard (Priority: P1)

**Goal**: Authorized normal HR can view and safely toggle check-out from the HR
dashboard; it is off by default.

**Independent Test**: As normal HR, enable/disable with a reason and confirm a
single audit event and immediate prospective UI behavior. As employee or
unauthorized manager, verify no control or write authority.

### Tests for User Story 2

- [X] T025 [P] [US2] Add policy-management role/visibility widget tests in `test/screens/hr/hr_dashboard_checkout_policy_test.dart`.
- [X] T026 [P] [US2] Add employee check-in-only and enabled-checkout presentation tests in `test/screens/employee/employee_dashboard_checkout_policy_test.dart`.
- [X] T027 [P] [US2] Add repository/controller tests for reload-after-conflict and cached-display behavior in `test/features/checkout_policy/data/checkout_policy_controller_test.dart`.

### Implementation for User Story 2

- [X] T028 [US2] Add an authorized HR dashboard policy card with status, effective time, confirmation, optional reason, and latest audit summary in `lib/screens/hr/hr_dashboard.dart`.
- [X] T029 [US2] Add policy loading/state handling and conflict reload behavior in `lib/features/checkout_policy/presentation/checkout_policy_controller.dart`.
- [X] T030 [US2] Show check-in-only UI while disabled and show normal checkout controls only while enabled in `lib/screens/employee/employee_dashboard.dart`.
- [X] T031 [US2] Map disabled/stale checkout outcomes to safe Arabic employee status in `lib/services/attendance_gateway_service.dart`.
- [X] T032 [US2] Add access-safe policy audit display for HR/super-admin users in `lib/screens/hr/hr_dashboard.dart`.

**Checkpoint**: HR can make one audited prospective change; employees never see
check-out UI while disabled and unauthorized users cannot control the policy.

---

## Phase 5: User Story 3 — Prevent Check-out Consequences While Disabled (Priority: P1)

**Goal**: Disabled policy prevents every new manual, queued, automatic,
reminder, daily-processing, notification, approval, and report consequence.

**Independent Test**: Disable the switch, then send a stale gateway request,
replay an offline queue item, process automatic signals/reminders/daily tasks,
and verify zero attendance mutations, deductions, reviews, approvals, or
notifications are created.

### Tests for User Story 3

- [X] T033 [P] [US3] Add gateway tests proving disabled checkout exits before device binding and attendance mutation in `scripts/test/attendance-gateway.test.js`.
- [X] T034 [P] [US3] Add offline queue tests for terminal disabled checkout behavior and no direct-write fallback in `test/services/offline_attendance_queue_service_checkout_policy_test.dart`.
- [X] T035 [P] [US3] Add automatic attendance/reminder suppression tests in `scripts/test/notification-routing.test.js`.
- [X] T036 [P] [US3] Add daily deduction/replay tests for disabled attendance-cutoff policy snapshots in `scripts/test/notification-routing.test.js`.
- [X] T037 [P] [US3] Add notification dispatch revalidation tests for disabled check-out messages in `scripts/test/notification-routing.test.js`.

### Implementation for User Story 3

- [X] T038 [US3] Evaluate shared policy before `checkOut` device binding or attendance write and return `checkout_disabled` in `scripts/attendance-gateway.js`.
- [X] T039 [US3] Route offline check-out replay through the gateway and mark disabled outcomes terminal with no Firestore fallback in `lib/services/offline_attendance_queue_service.dart`.
- [X] T040 [US3] Suppress automatic check-out signal processing under disabled policy in `scripts/auto-attendance.js`.
- [X] T041 [US3] Suppress check-out reminder planning/enqueueing under disabled policy in `scripts/attendance-reminders.js`.
- [X] T042 [US3] Revalidate policy before dispatching an existing check-out reminder in `scripts/dispatch-notifications.js`.
- [X] T043 [US3] Apply policy-at-attendance-cutoff logic to missed/early checkout deductions, review notifications, and reruns in `scripts/daily-tasks.js`.
- [X] T044 [US3] Block check-out-only manual review/approval consequences while disabled in `lib/services/attendance_service.dart`.
- [X] T045 [US3] Add disabled-period labels and suppress new check-out-only exports in `lib/services/sheets_export_service.dart`.

**Checkpoint**: A disabled policy creates no new check-out-only state through
the client, gateway, queue, automation, reminders, daily job, or exports.

---

## Phase 6: User Story 4 — Keep History and Payroll Auditable (Priority: P1)

**Goal**: Authorized HR/payroll users can distinguish disabled periods from
enabled history without rewriting prior attendance, deductions, or payroll.

**Independent Test**: Compare an enabled historical record, a disabled-period
attendance record, and a prior approved deduction. Confirm history is unchanged
and disabled periods are not labeled missing check-out.

### Tests for User Story 4

- [X] T046 [P] [US4] Add attendance-summary tests for historical enabled data and disabled-period labels in `test/services/dashboard_attendance_summary_service_test.dart`.
- [X] T047 [P] [US4] Add report/export tests for policy snapshot columns and no false missing-checkout labels in `test/services/sheets_export_service_checkout_policy_test.dart`.
- [X] T048 [P] [US4] Add historical no-recalculation and policy-transition tests in `test/permission_cycle_accounting_test.dart`.

### Implementation for User Story 4

- [X] T049 [US4] Surface policy snapshot/disabled-period display state without rewriting records in `lib/services/dashboard_attendance_summary_service.dart`.
- [X] T050 [US4] Render “لا ينطبق تسجيل الانصراف” for disabled periods and retain enabled-period checkout history in `lib/screens/hr/attendance_summary_details_screen.dart`.
- [X] T051 [US4] Preserve approved historic deduction presentation and distinguish policy-disabled periods in the HR/manager request views under `lib/screens/hr/` and `lib/screens/manager/`.
- [X] T052 [US4] Add policy revision/evaluation point to authorized export/report rows in `lib/services/sheets_export_service.dart`.

**Checkpoint**: Historical payroll evidence remains untouched and authorized
users can clearly distinguish policy-disabled attendance from a missed checkout.

---

## Phase 7: Polish and Cross-Cutting Verification

**Purpose**: Ensure safe language, no regression bypasses, and acceptance
coverage across the complete flow.

- [X] T053 [P] Add source-level regression coverage for every known checkout producer/consumer in `test/checkout_policy_inventory_test.dart`.
- [X] T054 [P] Add Arabic error-copy regression coverage preventing raw Firebase/Gateway details in `test/features/attendance_checkin/presentation/attendance_outcome_mapper_test.dart`.
- [X] T055 Run formatter, static analysis, focused Flutter tests, and Node test suite; record results in `specs/003-checkout-retirement/quickstart.md`.
- [ ] T056 Perform all non-production acceptance scenarios in `specs/003-checkout-retirement/quickstart.md` and record any exceptions there.
- [X] T057 Update role/operation documentation and deployment handoff notes in `specs/003-checkout-retirement/plan.md` without enabling policy or changing live Firestore data.

---

## Dependencies and Execution Order

```text
Phase 1 → Phase 2 → US1 / US2 → US3 → US4 → Phase 7
                         └──── shared policy contract ────┘
```

- Phase 2 blocks every story.
- US1 and US2 can proceed in parallel after Phase 2, but both should complete
  before US3 verifies the full employee-to-worker behavior.
- US4 depends on the policy snapshots and suppression behavior established in
  US3.
- Phase 7 follows all desired stories.

## Parallel Opportunities

- T002–T004 can run in parallel.
- T007–T009 can run in parallel, then T010–T016 follow in dependency order.
- Within US1: T017–T020 can run in parallel.
- Within US2: T025–T027 can run in parallel.
- Within US3: T033–T037 can run in parallel; T040–T042 affect different worker
  files after the shared resolver is ready.
- Within US4: T046–T048 can run in parallel.

## Implementation Strategy

1. Complete Phases 1–2 and verify only the default-off shared policy.
2. Deliver US1 and US2 on non-production data: requests remain available and
   HR can safely operate the switch.
3. Deliver US3 before enabling the switch anywhere; this closes stale-client,
   queue, automation, reminder, and payroll bypasses.
4. Deliver US4 and Phase 7, then obtain separate owner approval for any rules,
   deployment, data migration, or production policy action.
