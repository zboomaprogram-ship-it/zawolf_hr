# Tasks: Controlled Google Workspace

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [workspace contracts](contracts/workspace-contracts.md), and [quickstart.md](quickstart.md)

**Tests**: Tests are mandatory for this feature because authorization, auditing, retry, and report idempotency are core requirements.

**Organization**: Tasks are grouped by user story after setup/foundation so every increment remains independently demonstrable and testable.

## Phase 1: Setup and characterization

**Purpose**: Preserve the current live workspace while creating an evidence-backed migration baseline.

- [x] T001 Inventory all current Company Workspace routes, Firestore collections, server routes, Google connector calls, and scheduler ownership in `specs/006-google-workspace-control/current-state-audit.md`.
- [x] T002 [P] Add current workspace behavior characterization tests in `test/features/company_workspace/legacy_workspace_characterization_test.dart`.
- [x] T003 [P] Add existing Company Workspace HTTP contract characterization tests in `scripts/test/company-workspace-legacy-contract.test.js`.
- [x] T004 Add an explicit `company_workspace_v2` feature-switch contract and rollback policy in `lib/core/feature_flags/company_workspace_feature_flag.dart` and `specs/006-google-workspace-control/migration-plan.md`.
- [x] T005 Add a controlled non-production root/report-destination checklist in `specs/006-google-workspace-control/non-production-setup.md`.

---

## Phase 2: Foundation — clean boundaries, safe operations, and audit primitives

**Purpose**: Create the shared foundations that block every migrated screen and integration operation.

**⚠️ CRITICAL**: Complete this phase before replacing any live Workspace route.

- [x] T006 Create the Company Workspace feature folders under `lib/features/company_workspace/{domain,data,presentation}/`.
- [x] T007 [P] Define pure workspace entities and value types in `lib/features/company_workspace/domain/entities/`.
- [x] T008 [P] Define repository contracts in `lib/features/company_workspace/domain/repositories/company_workspace_repository.dart` and `workspace_reports_repository.dart`.
- [x] T009 [P] Define stable operation, permission, audit-action, report-period, and compatibility-capability enums in `lib/features/company_workspace/domain/entities/`.
- [x] T010 Add focused domain tests for access precedence, operation state transitions, report keys, and compatibility declarations in `test/features/company_workspace/domain/`.
- [x] T011 Create local pending-operation/outbox persistence in `lib/core/sync/workspace_operation_outbox.dart` and its Drift schema/migration files.
- [x] T012 [P] Add retry classification and Arabic safe error mapping in `lib/core/errors/workspace_user_facing_error.dart`.
- [x] T013 [P] Add a reusable feature switch reader in `lib/core/feature_flags/company_workspace_feature_flag.dart`.
- [x] T014 Implement data-layer DTOs, mapper tests, and server gateway interfaces in `lib/features/company_workspace/data/`.
- [x] T015 Add a client gateway that refreshes identity, sends stable operation IDs, and never exposes provider IDs in `lib/features/company_workspace/data/datasources/company_workspace_remote_data_source.dart`.
- [x] T016 Add a sync coordinator that resolves pending/acknowledged/rejected/conflict operations in `lib/features/company_workspace/data/repositories/company_workspace_repository_impl.dart`.
- [x] T017 Add Node request correlation, operation-id deduplication, safe error mapping, and append-only audit helper modules in `scripts/workspace/{request-context,operation-idempotency,safe-errors,audit}.js`.
- [x] T018 Add Node tests for duplicate operation IDs, permission denial, temporary failure, and raw-error suppression in `scripts/test/workspace-operation-foundation.test.js`.
- [x] T019 Add architecture-guard coverage for the new feature boundaries in `test/architecture_guard_test.dart`.
- [x] T020 Add Firestore/read-budget guard coverage for bounded Workspace queries in `test/firestore_query_guard_test.dart` and `scripts/test/firestore-read-budget.test.js`.

**Checkpoint**: The V2 feature can authenticate, authorize, queue/retry an operation safely, and emit one audit event without changing the legacy route.

---

## Phase 3: User Story 1 — Work only in assigned company files (Priority: P1) 🎯 MVP

