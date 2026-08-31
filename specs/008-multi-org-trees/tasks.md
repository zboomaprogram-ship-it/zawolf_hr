# Tasks: Multiple Organization Trees

> Implementation is blocked until the owner reviews and approves this specification,
> plan, and task list. Tasks follow red-green-refactor and Strangler Fig rollout.

## Phase 1 — Current Behavior and Contracts

- [x] T001 Characterize the Phase 005 single-tree snapshot, membership mutation, and manager projection in `test/features/organization_structure/`.
- [x] T002 Characterize new-request routing versus immutable existing approval plans in `scripts/test/company-os-organization-routing.test.js`.
- [x] T003 [P] Add multi-tree authorization/redaction contract tests in `scripts/test/company-os-multi-tree-authorization.test.js`.
- [x] T004 [P] Add migration dry-run/idempotency contract tests in `scripts/test/company-os-multi-tree-migration.test.js`.
- [x] T005 [P] Add bounded-read/query-budget expectations to `test/firestore_query_guard_test.dart` and Node read-budget tests.

## Phase 2 — Domain Model

- [x] T006 Add `OrganizationTree`, leadership, and tree-scoped unit entities under `lib/features/organization_structure/domain/entities/`.
- [x] T007 Add multi-tree membership and primary-designation invariants under `lib/features/organization_structure/domain/services/`.
- [x] T008 Extend repository contracts with paginated tree/snapshot/search operations without exposing data implementations.
- [x] T009 Add domain tests for duplicate memberships, cross-tree parents, primary replacement, archive blockers, and cycles.

## Phase 3 — Server Operations and Migration

- [x] T010 Add tree aggregate and tree-scoped unit operations under `scripts/company-os/` with expected versions and operation IDs.
- [x] T011 Add membership and primary-projection transaction; update compatibility manager fields atomically.
- [x] T012 Add managed global/tree capabilities and fail-closed authorization.
- [x] T013 Add one-audit-event idempotent receipts and safe error codes.
- [x] T014 Add bounded tree/snapshot/search handlers to `scripts/notification-web.js` composition.
- [x] T015 Add non-destructive default-tree dry-run/apply/rollback tooling.
- [x] T016 Run Node contract, security, retry, concurrency, and read-budget tests.

## Phase 4 — Data and Offline Sync

- [x] T017 Add DTO mapping and authenticated API adapter in `lib/features/organization_structure/data/remote/`.
- [x] T018 Add tree-scoped Drift cache and outbox records in `data/local/`.
- [x] T019 Add repository fallback to Phase 005 single-tree behavior while the flag is off.
- [x] T020 Add repository tests for saved, pending, conflict, status-check, retry, and stale cache.

## Phase 5 — Arabic UI

- [x] T021 Add remote flag `company_os_multi_tree_v1`, disabled by default, with scoped pilot audience and rollback.
- [x] T022 Add focused tree-selector Cubit and responsive selector UI.
- [x] T023 Add focused hierarchy, membership, and mutation Cubits; keep each under 300 lines.
- [x] T024 Add create/clone/activate/archive tree flows with impact preview and confirmation.
- [x] T025 Add root leader and tree administrator management with scoped capability feedback.
- [x] T026 Add shared employee multi-membership UI, primary badge, bulk assignment, search, and conflict handling.
- [x] T027 Verify keyboard selection, browser text selection, Arabic RTL, mobile back navigation, loading, empty, denied, offline, and retry states.

## Phase 6 — Acceptance and Rollout

- [x] T028 Run default-tree migration rehearsal against sanitized non-production data.
- [ ] T029 Run Employee/Manager/Tree Admin/HR/Admin/Super Admin role matrix and verify zero unauthorized reads/writes.
- [ ] T030 Pilot one secondary tree and verify primary routing, immutable old requests, audit, metrics, and rollback.
- [x] T031 Run all required Flutter, architecture, query, and Node checks.
- [x] T032 Document acceptance evidence and rollback result.
- [ ] T033 Obtain explicit owner approval before making the flag default.
- [x] T034 Deploy the approved flag-protected increment and verify the live Hosting response and Hostinger health endpoint (Firebase Hosting release `07e8e471200e36b7`, 2026-08-25).

## Phase 7 — Assisted Tree Creation

- [x] T035 Characterize assisted clone creation from the current hierarchy, including a source tree with shared employees and an empty-tree fallback.
- [x] T036 Add an idempotent server-side clone-current-tree operation with preview, new stable IDs, audit receipt, and no primary-routing mutation.
- [x] T037 Make the in-page tree creation dialog default to assisted clone, retain explicit empty-tree creation, and expose Arabic saved/pending/conflict/retry states.
- [x] T038 Add Flutter and Node tests for clone isolation, retries, authorization, and current-tree preservation; run a non-production acceptance test before default enablement.

## Dependencies and Parallel Opportunities

- T003–T005 can run in parallel after T001/T002.
- T006–T009 can progress in parallel with server contract fixtures.
- Server implementation precedes data/UI integration.
- T028–T034 are release gates and cannot be pre-checked with simulated evidence.
