# Tasks — Work Regulations Enforcement

## Phase 1 — Characterization and policy primitives

- [X] T001 Add boundary characterization tests for scheduled-start and prior-check-in late-arrival requests in `test/services/permission_service_regulation_test.dart`.
- [X] T002 [P] Add advance tenure, calendar-day, salary-cap, and no-write characterization tests in `test/services/advance_service_regulation_test.dart`.
- [X] T003 [P] Add leave type, duration, evidence, and conversion serialization tests in `test/leave_request_policy_test.dart`.
- [X] T004 Add full-year quota boundary tests in `test/leave_entitlement_policy_test.dart` and `scripts/test/daily-tasks-entitlement.test.js`.

## Phase 2 — Shared policy implementation

- [X] T005 Add full-year service/age quota calculation to `lib/models/leave_entitlement_policy.dart`.
- [X] T006 Add birth-leave metadata and balance behavior to `lib/models/leave_type_policy.dart`.
- [X] T007 Add optional sick-to-annual conversion serialization to `lib/models/leave_model.dart`.

## Phase 3 — User Story 1: late-arrival and advances

- [X] T008 [US1] Enforce scheduled-start and deterministic check-in guards in `lib/services/permission_service.dart`.
- [X] T009 [P] [US1] Add late-arrival eligibility feedback to `lib/screens/employee/employee_requests.dart`.
- [X] T010 [US1] Enforce advance tenure, monthly-window, and half-salary constraints in `lib/services/advance_service.dart`.
- [X] T011 [P] [US1] Display advance eligibility and maximum amount in `lib/screens/employee/employee_requests.dart`.

## Phase 4 — User Story 2: regulated leave

- [X] T012 [US2] Enforce casual, birth, exam, and conversion validation in `lib/services/leave_service.dart`.
- [X] T013 [US2] Add birth leave, exam proof, casual range, and sick-conversion controls to `lib/screens/employee/employee_requests.dart`.
- [X] T014 [P] [US2] Display birth leave and annual-conversion status in `lib/screens/manager/requests_mgmt.dart`.

## Phase 5 — User Story 3: entitlement renewal

- [X] T015 [US3] Apply dynamic annual quota reconciliation in `scripts/daily-tasks.js`.
- [X] T016 [US3] Preserve balance and closed-cycle semantics in `scripts/test/daily-tasks-entitlement.test.js`.

## Phase 6 — Verification and release

- [X] T017 Run `flutter analyze`, architecture/query guards, focused Flutter tests, `flutter test`, and `(cd scripts && npm test)`.
- [ ] T018 Verify Arabic RTL, iOS, Android, web, Cairo date boundaries, duplicate approvals, and policy-denied request creation on a non-production account.