**Goal**: Employees can securely browse and work with only their assigned folders/files from ZaWolf.

**Independent Test**: An editor, viewer, and ungranted employee each open Company Files; only permitted resources/actions are available, and every permitted Drive action has one audit event.

### Tests for User Story 1

- [x] T021 [P] [US1] Add domain tests for inherited, resource-specific, revoked, and stale-session grants in `test/features/company_workspace/domain/workspace_access_policy_test.dart`.
- [x] T022 [P] [US1] Add Node authorization and direct-link contract tests in `scripts/test/workspace-resource-authorization.test.js`.
- [x] T023 [P] [US1] Add Flutter widget tests for allowed, empty, loading, retry, denied, and RTL states in `test/features/company_workspace/presentation/company_files_page_test.dart`.
- [x] T024 [P] [US1] Add idempotency tests for create/upload/rename/move/copy/trash/restore in `scripts/test/workspace-drive-operations.test.js`.

### Implementation for User Story 1

- [x] T025 [US1] Implement effective access evaluation and resource-discovery use cases in `lib/features/company_workspace/domain/use_cases/`.
- [x] T026 [P] [US1] Implement paginated resource/folder data source and repository mapping in `lib/features/company_workspace/data/`.
- [x] T027 [P] [US1] Implement safe server-side resource hierarchy validation in `scripts/workspace/authorization.js` and `scripts/workspace/resource-navigation.js`.
- [x] T028 [US1] Implement V2 folder/file list, progressive discovery, and safe path navigation endpoints in `scripts/notification-web.js` and `scripts/workspace/resource-navigation.js`.
- [x] T029 [US1] Implement retry-safe Drive mutation endpoints for create/upload/download/rename/move/copy/trash/restore in `scripts/workspace/drive-operations.js` and `scripts/notification-web.js`.
- [x] T030 [US1] Implement `WorkspaceBrowserCubit` in `lib/features/company_workspace/presentation/cubit/workspace_browser_cubit.dart`.
- [x] T031 [US1] Implement full-width responsive Company Files route/page in `lib/features/company_workspace/presentation/pages/company_files_page.dart`.
- [x] T032 [P] [US1] Implement breadcrumb, folder tree, file list, progress, and empty/error/retry widgets in `lib/features/company_workspace/presentation/widgets/`.
- [x] T033 [US1] Add safe upload, download, create-folder, rename, move, copy, trash, and restore flows in `lib/features/company_workspace/presentation/pages/company_files_page.dart`.
- [x] T034 [US1] Wire the V2 page behind `company_workspace_v2` while retaining the legacy screens/routes in `lib/navigation/` and `lib/screens/shared/`.

**Checkpoint**: US1 is independently usable without direct Google links and can be rolled back by the feature switch.

---

## Phase 4: User Story 2 — Use a reliable spreadsheet workspace (Priority: P1)

**Goal**: An editor can use a full-page, familiar spreadsheet workspace inside ZaWolf for supported content.

**Independent Test**: An editor adds/renames a tab, edits/pastes multiple cells, inserts a row/column, applies formats/labels/validation, uses find, saves, reloads, and sees the same supported data.

### Tests for User Story 2

- [x] T035 [P] [US2] Add domain tests for range validation, expected versions, and unsupported capability protection in `test/features/company_workspace/domain/spreadsheet_operation_test.dart`.
- [x] T036 [P] [US2] Add Node contract tests for viewport read, batched edit, paste, format, structure, tabs, and version conflict in `scripts/test/workspace-sheet-contract.test.js`.
- [x] T037 [P] [US2] Add widget tests for direct-cell editing, selection, keyboard shortcuts, tabs, scroll, RTL, and safe status in `test/features/company_workspace/presentation/workspace_sheet_editor_page_test.dart`.
- [x] T038 [P] [US2] Add regression tests protecting unsupported advanced content from mutation in `scripts/test/workspace-sheet-compatibility.test.js`.

### Implementation for User Story 2

