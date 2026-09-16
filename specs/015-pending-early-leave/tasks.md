# Tasks: Pending Early-Leave Checkout

**Input**: Design documents from `specs/015-pending-early-leave/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/early-leave-checkout-api.md`, `quickstart.md`

**Tests**: Attendance and payroll are critical behavior. Characterization and
failing tests must be written before implementation, then kept green throughout.

**Organization**: Tasks are grouped by user story so each increment can be
implemented and validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches independent files and has no
  dependency on another incomplete task in the same phase.
- **[Story]**: Maps the task to a user story in `spec.md`.
- Every task names the exact target file or directory.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the additive feature slice and disabled rollout controls
without changing live checkout behavior.

- [x] T001 Create the feature-first directories and barrel export under `lib/features/pending_early_leave/` and `lib/features/pending_early_leave/pending_early_leave.dart`
- [x] T002 [P] Register the disabled-by-default `pending_early_leave_checkout_v1` attendance flag in `scripts/feature-flags.js` and add evaluator coverage in `scripts/test/feature-flags.test.js`
- [x] T003 [P] Document the disabled rollout value, Hostinger ownership, and rollback switch in `scripts/HOSTINGER_DEPLOYMENT.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Characterize current behavior and add shared domain contracts before
any user-story implementation.

**⚠️ CRITICAL**: No user story implementation starts until these tests exist and
the shared domain boundary is ready.

- [x] T004 [P] Add characterization tests for approved early-leave checkout selection, deterministic tie-breaking, and normal scheduled checkout in `test/services/attendance_service_checkout_test.dart`
- [x] T005 [P] Add characterization tests for checkout policy, duplicate checkout, stale-event replay, and preservation of existing deduction fields in `scripts/test/attendance-gateway.test.js`
- [x] T006 [P] Add characterization tests proving pending/rejected permission deductions are excluded and approved existing deductions are included in `test/services/payroll_service_test.dart` and `scripts/test/monthly-tasks.test.js`
- [x] T007 Define request state, eligibility, evidence, and consequence value objects in `lib/features/pending_early_leave/domain/early_leave_checkout_eligibility.dart` and `lib/features/pending_early_leave/domain/early_leave_rejection_consequence.dart`
- [x] T008 Define the focused watch/refresh contract in `lib/features/pending_early_leave/domain/early_leave_checkout_repository.dart`
- [x] T009 [P] Define the pure quarter-day-per-hour calculation and validation API in `lib/features/pending_early_leave/domain/early_leave_deduction_policy.dart`
- [x] T010 Define additive Firestore/API decoding with explicit unknown and conflict states in `lib/features/pending_early_leave/data/early_leave_checkout_wire_model.dart`

**Checkpoint**: Existing behavior is locked down and the domain/data boundary is
ready without changing the employee experience.

---

## Phase 3: User Story 1 - Checkout While Approval Is Pending (Priority: P1) 🎯 MVP

**Goal**: A checked-in employee sees checkout at the requested time for a valid
same-day pending request and sees the exact warning before confirming.

**Independent Test**: Keep a two-hour request pending for a 17:00 schedule, leave
the dashboard open, advance to 15:00, and verify checkout appears within five
seconds with a 0.50-day Arabic warning; cancelling writes nothing.

### Tests for User Story 1

> Write these tests first and verify the new cases fail before implementation.

- [x] T011 [P] [US1] Add failing one-to-four-hour calculation, state-label, and deterministic-selection tests in `test/features/pending_early_leave/early_leave_deduction_policy_test.dart`
- [x] T012 [P] [US1] Add failing repository tests for same-user/date/type filtering, status updates, multiple requests, and validation failure in `test/features/pending_early_leave/early_leave_checkout_repository_test.dart`
- [x] T013 [P] [US1] Add failing Cubit/widget tests for live clock transition, pending warning, cancellation, RTL, and preserved data during refresh in `test/features/pending_early_leave/early_leave_checkout_cubit_test.dart` and `test/screens/employee/employee_dashboard_gate_test.dart`
- [x] T014 [P] [US1] Add failing server contract tests for owner/date/type/status/time validation and immutable checkout evidence in `scripts/test/attendance-gateway.test.js`
- [x] T015 [P] [US1] Add failing offline serialization/replay tests for stable event ID and exact permission ID in `test/services/offline_attendance_queue_service_test.dart`

### Implementation for User Story 1

- [x] T016 [US1] Implement the pure eligibility and quarter-day calculation rules in `lib/features/pending_early_leave/domain/early_leave_checkout_eligibility.dart` and `lib/features/pending_early_leave/domain/early_leave_deduction_policy.dart`
- [x] T017 [US1] Implement the bounded same-user/current-Cairo-date Firestore watch with deterministic request selection and feature-flag fallback in `lib/features/pending_early_leave/data/early_leave_checkout_repository_impl.dart`
- [x] T018 [US1] Implement focused loading, ready, error, stale-cache, and request-state transitions in `lib/features/pending_early_leave/presentation/early_leave_checkout_state.dart` and `lib/features/pending_early_leave/presentation/early_leave_checkout_cubit.dart`
- [x] T019 [US1] Build the accessible Arabic RTL pending/rejected/approved hint and exact-fraction confirmation content in `lib/features/pending_early_leave/presentation/early_leave_checkout_hint.dart`
- [x] T020 [US1] Integrate the Cubit and confirmation hint at the existing checkout seam without replacing unrelated dashboard state in `lib/screens/employee/employee_dashboard.dart` and `lib/screens/employee/checkin_confirm_modal.dart`
- [x] T021 [US1] Persist `eventId` and `earlyLeavePermissionId` through queue JSON and gateway payload replay in `lib/services/offline_attendance_queue_service.dart`
- [x] T022 [US1] Extend the authenticated client contract and map the new safe error codes in `lib/services/attendance_gateway_service.dart`
- [x] T023 [US1] Implement server-side request ownership, Cairo-date, schedule, status, duration, and earliest-time validation plus transactional evidence writing in `scripts/attendance-gateway.js`
- [x] T024 [US1] Wire the extended attendance action response and safe HTTP status mapping in `scripts/notification-web.js`
- [x] T025 [US1] Add privacy-safe counters for accepted, too-early, invalid, unavailable, and duplicate early checkouts in `scripts/attendance-gateway.js`

**Checkpoint**: Pending checkout works end-to-end behind the feature flag, while
normal checkout, global disablement, and invalid/unavailable requests fail safe.

---

## Phase 4: User Story 2 - Rejected Request Produces a Reviewable Deduction (Priority: P1)

**Goal**: A used early checkout followed or preceded by rejection creates exactly
one correctly calculated consequence for HR review, with no payroll impact yet.

**Independent Test**: Use a two-hour early checkout, reject the linked request,
replay checkout and reconciliation ten times, and verify one 0.50-day pending-HR
consequence with complete evidence and zero payroll/discipline impact.

### Tests for User Story 2

> Write these tests first and verify the new cases fail before implementation.

- [x] T026 [P] [US2] Add failing projector tests for both event orderings, no-checkout rejection, normal-end checkout, retries, unrelated deductions, and one-to-four-hour fractions in `scripts/test/early-leave-reconciliation.test.js`
- [x] T027 [P] [US2] Add failing API authorization and semantic-result tests for reconcile and HR review endpoints in `scripts/test/early-leave-reconciliation-router.test.js`
- [x] T028 [P] [US2] Add failing employee detail tests for requested time, actual checkout, rejection reason, fraction, amount, and review state in `test/services/employee_deduction_service_test.dart`
- [x] T029 [P] [US2] Add failing HR queue tests for independent review without overwriting attendance deductions in `test/screens/manager/requests_mgmt_early_leave_deduction_test.dart`
- [x] T030 [P] [US2] Add failing Dart and Node payroll tests proving pending/rejected consequences have zero impact and only HR-approved consequences count in `test/services/payroll_service_test.dart` and `scripts/test/monthly-tasks.test.js`

### Implementation for User Story 2

- [x] T031 [US2] Implement the idempotent consequence projector and deterministic identity in `scripts/early-leave-reconciliation.js`
- [x] T032 [US2] Project a pending-HR consequence in the checkout transaction when the request is already rejected in `scripts/attendance-gateway.js`
- [x] T033 [US2] Add authenticated reconcile and consequence-review handlers with reviewer authorization and audit writes in `scripts/notification-web.js`
- [x] T034 [US2] Mark post-checkout decisions for repair and call immediate reconciliation after rejection in `lib/services/permission_service.dart` and `lib/services/attendance_gateway_service.dart`
- [x] T035 [US2] Add the bounded Hostinger recovery query, cursor, lease, and safe counters in `scripts/early-leave-reconciliation.js` and schedule it from `scripts/notification-web.js`
- [x] T036 [US2] Decode nested consequence data without changing legacy permission semantics in `lib/models/permission_model.dart` and `lib/features/pending_early_leave/data/early_leave_checkout_wire_model.dart`
- [x] T037 [US2] Add rejected-early-leave consequences to employee deduction details and keep other sources independent in `lib/services/employee_deduction_service.dart`
- [x] T038 [US2] Add a distinct rejected-early-leave queue and approve/reject actions to the existing HR review surface in `lib/screens/manager/requests_mgmt.dart`
- [x] T039 [US2] Include only HR-approved rejection consequences in interactive payroll calculations in `lib/services/payroll_service.dart`
- [x] T040 [US2] Include only HR-approved rejection consequences in cycle-close payroll calculations and pending counts in `scripts/monthly-tasks.js`
- [x] T041 [US2] Send deterministic HR-review and employee-decision notifications with exact deep links in `scripts/early-leave-reconciliation.js` and `lib/models/notification_route_policy.dart`

**Checkpoint**: Rejected used requests create one independently reviewable
consequence; unused requests create none; payroll remains unchanged before HR
approval.

---

## Phase 5: User Story 3 - Approval Removes the Financial Consequence (Priority: P2)

**Goal**: Final approval authorizes the linked checkout and removes only its
matching provisional consequence, including delayed approval and retry cases.

**Independent Test**: Check out while pending, approve later, replay approval and
repair ten times, and verify no rejection consequence remains while an unrelated
late/missed-checkout deduction is unchanged.

### Tests for User Story 3

> Write these tests first and verify the new cases fail before implementation.

- [x] T042 [P] [US3] Add failing approval-after-checkout, repeated approval, unrelated deduction, and finalized-cycle tests in `scripts/test/early-leave-reconciliation.test.js`
- [x] T043 [P] [US3] Add failing client reconciliation tests for approved requests and live warning-state updates in `test/services/attendance_reconciliation_service_test.dart` and `test/features/pending_early_leave/early_leave_checkout_cubit_test.dart`

### Implementation for User Story 3

- [x] T044 [US3] Make approved-request projection mark only the matching rejection consequence not applicable while preserving unrelated attendance fields in `scripts/early-leave-reconciliation.js`
- [x] T045 [US3] Invoke idempotent server reconciliation after final permission approval without changing existing quota accounting in `lib/services/permission_service.dart` and `lib/services/attendance_gateway_service.dart`
- [x] T046 [US3] Keep the legacy approved-permission attendance reconciliation compatible with linked evidence in `lib/services/attendance_reconciliation_service.dart`
- [x] T047 [US3] Update the open dashboard immediately from pending/rejected warning to approved authorization in `lib/features/pending_early_leave/presentation/early_leave_checkout_cubit.dart` and `lib/features/pending_early_leave/presentation/early_leave_checkout_hint.dart`

**Checkpoint**: Approval always produces zero rejection-based financial impact
and cannot erase another attendance consequence.

---

## Phase 6: Polish, Safety, and Rollout

**Purpose**: Validate the complete distributed flow, read budget, compatibility,
observability, and reversible production rollout.

- [x] T048 [P] Add architecture/query guard fixtures for the feature slice and bounded Firestore watch in `test/architecture_guard_test.dart` and `test/firestore_query_guard_test.dart`
- [x] T049 [P] Add Arabic employee-guide text explaining pending checkout, rejection consequences, and HR review in `docs/employee_guide_ar.md`
- [x] T050 Run every manual scenario and record results in `specs/015-pending-early-leave/quickstart.md`
- [x] T051 Run `dart format`, `flutter analyze`, architecture/query guards, the full Flutter suite, and `(cd scripts && npm test)`, fixing only failures caused by this feature
- [ ] T052 Build the Hostinger deployment ZIP with server support disabled and document checksum/release contents in `scripts/HOSTINGER_DEPLOYMENT.md`
- [ ] T053 Deploy server support before the mobile flag, enable a pilot audience, verify safe counters and rollback, then record production evidence in `specs/015-pending-early-leave/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Starts immediately and changes no live behavior.
- **Foundational (Phase 2)**: Depends on setup and blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on the foundation; delivers the flagged MVP.
- **User Story 2 (Phase 4)**: Depends on US1 checkout evidence and gateway contract.
- **User Story 3 (Phase 5)**: Depends on the US2 projector but is independently
  verified through approval scenarios.
