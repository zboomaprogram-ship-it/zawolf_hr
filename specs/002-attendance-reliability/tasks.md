# Tasks: Check-in Reliability Pilot

**Input**: Design documents from `specs/002-attendance-reliability/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/checkin-outcome-contract.md`, and `quickstart.md`

**Scope guard**: These tasks change **employee check-in only**. The existing
check-out route, messages, queue, and business rules remain untouched.

**Tests**: Required by the approved specification. Write each listed test first
and confirm it fails for the missing behavior before implementing the matching
task.

## Phase 1: Setup

**Purpose**: Create an isolated, reversible pilot foundation.

- [X] T001 Add the approved `flutter_bloc`, Drift runtime, and Drift build dependencies to `pubspec.yaml`, then regenerate `pubspec.lock` with Flutter tooling.
- [X] T002 Create the documented feature-spec bridge in `specs/attendance_checkin/README.md` that points to the canonical `specs/002-attendance-reliability/` documents required by `test/architecture_guard_test.dart`.
- [X] T003 [P] Create the empty feature-first directory structure and feature export in `lib/features/attendance_checkin/{data/{local,remote},domain/{entities,repositories,usecases},presentation/{cubit,widgets}}/` and `lib/features/attendance_checkin/attendance_checkin.dart`.

---

## Phase 2: Foundational safeguards

**Purpose**: Characterize the current contract and create shared boundaries that block unsafe regressions.

**⚠️ CRITICAL**: Complete this phase before routing any employee check-in through the pilot.

- [X] T004 [P] Add characterization coverage for the legacy deterministic check-in identity, Cairo execution date, and check-out non-interference in `test/services/attendance_service_checkin_characterization_test.dart`.
- [X] T005 [P] Add authenticated Node contract tests for the existing check-in `recorded` and `already_recorded` receipts in `scripts/test/attendance-gateway.test.js`.
- [X] T006 [P] Extend `test/architecture_guard_test.dart` so `lib/features/attendance_checkin/presentation/` cannot import `lib/services/`, Firebase, HTTP, Drift, or data-layer files.
- [X] T007 Define framework-independent `CheckInAction`, `CheckInReceipt`, `PendingCheckIn`, `CheckInStatusResolution`, and `CheckInPresentationState` entities in `lib/features/attendance_checkin/domain/entities/` according to `data-model.md` and `contracts/checkin-outcome-contract.md`.
- [X] T008 Define the portable `AttendanceCheckInRepository` contract and focused use cases in `lib/features/attendance_checkin/domain/repositories/attendance_checkin_repository.dart` and `lib/features/attendance_checkin/domain/usecases/` using `OperationResult` and `AppFailure`, not Firebase or HTTP types.
- [X] T009 Create the account-scoped local outbox interface and Drift schema/database in `lib/features/attendance_checkin/data/local/checkin_outbox.dart` and `lib/features/attendance_checkin/data/local/checkin_outbox_database.dart`; generate the required `*.g.dart` file without changing `lib/services/offline_attendance_queue_service.dart`.

**Checkpoint**: The legacy contract is characterized, the new slice has no forbidden dependencies, and no production behavior has changed.

---

## Phase 3: User Story 1 — Complete a reliable check-in (Priority: P1) 🎯 MVP

**Goal**: An eligible employee receives an Arabic saved state for a single canonical check-in; a duplicate resolves as saved without another event.

**Independent Test**: Submit a valid action, then repeat the same deterministic action. Verify one attendance event and saved Arabic feedback both times.

### Tests for User Story 1

- [X] T010 [P] [US1] Add domain tests for deterministic action identity, `recorded`, and `alreadyRecorded` semantics in `test/features/attendance_checkin/domain/checkin_action_test.dart`.
- [X] T011 [P] [US1] Add data tests that parse current gateway submit receipts into domain outcomes in `test/features/attendance_checkin/data/attendance_gateway_checkin_client_test.dart`.
- [X] T012 [P] [US1] Add Cubit tests for submitting, saved, and duplicate-saved states in `test/features/attendance_checkin/presentation/checkin_cubit_test.dart`.

### Implementation for User Story 1

- [X] T013 [US1] Add receipt parsing and authenticated submit adapter behavior to `lib/features/attendance_checkin/data/remote/attendance_gateway_checkin_client.dart`, preserving the canonical check-in payload and date/identity rules used by `lib/services/attendance_service.dart`.
- [X] T014 [US1] Implement `AttendanceCheckInRepositoryImpl` in `lib/features/attendance_checkin/data/attendance_checkin_repository_impl.dart` so confirmed `recorded` and `already_recorded` responses return structured success and clear a matching pending item.
- [X] T015 [US1] Implement a focused `CheckInCubit` and immutable state in `lib/features/attendance_checkin/presentation/cubit/checkin_cubit.dart` and `lib/features/attendance_checkin/presentation/cubit/checkin_state.dart`; keep it below 300 lines and consume only domain contracts.
- [X] T016 [US1] Implement the Arabic saved/duplicate-safe feedback widget in `lib/features/attendance_checkin/presentation/widgets/checkin_status_feedback.dart` without exposing infrastructure text.
- [X] T017 [US1] Add a guarded, default-off check-in pilot seam in `lib/screens/employee/employee_dashboard.dart` that routes only the manual **check-in** action to the new presentation boundary; leave every check-out branch on the legacy service.

