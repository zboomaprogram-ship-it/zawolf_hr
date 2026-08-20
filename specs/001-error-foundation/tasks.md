# Tasks: Shared Error Foundation

**Input**: Design documents from `specs/001-error-foundation/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), and [operation-outcome.md](contracts/operation-outcome.md)

**Tests**: Required by FR-008 and the constitution. Test tasks are intentionally placed before their matching implementation tasks.

**Implementation gate**: Do not start T003 or later until the existing repository-wide Flutter failures are fixed in a separate focused change and `flutter analyze` plus `flutter test` are green. This feature does not include that unrelated repair.

## Phase 1: Setup and Baseline Gate

**Purpose**: Protect the live application and establish the red-green-refactor starting point.

- [x] T001 Record the current failing `flutter analyze` and `flutter test` baseline, including the two inherited failing tests, in `specs/001-error-foundation/quickstart.md`.
- [x] T002 Verify a separate focused maintenance change makes `flutter analyze`, `flutter test`, `flutter test test/architecture_guard_test.dart`, and `cd scripts && npm test` green before editing `lib/core/errors/`.

**Checkpoint**: The repository quality gate is green and this additive feature may begin. If it is not green, stop here.

---

## Phase 2: Foundational Error Contract

**Purpose**: Create the pure, provider-neutral foundation required by every story.

- [x] T003 Create the core error directory and public export convention in `lib/core/errors/` without changing `lib/utils/user_facing_error.dart` or any existing caller.
- [x] T004 [P] Define the nine-category `FailureCategory` value type in `lib/core/errors/failure_category.dart` according to `specs/001-error-foundation/data-model.md`.
- [x] T005 [P] Define `RecoveryGuidance` and its safe retry semantics in `lib/core/errors/recovery_guidance.dart` according to `specs/001-error-foundation/contracts/operation-outcome.md`.
- [x] T006 Define the immutable provider-neutral `AppFailure`, including outcome certainty and validation of safe diagnostic context, in `lib/core/errors/app_failure.dart`.
- [x] T007 Define the sealed/generic confirmed-success-or-failure `OperationResult<T>` contract in `lib/core/errors/operation_result.dart`.

**Checkpoint**: No core file imports Firebase, Firestore, HTTP, Flutter presentation APIs, Provider, BLoC, storage, or a provider exception type. No legacy path is changed.

---

## Phase 3: User Story 1 - Receive a Clear Action Message (Priority: P1) 🎯 MVP

**Goal**: Every adopted failure can be converted into consistent Arabic user guidance without exposing raw technical information.

**Independent Test**: Construct a failure for each category and prove the returned Arabic content provides a safe next action without provider codes, exception text, stack traces, credentials, IDs, or authorization details.

### Tests for User Story 1

- [x] T008 [P] [US1] Write red unit tests for Arabic messages for access, authentication/session, validation, connectivity, temporary service, capacity/quota, conflict/duplicate, missing data, and unexpected failures in `test/core/errors/user_safe_failure_message_test.dart`.
- [x] T009 [P] [US1] Write red safety tests that assert messages never render raw exception identifiers, stack text, credentials, employee identifiers, Firestore paths, or authorization-rule details in `test/core/errors/user_safe_failure_message_test.dart`.

### Implementation for User Story 1

- [x] T010 [US1] Implement the pure Arabic `UserSafeFailureMessage` value and category/recovery policy with a conservative fallback in `lib/core/errors/user_safe_failure_message.dart`.
- [x] T011 [US1] Run `flutter test test/core/errors/user_safe_failure_message_test.dart` and refactor only while the focused test stays green.

**Checkpoint**: User Story 1 is independently testable; no UI or provider-specific error text has been changed.

---

## Phase 4: User Story 2 - Preserve Operational Safety (Priority: P1)

**Goal**: Callers can distinguish confirmed non-completion, unknown write outcome, and duplicate/conflict so unsafe repeat actions are prevented.

**Independent Test**: Construct validation/access, interrupted write, and duplicate failures and prove that each has its required certainty and recovery behavior.

### Tests for User Story 2

- [x] T012 [P] [US2] Write red unit tests for confirmed success and structured failure variants of `OperationResult<T>` in `test/core/errors/operation_result_test.dart`.
- [x] T013 [P] [US2] Write red unit tests for `confirmedNotCompleted` versus `unknown`, including the rule that unknown write outcomes require `checkStatusBeforeRetry`, in `test/core/errors/app_failure_test.dart`.
- [x] T014 [P] [US2] Write red duplicate/conflict and invalid-recovery-combination tests in `test/core/errors/app_failure_test.dart`.

### Implementation for User Story 2

- [x] T015 [US2] Complete `AppFailure` validation and outcome-certainty/recovery invariants in `lib/core/errors/app_failure.dart`.
- [x] T016 [US2] Complete `OperationResult<T>` success/failure ergonomics without accepting raw provider errors in `lib/core/errors/operation_result.dart`.
- [x] T017 [US2] Run `flutter test test/core/errors/operation_result_test.dart test/core/errors/app_failure_test.dart` and refactor only while the focused tests stay green.

**Checkpoint**: Unknown write outcomes cannot be presented as confirmed success or automatically retried through the new contract.

---

## Phase 5: User Story 3 - Migrate Safely Over Time (Priority: P2)

**Goal**: The foundation is available to future migrations while all unselected legacy workflows retain their current routes and behavior.

**Independent Test**: Compile the core package and prove its public API contains no concrete provider imports; confirm the legacy error utility and its callers were not modified by this feature.

### Tests for User Story 3

- [x] T018 [P] [US3] Add static architecture assertions that reject Firebase, Firestore, HTTP, Provider, BLoC, storage, and Flutter widget imports from `lib/core/errors/` in `test/architecture_guard_test.dart`.
- [x] T019 [P] [US3] Add a regression assertion that this feature does not alter `lib/utils/user_facing_error.dart` or direct existing call sites in `test/architecture_guard_test.dart`.

### Implementation for User Story 3

- [x] T020 [US3] Export the stable provider-neutral public surface from `lib/core/errors/` using only the files defined in `specs/001-error-foundation/contracts/operation-outcome.md`.
- [x] T021 [US3] Update usage notes for the deferred Auth data-adapter/Cubit pilot in `specs/001-error-foundation/quickstart.md` without modifying an Auth workflow.
- [x] T022 [US3] Run `flutter test test/architecture_guard_test.dart test/core/errors` and verify `git diff -- lib/utils/user_facing_error.dart lib/screens lib/services` has no change belonging to this feature.

**Checkpoint**: The foundation is available for future use but no legacy behavior has been migrated or switched.

---

## Phase 6: Polish and Release Evidence

**Purpose**: Validate the additive foundation and document that it is not a production workflow switch.

- [x] T023 [P] Format the new core and test files with `dart format lib/core/errors test/core/errors`.
- [x] T024 Run all commands in `specs/001-error-foundation/quickstart.md` and record the final green results in `specs/001-error-foundation/quickstart.md`.
- [x] T025 Verify `git diff --check` and confirm no Firestore rules, Firebase configuration, payroll/attendance code, routing, screens, legacy services, or Hostinger scripts changed for this feature.
- [x] T026 Document the follow-up Auth pilot as a separate spec/plan/tasks lifecycle in `specs/001-error-foundation/quickstart.md`; do not implement it here.

## Dependencies and Execution Order

```text
T001 -> T002 (hard repository gate)
T002 -> T003 -> T004/T005 -> T006 -> T007
T004/T005/T006/T007 -> T008/T009 -> T010 -> T011      (US1)
T006/T007 -> T012/T013/T014 -> T015/T016 -> T017      (US2)
T003 -> T018/T019 -> T020/T021 -> T022                (US3)
US1 + US2 + US3 -> T023/T024/T025/T026
```

- **US1** depends on the foundational contract and delivers the MVP: Arabic-safe guidance.
- **US2** depends on the foundational contract and may proceed after Phase 2; it can be developed alongside US1 once shared type shapes are stable.
- **US3** depends only on the directory/public-surface decision and may proceed alongside US1/US2 after Phase 2.
- No task in this feature authorizes a consumer migration, production rule change, data migration, or default-route switch.

## Parallel Opportunities

- T004 and T005 touch different pure value files.
- T008 and T009 are separate test concerns but must agree on the public message API before T010.
- T012, T013, and T014 can be written in parallel against the agreed contract.
- T018 and T019 can be developed in the same guard test file only sequentially in a single worktree; they are conceptually independent but should not be edited concurrently in one checkout.
- After T007, US1, US2, and US3 may be assigned to different developers if they coordinate the immutable public API first.

## Implementation Strategy

### MVP first

1. Satisfy the external quality gate (T001-T002).
2. Build the pure contract (T003-T007).
3. Complete US1 (T008-T011) and validate Arabic-safe messages.
4. Stop and demonstrate the foundation without changing any live workflow.

### Incremental delivery

1. US1 establishes safe text.
2. US2 adds material-operation retry safety.
3. US3 locks in migration compatibility and boundary regression protection.
4. A future Auth vertical slice adopts the contract through its own reviewed lifecycle.

## Format Validation

All 26 tasks use the required checkbox, sequential ID, optional parallel marker, user-story label for story work, and explicit repository path format.