- [x] T039 [US2] Implement viewport, cell metadata, range, tab, and compatibility entities/use cases in `lib/features/company_workspace/domain/`.
- [x] T040 [P] [US2] Implement spreadsheet read/mutation DTOs and version-aware data source in `lib/features/company_workspace/data/`.
- [x] T041 [US2] Implement server-side viewport read with dimensions, formulas, formats, labels, notes, hyperlinks, validation, merges, and capabilities in `scripts/workspace/spreadsheet-read.js`.
- [x] T042 [US2] Implement atomic batched cell/formula/paste mutation handling with operation deduplication in `scripts/workspace/spreadsheet-mutations.js`.
- [x] T043 [US2] Implement server operations for row/column/tab lifecycle, formatting, validation/checkboxes, labels, filtering/sorting, and permitted protection in `scripts/workspace/spreadsheet-structure.js`.
- [x] T044 [US2] Implement `WorkspaceSheetCubit` and `WorkspaceSheetSyncCubit` in `lib/features/company_workspace/presentation/cubit/`.
- [x] T045 [US2] Implement a full-page responsive sheet editor with frozen headings, horizontal/vertical scroll, direct in-cell input, range selection, and formula bar in `lib/features/company_workspace/presentation/pages/workspace_sheet_editor_page.dart`.
- [x] T046 [P] [US2] Implement toolbar, tabs, status bar, find panel, context actions, range formatter, validation/label controls, and accessibility widgets in `lib/features/company_workspace/presentation/widgets/sheet/`.
- [x] T047 [US2] Implement keyboard selection/copy/paste/find/undo/redo behavior and audit capture for in-editor clipboard actions in `lib/features/company_workspace/presentation/pages/workspace_sheet_editor_page.dart`.
- [x] T048 [US2] Implement optimistic queued edits, conflict display, and per-operation Arabic saved/pending/retry/status states in `lib/features/company_workspace/presentation/cubit/workspace_sheet_sync_cubit.dart`.
- [x] T049 [US2] Wire V2 spreadsheet opening from V2 Company Files while keeping `lib/screens/shared/workspace_sheet_editor_screen.dart` available as rollback.

**Checkpoint**: US2 delivers the operational spreadsheet workflow without claiming support for protected/unsupported content.

---

## Phase 5: User Story 3 — Control company access centrally (Priority: P1)

**Goal**: Super Admins and dynamic IT Managers control sources, department hierarchy, and granular access in ZaWolf.

**Independent Test**: A controller imports a department hierarchy, grants edit then view then revokes access for an employee; the changed capability is enforced on next action and every policy change is audited.

### Tests for User Story 3

- [x] T050 [P] [US3] Add authorization tests proving an active IT Manager is dynamic and no employee code is hard-coded in `scripts/test/workspace-controller-authorization.test.js`.
- [x] T051 [P] [US3] Add grant-scope, revoke-precedence, and hierarchy-import tests in `scripts/test/workspace-access-administration.test.js`.
- [x] T052 [P] [US3] Add Flutter widget tests for source, grant, revoke, and protected-access states in `test/features/company_workspace/presentation/workspace_access_admin_page_test.dart`.

### Implementation for User Story 3

- [x] T053 [US3] Implement source, grant, and role-scope administration entities/use cases in `lib/features/company_workspace/domain/`.
- [x] T054 [P] [US3] Implement source/grant repositories and mapping in `lib/features/company_workspace/data/`.
- [x] T055 [US3] Implement server APIs for source import, department/employee placement, grant create/update/revoke, and grant inspection in `scripts/workspace/access-administration.js` and `scripts/notification-web.js`.
- [x] T056 [US3] Implement safe hierarchy import with progress/resume, duplicate detection, and non-destructive reconciliation in `scripts/workspace/source-import.js`.
- [x] T057 [US3] Implement `WorkspaceAccessAdminCubit` in `lib/features/company_workspace/presentation/cubit/workspace_access_admin_cubit.dart`.
- [x] T058 [US3] Implement the full-width access/source administration page and access matrix in `lib/features/company_workspace/presentation/pages/workspace_access_admin_page.dart`.
- [x] T059 [US3] Add department-organized employee folder assignment UI and resource discovery controls in `lib/features/company_workspace/presentation/widgets/access/`.
- [x] T060 [US3] Add an audited feature-switch pilot configuration and controller-facing rollback UI in `lib/features/company_workspace/presentation/pages/workspace_access_admin_page.dart`.