**Checkpoint**: With the pilot explicitly enabled for a test account, normal and duplicate check-ins are independently demonstrable. Check-out has the same characterization behavior as before.

---

## Phase 4: User Story 2 — Continue safely through a temporary outage (Priority: P1)

**Goal**: A valid action survives temporary connectivity/service failures as saved, pending synchronization, or needs-status-check, without duplicate attendance.

**Independent Test**: Simulate offline-before-send, retryable temporary failure, and lost confirmation after the gateway writes; prove each action reaches exactly one permitted final outcome.

### Tests for User Story 2

- [X] T018 [P] [US2] Add outbox persistence and employee-account isolation tests in `test/features/attendance_checkin/data/checkin_outbox_test.dart`.
- [X] T019 [P] [US2] Add repository tests for two bounded retries, pending persistence, replay idempotency, and no retry after a confirmed failure in `test/features/attendance_checkin/data/attendance_checkin_repository_test.dart`.
- [X] T020 [P] [US2] Add gateway status-resolution contract tests, including actor ownership and absent records, in `scripts/test/attendance-gateway.test.js`.
- [X] T021 [P] [US2] Add Cubit tests for pending-sync, requires-status-check, recovery on return, and preventing a second submission while a status check is required in `test/features/attendance_checkin/presentation/checkin_cubit_test.dart`.

### Implementation for User Story 2

- [X] T022 [US2] Add the authenticated, actor-owned check-in status resolver to `scripts/attendance-gateway.js` and wire a narrowly scoped status endpoint in `scripts/notification-web.js`; return only the semantic status in the approved contract.
- [X] T023 [US2] Implement status resolution parsing in `lib/features/attendance_checkin/data/remote/attendance_gateway_checkin_client.dart` using the same domain receipt/status contract as a future company API.
- [X] T024 [US2] Implement bounded retry (maximum two retries), uncertainty handling, and outbox replay in `lib/features/attendance_checkin/data/attendance_checkin_repository_impl.dart`; retain original timestamp/action ID and never retry access, authentication, or validation failures.
- [X] T025 [US2] Implement account-scoped pending synchronization on explicit check-in screen entry and explicit retry in `lib/features/attendance_checkin/domain/usecases/synchronize_pending_checkin.dart` and `lib/features/attendance_checkin/presentation/cubit/checkin_cubit.dart`; add no listener, timer, or uncontrolled polling.
- [X] T026 [US2] Show distinct Arabic pending-sync and needs-status-check states with a disabled duplicate-prone action in `lib/features/attendance_checkin/presentation/widgets/checkin_status_feedback.dart` and the pilot section of `lib/screens/employee/employee_dashboard.dart`.

**Checkpoint**: An eligible action survives an outage without false success or duplicate check-in; changing accounts cannot expose or submit another employee’s pending action.

---

## Phase 5: User Story 3 — Receive actionable Arabic guidance (Priority: P1)

**Goal**: Employees receive concise Arabic next steps and never see provider, Firebase, HTTP, permission-rule, or exception text.

**Independent Test**: Trigger access denied, expired session, invalid attendance condition, temporary outage, and an unknown failure. Assert Arabic actionable text with no technical identifiers.

### Tests for User Story 3

- [X] T027 [P] [US3] Add failure-mapping tests for access, authentication, validation, temporary service, connectivity, and unknown outcomes in `test/features/attendance_checkin/data/attendance_checkin_failure_mapper_test.dart`.
- [X] T028 [P] [US3] Add widget tests that assert Arabic saved/pending/status-check/failure text and reject raw Firebase/HTTP/exception fragments in `test/features/attendance_checkin/presentation/checkin_status_feedback_test.dart`.
- [X] T029 [P] [US3] Add employee dashboard pilot tests for permission-denied, unavailable, duplicate check-in, and interrupted submission in `test/screens/employee/employee_dashboard_checkin_pilot_test.dart`.

### Implementation for User Story 3

- [X] T030 [US3] Implement provider-to-`AppFailure` classification and restricted diagnostic capture in `lib/features/attendance_checkin/data/attendance_checkin_failure_mapper.dart`, reusing `lib/core/errors/` rather than string matching in presentation.
- [X] T031 [US3] Centralize approved Arabic check-in outcome text and next actions in `lib/features/attendance_checkin/presentation/widgets/checkin_status_feedback.dart`, including “تم الحفظ”، “بانتظار المزامنة”، و“تحقق من حالة الطلب”.
- [X] T032 [US3] Replace only check-in pilot error presentation in `lib/screens/employee/employee_dashboard.dart` with the structured Arabic feedback flow; preserve current check-out messages and behavior.

**Checkpoint**: Every covered pilot result is safe Arabic guidance; no raw Firebase/provider text can reach employees.

---

## Phase 6: User Story 4 — Preserve check-in business rules during migration (Priority: P2)