- **Polish/Rollout (Phase 6)**: Depends on all selected stories and requires the
  full validation suite before any production enablement.

### User Story Dependencies

- **US1** owns eligibility, the warning, request-bound event transport, and
  authoritative checkout evidence.
- **US2** consumes US1 evidence to create and review a rejected-request
  consequence; it never changes US1's eligibility contract.
- **US3** consumes the same evidence/projector to authorize approval and remove
  only the matching consequence.

### Within Each User Story

- Write the listed tests first and confirm the new cases fail.
- Implement domain/model changes before repository/service changes.
- Implement server authority before enabling the presentation path.
- Keep the feature flag disabled until the story's checkpoint passes.
- Commit by logical task group without staging unrelated worktree changes.

### Parallel Opportunities

- T002 and T003 can run in parallel after T001.
- T004–T006 can run in parallel; T009 can proceed alongside T007–T008.
- T011–T015 can run in parallel before US1 implementation.
- T026–T030 can run in parallel before US2 implementation.
- T042 and T043 can run in parallel before US3 implementation.
- T048 and T049 can run in parallel after all story implementations.

## Parallel Example: User Story 1

```text
Task T011: Pure policy and deterministic selection tests.
Task T012: Repository filtering and stream tests.
Task T013: Cubit, clock, warning, cancellation, and RTL tests.
Task T014: Node gateway contract/security tests.
Task T015: Offline serialization and replay tests.
```

