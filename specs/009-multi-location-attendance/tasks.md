# Tasks: Multiple Attendance Locations

> Attendance implementation and deployment are blocked until owner review of the
> specification, plan, and tasks. Production rules/migration require separate approval.

## Phase 1 — Characterization and Safety Baseline

- [x] T001 Characterize current one-location manual check-in, deterministic duplicate, device binding, and safe error outcomes.
- [x] T002 Characterize offline queued check-in and interrupted retry behavior.
- [x] T003 Characterize automatic enter validation, stale/unassigned events, workdays, leave, and duplicate convergence in Node tests.
- [x] T004 [P] Characterize checkout-disabled behavior and prove leave permission/correction remain available.
- [x] T005 [P] Add bounded assignment/location read-budget expectations.

## Phase 2 — Domain and Contracts

- [x] T006 Add attendance-location assignment and match-evidence entities under feature domain layers.
- [x] T007 Add deterministic nearest-match policy with stable-ID tie breaking.
- [x] T008 Add assignment repository and administration use-case contracts.
- [x] T009 Add domain tests for overlap, effective dates, inactive sites, empty assignments, and DST boundaries.

## Phase 3 — Server Authority

- [x] T010 Add capability-scoped assignment preview/apply/status operations with version/idempotency/audit.
- [x] T011 Extend attendance gateway parsing to require matched assignment evidence when the flag is enabled.
- [x] T012 Recalculate geofence distance and validate active/effective assignment server-side before device binding/write.
- [x] T013 Extend automatic attendance worker to accept any assigned active location without scanning company locations.
- [x] T014 Preserve canonical attendance ID and semantic duplicate result across location races.
- [x] T015 Add safe Arabic error mapping for no assignment, stale assignment, inactive site, outside range, and status check.
- [x] T016 Add Node authorization, tampering, idempotency, race, offline, auto-entry, and read-budget tests.

## Phase 4 — Client Data and Matching

- [x] T017 Add bounded assignment API/cache repository in `lib/features/attendance_locations/data/`.
- [x] T018 Add assignment version/location evidence to the existing local attendance outbox compatibly.
- [x] T019 Update check-in repository to use nearest assigned match behind the flag and legacy validator when disabled.
- [x] T020 Add repository tests for cache fallback, stale assignment, pending sync, conflict, and status-check.

## Phase 5 — HR Assignment UI

- [x] T021 Add focused assignment-management Cubit under 300 lines.
- [x] T022 Add employee search, active location multi-select, effective dates, default site, impact preview, and audit receipt UI.
- [x] T023 Add bulk assign/remove flows with explicit confirmation and safe partial-failure prevention.
- [x] T024 Verify HR/Admin capability matrix and Arabic loading/empty/denied/offline/conflict/retry states.

## Phase 6 — Mobile Automatic Attendance

- [x] T025 Update Android region registration to use bounded prioritized assignments and send entry/exit evidence without device-side payroll decisions.
- [x] T026 Update iOS region registration within Apple platform limits, send entry/exit evidence, and preserve manual fallback.
- [x] T027 Add platform contract tests for add/remove/restart/limit/priority behavior without requiring an iOS build on the owner's old device.
- [x] T028 Verify manual check-in remains available when background regions cannot all register.

## Phase 7 — Migration and Release

- [x] T029 Add `attendance_multi_location_v1`, disabled by default, with remote pilot audience and rollback.
- [x] T030 Add legacy `locationId` to one-assignment dry-run/apply tooling with retry and no deletion.
- [ ] T031 Run real non-production role/location/device/manual/offline/automatic acceptance matrix.
- [ ] T032 Pilot employees who attend two locations and verify latency, reads, rejection reasons, duplicates, audit, and rollback.
- [x] T033 Run all required Flutter, architecture, query, and Node checks.
- [x] T034 Document acceptance and rollback evidence.
- [ ] T035 Obtain explicit owner approval for default switch and any production migration/rule change.
- [ ] T036 Deploy the approved increment and monitor attendance success, pending sync, status checks, and duplicate rate.

## Phase 8 — Exception Return Grace and Automatic Checkout

- [x] T037 Characterize exit during approved return-required permission and company break, re-entry before grace, expiry without re-entry, worker retry, and checkout-disabled behavior.
- [x] T038 Add a server-authoritative, HR-configurable return-grace policy and deterministic pending-return evidence entity without changing payroll or permission accounting.
- [x] T039 Extend automatic-attendance processing to create/resolve pending-return evidence and schedule one idempotent checkout only after exception end plus grace.
- [x] T040 Add Node tests for duplicate/delayed worker execution, policy changes, re-entry race, permission/break exceptions, and audit receipts.
- [x] T041 Add HR policy UI and employee-safe Arabic status for pending return, re-entry confirmed, and automatic checkout; retain no raw infrastructure errors.
- [ ] T042 Run non-production Android/iOS/manual acceptance for exit, permission, break, re-entry, and checkout-disabled policy before enabling the feature for staff.

## Dependencies and Parallel Opportunities

- T004/T005 can run alongside T001–T003.
- T006–T009 can progress alongside server test fixtures after characterization.
- Server authority must pass before client or platform rollout.
- T031–T036 are real release gates and cannot be checked from local simulation.