**Checkpoint**: US3 independently controls access and source organization without exposing credentials or raw Google metadata.

---

## Phase 6: User Story 4 — Audit work and generate reports (Priority: P1)

**Goal**: Authorized leaders and HR receive protected, idempotent Sheets reports for workspace work and HR operational periods.

**Independent Test**: Run a representative employee work session, generate daily/weekly/monthly/custom reports, and verify scoped contents, one official result per report key, and in-app discovery.

### Tests for User Story 4

- [x] T061 [P] [US4] Add audit taxonomy, actor attribution, external/unattributed, and sensitive-diff tests in `scripts/test/workspace-audit.test.js`.
- [x] T062 [P] [US4] Add daily/weekly/monthly/custom report-key and duplicate-run tests in `scripts/test/workspace-reports-idempotency.test.js`.
- [x] T063 [P] [US4] Add HR business-effective period report tests for attendance, requests, and deductions in `scripts/test/workspace-hr-reports.test.js`.
- [x] T064 [P] [US4] Add report period/filter/empty/error/RTL widget tests in `test/features/company_workspace/presentation/workspace_reports_page_test.dart`.

### Implementation for User Story 4

- [x] T065 [US4] Implement append-only audit-event and report-run entities/use cases in `lib/features/company_workspace/domain/`.
- [x] T066 [P] [US4] Implement audit/report data sources and repositories in `lib/features/company_workspace/data/`.
- [x] T067 [US4] Implement server audit taxonomy, protected diff policy, event query, and external-activity reconciliation in `scripts/workspace/{audit,activity-reconciliation}.js`.
- [x] T068 [US4] Implement idempotent workspace activity report generation and protected report discovery in `scripts/workspace/reports.js` and `scripts/notification-web.js`.
- [x] T069 [US4] Implement idempotent HR attendance/request/deduction period reports using existing authoritative records only in `scripts/workspace/hr-reports.js`.
- [x] T070 [US4] Identify and document one live report/reconciliation scheduler owner and manual recovery paths in `scripts/workspace/scheduler.js` and `docs/workspace_scheduler_ownership.md`.
- [x] T071 [US4] Implement `WorkspaceReportsCubit` and `WorkspaceAuditCubit` in `lib/features/company_workspace/presentation/cubit/`.
- [x] T072 [US4] Implement in-app reports page with daily/weekly/monthly/custom filters, safe status, scoped audit discovery, and report opening in `lib/features/company_workspace/presentation/pages/workspace_reports_page.dart`.
- [x] T073 [US4] Add HR navigation entry and report discovery route without changing attendance, request, payroll, or deduction calculations in `lib/navigation/` and `lib/screens/hr/`.

**Checkpoint**: US4 produces governed Google Sheet reports and makes them discoverable inside ZaWolf.

---

## Phase 7: User Story 5 — Recover safely from unreliable connections (Priority: P2)

**Goal**: Employees receive reliable Arabic outcomes during network/provider interruptions, duplicate submits, and conflicts.

**Independent Test**: Interrupt each mutable workspace action, restore service, and prove one final result with Arabic pending/retry/conflict feedback and no technical error text.

### Tests for User Story 5

- [x] T074 [P] [US5] Add outbox persistence/restart/retry tests in `test/features/company_workspace/data/workspace_operation_outbox_test.dart`.
- [x] T075 [P] [US5] Add client Cubit tests for unavailable, denied, duplicate, conflict, and recovery outcomes in `test/features/company_workspace/presentation/workspace_sync_cubit_test.dart`.
- [x] T076 [P] [US5] Add Node temporary-failure and previous-result replay tests in `scripts/test/workspace-resilience.test.js`.

### Implementation for User Story 5