## Parallel Example: User Story 2

```text
Task T026: Idempotent projector tests.
Task T027: Reconcile/review endpoint tests.
Task T028: Employee deduction details tests.
Task T029: HR review queue tests.
Task T030: Dart and Node payroll exclusion/inclusion tests.
```

## Implementation Strategy

### MVP First

1. Complete setup and foundational characterization.
2. Complete US1 behind `pending_early_leave_checkout_v1`.
3. Keep the flag disabled until authoritative gateway validation and offline
   replay tests pass.
4. Validate the pending warning and cancellation independently.

US1 is a technical MVP only. Production-wide enablement waits for US2 because
the approved business rule requires the rejection consequence.

### Incremental Delivery

1. Ship disabled server compatibility and evidence support.
2. Add US1 client eligibility and warnings for a pilot audience.
3. Add US2 consequence review and payroll governance.
4. Add US3 approval reconciliation.
5. Run full distributed validation, then enable broadly.

### Rollback

Disable `pending_early_leave_checkout_v1` and the Hostinger recovery worker.
Existing scheduled checkout and approved early-leave behavior resumes. Do not
delete evidence or reviewed consequences; retain them for audit and follow the
existing closed-cycle adjustment policy.

## Notes

- Do not deploy Firestore rules or run a production backfill in this feature.
- Do not reopen finalized payroll cycles.
- Hostinger is the sole live reconciliation scheduler; GitHub remains recovery.
- No task may overwrite the attendance row's existing flat deduction fields.
- Stop for owner review after this task list before implementation.