**Goal**: The reliability pilot preserves attendance policy, late-permission reconciliation, deductions, and payroll-cycle allocation while remaining portable to a future company service.

**Independent Test**: Run legacy and pilot characterization scenarios for valid/duplicate check-in and delayed permission reconciliation, then verify matching attendance/policy outcomes and no check-out change.

### Tests for User Story 4

- [X] T033 [P] [US4] Add regression tests for deterministic daily identity, location/device payload preservation, and legacy check-out non-interference in `test/services/attendance_service_checkin_characterization_test.dart`.
- [X] T034 [P] [US4] Add execution-date versus approval-date payroll/permission regression coverage in `scripts/test/payroll-cycle.test.js` without changing payroll implementation.
- [X] T035 [P] [US4] Add repository contract tests using a substitute fake service adapter in `test/features/attendance_checkin/data/attendance_checkin_repository_contract_test.dart` to prove presentation/domain outcomes do not depend on Firebase.

### Implementation for User Story 4

- [X] T036 [US4] Compare and document the pilot payload against legacy check-in construction in `lib/features/attendance_checkin/data/remote/attendance_gateway_checkin_client.dart` and `specs/002-attendance-reliability/quickstart.md`; preserve Cairo date, device, location, and late-permission fields.
- [X] T037 [US4] Add pilot observability counters for saved, pending, status-check, and safe-failure outcomes in `lib/features/attendance_checkin/data/attendance_checkin_repository_impl.dart` without persisting raw employee-facing diagnostics or adding Firestore listeners.
- [X] T038 [US4] Document the pilot enable/disable and non-destructive rollback procedure in `specs/002-attendance-reliability/quickstart.md`, explicitly stating that disabling the seam returns new check-ins to legacy without deleting pending pilot records.

**Checkpoint**: The pilot can be disabled cleanly, business-rule regressions are covered, and a future API adapter can replace the current gateway behind the repository contract.

---

## Phase 7: Polish and release evidence

**Purpose**: Verify the slice, keep rollout guarded, and do not deploy or change production rules without separate authorization.

- [X] T039 [P] Run `dart format` on modified Dart files and update only relevant generated Drift files.
- [X] T040 Run `flutter analyze`, `flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart`, `flutter test test/features/attendance_checkin`, and `flutter test`; resolve only pilot-caused failures. (Completed 2026-08-20: analysis clean; architecture/query guards, feature suite, and complete Flutter suite passed.)
- [X] T041 Run `(cd scripts && npm test)` and capture the check-in gateway contract results in `specs/002-attendance-reliability/quickstart.md`.
- [ ] T042 Perform the non-production validation matrix from `specs/002-attendance-reliability/quickstart.md` with the pilot switch off by default; record owner approval separately before enabling any pilot cohort, deploying server changes, changing production rules, or retiring legacy code.

---

## Dependencies & execution order

1. Complete T001–T003, then T004–T009. The foundation blocks all story work.
2. Complete US1 (T010–T017) for the smallest working, guarded MVP.
3. Add US2 (T018–T026) before exposing the pilot to any real test cohort.
4. Add US3 (T027–T032) before employee-facing pilot validation.
5. Add US4 (T033–T038), then run release evidence T039–T042.

### Story dependencies

- **US1** depends on the foundation only.
- **US2** depends on the US1 repository/presentation boundary and the durable outbox.
- **US3** depends on the US1 presentation boundary; its mapper can be built alongside US2 after T008.
- **US4** verifies US1–US3 and does not authorize payroll changes.

### Parallel opportunities

- T003 can run alongside T001–T002.
- T004–T006 can run in parallel; T007–T009 then complete the foundation.
- Within each story, every test marked `[P]` can be authored in parallel before implementation.
- T033–T035 and T039 can run in parallel because they change separate files.

## Parallel example: User Story 2

```text
T018  Outbox persistence/account-isolation tests
T019  Repository retry/replay tests
T020  Gateway status contract tests
T021  Cubit pending/status-check tests
```

## Implementation strategy

### MVP first

1. Finish Phases 1–2.
2. Implement and verify US1 only.
3. Keep the pilot switch disabled by default; confirm its check-in path works with a non-production account.
4. Do not deploy or roll out yet—US2 and US3 are required for the approved reliability promise.

### Incremental delivery

1. **US1**: structured successful/duplicate check-in.
2. **US2**: durable pending sync, bounded retry, and status resolution.
3. **US3**: safe Arabic outcomes in the dashboard.
4. **US4**: parity and future-service portability proof.
5. **Polish**: full test evidence and a separate owner rollout decision.

## Task summary

| Area | Tasks |
|---|---:|
| Setup + foundation | 9 |
| US1 — reliable check-in | 8 |
| US2 — outage safety | 9 |
| US3 — Arabic guidance | 6 |
| US4 — business-rule preservation | 6 |
| Polish/release evidence | 4 |
| **Total** | **42** |

**Parallelizable tasks**: 17 are explicitly marked `[P]`.

**Recommended MVP boundary**: T001–T017, followed by its independent US1 test. It remains default-off and check-in-only.