- [x] T077 [US5] Implement background-safe outbox replay, bounded retry/backoff, and acknowledgement reconciliation in `lib/core/sync/workspace_operation_outbox.dart`.
- [x] T078 [US5] Implement conflict resolution UI with safe before/current context and explicit user decision in `lib/features/company_workspace/presentation/pages/workspace_conflict_page.dart`.
- [x] T079 [US5] Add offline/pending/conflict indicator and status-check actions across V2 Company Files, editor, admin, and reports pages in `lib/features/company_workspace/presentation/widgets/`.
- [x] T080 [US5] Add server diagnostics that retain technical context privately while returning only safe Arabic errors in `scripts/workspace/safe-errors.js` and `scripts/notification-web.js`.

**Checkpoint**: US5 keeps employee-facing operations calm, actionable, and non-duplicating under failure.

---

## Phase 8: Migration, acceptance, performance, and release

**Purpose**: Prove V2 parity, privacy, reliability, cost control, and rollback before it becomes the default.

- [x] T081 Add non-destructive legacy-resource migration and reconciliation tooling in `scripts/workspace/migrate-legacy-resources.js`.
- [x] T082 Add migration dry-run, duplicate, rollback, and privilege-regression tests in `scripts/test/workspace-migration.test.js`.
- [x] T083 Add bounded discovery/list/read observability and read-budget tests in `scripts/workspace/metrics.js` and `scripts/test/workspace-read-budget.test.js`.
- [x] T084 Add accessibility, RTL, desktop width/height, normal selection/copy, Ctrl/Cmd+F, and mobile scrolling regression tests in `test/features/company_workspace/presentation/workspace_accessibility_test.dart`.
- [ ] T085 Execute the non-production acceptance flows from `specs/006-google-workspace-control/quickstart.md` and record evidence in `specs/006-google-workspace-control/acceptance-evidence.md`.
- [x] T086 Run `flutter analyze` and record the result in `specs/006-google-workspace-control/acceptance-evidence.md`.
- [x] T087 Run `flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart` and record the result in `specs/006-google-workspace-control/acceptance-evidence.md`.
- [x] T088 Run `flutter test` and record the result in `specs/006-google-workspace-control/acceptance-evidence.md`.
- [x] T089 Run `(cd scripts && npm test)` and record the result in `specs/006-google-workspace-control/acceptance-evidence.md`.
- [x] T090 Prepare deployment, environment-variable, one-scheduler, non-destructive migration, and rollback instructions in `docs/phase-006-google-workspace-release.md`.
- [ ] T091 Enable a limited pilot through `company_workspace_v2`, verify metrics/audits/reports, and document the owner’s explicit default-route approval in `specs/006-google-workspace-control/acceptance-evidence.md`.
- [ ] T092 Make V2 the default only after T081–T091 are proven; keep the legacy path available until separately approved retirement in `lib/core/feature_flags/company_workspace_feature_flag.dart`.

## Dependencies & Execution Order

```text
Phase 1 → Phase 2 → US1 (MVP) → US2 / US3 → US4 → US5 → Phase 8
                                  └────────── both require the same foundation
US4 requires audit/report primitives from Phase 2 and access controls from US1/US3.
US5 begins after any mutable V2 operation exists and completes before pilot/default switch.
```

## Parallel Opportunities

- T002–T003 can proceed in parallel after T001.
- T007–T010 and T012–T013 can proceed in parallel once T006 exists.
- Within US1, T021–T024 are parallel test work; T026–T027 can begin after T025.
- Within US2, T035–T038 are parallel test work; T040 and T041 can proceed in parallel after T039.
- Within US3, T050–T052 are parallel test work; T054 can proceed alongside T055 after T053.
- Within US4, T061–T064 are parallel test work; T066–T067 can proceed after T065.
- US2 and US3 may proceed in parallel after US1’s V2 authorization/navigation boundary is stable.

## Implementation Strategy

1. Complete Foundation and demonstrate the US1 controlled-file MVP behind the feature switch.
2. Add spreadsheet parity and access administration without removing the existing workspace.
3. Add activity/HR reports and reliability guarantees.
4. Run full non-production acceptance, then a limited pilot.
5. Only after evidence and owner approval, make V2 the default; retirement of the legacy workspace is a separate reviewed change.

## Format Validation

Every implementation task uses the required checkbox, sequential ID, optional parallel marker, user-story label where applicable, and an exact target path.
