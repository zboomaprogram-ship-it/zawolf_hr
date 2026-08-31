# Tasks: Internal Company OS Foundation

**Input**: Design documents in `specs/005-internal-company-os/`

**Tests**: Contract, authorization, idempotency, privacy, query-budget, Arabic
state, and legacy-parity tests are required by the approved specification and
plan. Story tests must be written first and observed failing before the matching
implementation is added.

## Phase 1: Setup and characterization

**Purpose**: Establish additive feature boundaries, disabled rollout switches,
and characterization coverage without changing the live HR experience.

- [X] T001 Create the Company OS feature layer directories and ownership notes in `lib/features/company_os/data/`, `lib/features/company_os/domain/`, `lib/features/company_os/presentation/`, and `lib/features/company_os/README.md`
- [X] T002 [P] Add disabled-by-default portal, IT, request, and operations flag contracts plus test overrides in `lib/core/feature_flags/company_os_feature_flags.dart` and `test/core/company_os_feature_flags_test.dart`
- [X] T003 [P] Characterize existing request history, notification, approval-chain, and management-route behavior in `test/features/company_os/legacy_request_center_characterization_test.dart` and `test/navigation/company_os_route_parity_test.dart`
- [X] T004 [P] Characterize active employee, department, direct-manager, and existing HR-role resolution in `test/features/company_os/existing_identity_characterization_test.dart`
- [X] T005 [P] Add Company OS fixture identities, departments, scopes, tickets, assets, licenses, and request categories in `test/fixtures/company_os_fixtures.dart` and `scripts/test/fixtures/company-os-fixtures.js`
- [X] T006 Document the four rollout audiences, legacy fallback routes, metrics, rollback owner, and pilot evidence fields in `specs/005-internal-company-os/quickstart.md`

---

## Phase 2: Foundational safety and integration contracts

**Purpose**: Build the shared authorization, operation, persistence, privacy,
and audit foundations that block every Company OS user story.

**Critical**: No story implementation starts until these tasks pass.

- [X] T007 Define framework-independent operation receipt, sync state, pagination, safe error, attachment reference, and version-conflict entities in `lib/features/company_os/domain/entities/`
- [X] T008 [P] Define operational role grant, immutable audit event, and role-derived scope contracts in `lib/features/company_os/domain/entities/operational_role_grant.dart`, `lib/features/company_os/domain/entities/operational_audit_event.dart`, and `lib/features/company_os/domain/repositories/company_os_authorization_repository.dart`
- [X] T009 [P] Add architecture guards rejecting Flutter/infrastructure imports in Company OS domain and data imports in presentation in `test/architecture_guard_test.dart`
- [X] T010 [P] Add operation envelope, pagination, safe-code, and private-field redaction contract tests in `scripts/test/company-os-contract.test.js`
- [X] T011 [P] Add role/scope/active-employment authorization matrix tests for Employee, IT Support, IT Manager, Finance, Manager, Admin, and Super Admin in `scripts/test/company-os-authorization.test.js`
- [X] T012 Implement authenticated Company OS routing, Firebase token validation, active-employee resolution, role grants, scope enforcement, and safe response envelopes in `scripts/company-os/router.js`, `scripts/company-os/authorization.js`, and `scripts/notification-web.js`
- [X] T013 Implement operation-ID payload hashing, previous-result replay, expected-version validation, and atomic mutation-plus-audit transactions in `scripts/company-os/operation-gateway.js` and `scripts/company-os/audit.js`
- [X] T014 [P] Add duplicate retry, changed-payload conflict, ambiguous timeout, and audit atomicity tests in `scripts/test/company-os-idempotency.test.js`
- [X] T015 Implement Drift-backed Company OS cache/outbox records, bounded retry, status reconciliation, and restart recovery in `lib/features/company_os/data/local/company_os_database.dart` and `lib/features/company_os/data/local/company_os_outbox.dart`
- [X] T016 [P] Add local outbox persistence, retry, conflict, and status-check tests in `test/features/company_os/data/company_os_outbox_test.dart`
- [X] T017 Implement the authenticated remote operation client, DTO validation, raw-error redaction, and bounded list envelope in `lib/features/company_os/data/remote/company_os_api_client.dart`
- [X] T018 Add server-side disabled-by-default audience flags and audited rollback controls for all four slices in `scripts/feature-flags.js`, `scripts/company-os/feature-flags.js`, and `scripts/test/company-os-feature-flags.test.js`
- [X] T019 Define the optional attachment-provider boundary and legacy attachment adapter so Phase 005 does not depend on Phase 006 in `lib/features/company_os/domain/repositories/company_os_attachment_repository.dart` and `lib/features/company_os/data/repositories/legacy_company_os_attachment_repository.dart`

**Checkpoint**: Authenticated, scoped, idempotent operations can be tested with
safe Arabic outcomes while every Company OS route remains disabled by default.

---

## Phase 3: User Story 1 — Use one internal operations portal (Priority: P1) MVP

**Goal**: An active employee can view only their own operational information,
submit and track an IT ticket, and use published knowledge from one ZaWolf area.

**Independent Test**: Enable the portal for one employee, submit the same ticket
twice across an interrupted connection, and verify one ticket, one audit event,
safe Arabic state, and no other employee or private IT data.

### Tests for User Story 1

- [X] T020 [P] [US1] Add employee portal summary and self-scope domain tests in `test/features/company_os/domain/employee_portal_test.dart`
- [X] T021 [P] [US1] Add ticket creation/detail, interrupted-submit, private-note exclusion, and inactive-employee Node tests in `scripts/test/company-os-employee-portal.test.js`
- [X] T022 [P] [US1] Add Arabic RTL loading, empty, pending, saved, conflict, denied, and retry widget tests in `test/features/company_os/presentation/company_os_portal_page_test.dart`

### Implementation for User Story 1

- [X] T023 [P] [US1] Define employee portal summary, IT ticket, public comment, ticket activity, and knowledge article domain entities in `lib/features/company_os/domain/entities/`
- [X] T024 [P] [US1] Define employee portal and self-service ticket repository contracts and use cases in `lib/features/company_os/domain/repositories/employee_portal_repository.dart` and `lib/features/company_os/domain/use_cases/`
- [X] T025 [US1] Implement scoped employee summary, own-ticket list/detail/create, public-comment, and published-knowledge endpoints in `scripts/company-os/employee-portal.js` and `scripts/company-os/tickets.js`
- [X] T026 [US1] Implement employee portal DTOs, cache mapping, and repository adapter in `lib/features/company_os/data/repositories/employee_portal_repository_impl.dart`
- [X] T027 [US1] Implement focused portal-summary, ticket-list, ticket-detail, and ticket-submit Cubits under 300 lines in `lib/features/company_os/presentation/cubit/`
- [X] T028 [US1] Implement Arabic responsive employee portal, own ticket flow, operational summary, and knowledge views in `lib/features/company_os/presentation/pages/company_os_portal_page.dart`, `lib/features/company_os/presentation/pages/employee_ticket_page.dart`, and `lib/features/company_os/presentation/pages/company_knowledge_page.dart`
- [X] T029 [US1] Add the flagged Company OS employee navigation seam while retaining all legacy HR routes in `lib/navigation/router.dart` and `lib/navigation/navigation_wrapper.dart`
- [X] T030 [US1] Wire eligible ticket/status notifications to canonical authorized destinations with private-field-safe Arabic text in `scripts/company-os/notifications.js` and `lib/services/notification_service.dart`

**Checkpoint**: User Story 1 is independently usable and can be rolled back by
disabling `company_os_portal_v1`.

---

## Phase 4: User Story 2 — Operate IT tickets and assets safely (Priority: P1)

**Goal**: Authorized IT users manage ticket lifecycle, private notes, assets,
handover/return/maintenance history, software, and license seats safely.

**Independent Test**: Assign and resolve one ticket, assign/return one asset,
and fill one license; verify immutable history, private-note isolation, exactly
one result under retries, and capacity/conflict protection.

### Tests for User Story 2

- [X] T031 [P] [US2] Add ticket lifecycle, priority, SLA, transition, and private-note domain tests in `test/features/company_os/domain/it_ticket_test.dart`
- [X] T032 [P] [US2] Add asset lifecycle, single-active-assignment, retirement, and maintenance-cost domain tests in `test/features/company_os/domain/asset_test.dart`
- [X] T033 [P] [US2] Add software seat capacity, duplicate assignment, renewal, and revoke tests in `test/features/company_os/domain/software_license_test.dart`
- [X] T034 [P] [US2] Add Node authorization, concurrency, retry, history, and private-field redaction tests in `scripts/test/company-os-it-operations.test.js`
- [X] T035 [P] [US2] Add IT queue, asset, software, and safe conflict widget tests in `test/features/company_os/presentation/it_operations_pages_test.dart`

### Implementation for User Story 2

- [X] T036 [P] [US2] Define asset, assignment, maintenance, software license, software assignment, and IT private-note entities in `lib/features/company_os/domain/entities/`
- [X] T037 [P] [US2] Define IT operations repository contracts and lifecycle use cases in `lib/features/company_os/domain/repositories/it_operations_repository.dart` and `lib/features/company_os/domain/use_cases/`
- [X] T038 [US2] Implement transactional ticket assignment/transition/comment/private-note operations with separate private-note storage in `scripts/company-os/tickets.js` and `scripts/company-os/private-notes.js`
- [X] T039 [US2] Implement transactional asset create/update/assign/return/maintenance/retire operations and immutable history in `scripts/company-os/assets.js`
- [X] T040 [US2] Implement transactional software/license create/update/seat-assign/revoke operations with capacity enforcement in `scripts/company-os/software.js`
- [X] T041 [US2] Implement paginated IT ticket, asset, history, maintenance, license, and seat data adapters in `lib/features/company_os/data/repositories/it_operations_repository_impl.dart`
- [X] T042 [US2] Implement focused IT queue, ticket detail, asset inventory/detail, and license Cubits under 300 lines in `lib/features/company_os/presentation/cubit/`
- [X] T043 [US2] Implement Arabic responsive IT queue and ticket workflow pages with public/private content separation in `lib/features/company_os/presentation/pages/it_ticket_queue_page.dart` and `lib/features/company_os/presentation/pages/it_ticket_detail_page.dart`
- [X] T044 [US2] Implement asset inventory, handover/return/maintenance, and retained-history pages in `lib/features/company_os/presentation/pages/company_assets_page.dart` and `lib/features/company_os/presentation/pages/asset_detail_page.dart`
- [X] T045 [US2] Implement software license, seat capacity, assignment, renewal, and revoke pages in `lib/features/company_os/presentation/pages/software_licenses_page.dart`
- [X] T046 [US2] Add IT Support/IT Manager navigation and route/server guards behind `company_os_it_v1` in `lib/navigation/router.dart` and `lib/navigation/navigation_wrapper.dart`

**Checkpoint**: User Story 2 is independently demonstrable; disabling
`company_os_it_v1` removes its navigation without changing employee HR routes.

---

## Phase 5: User Story 3 — Use one approval chain for IT and every cost (Priority: P1)

**Goal**: Extend the existing request center with access and cost-bearing
requests whose immutable server plan enforces manager, relevant specialist,
Finance, Company Owner, and payment/closure stages.

**Independent Test**: Submit an access request and every cost category, retry
each decision, approve in a later period, and verify one canonical history,
mandatory Finance/owner stages, immutable execution date, and no payroll write.

### Tests for User Story 3

- [X] T047 [P] [US3] Add request classification, specialist relevance, stage order, owner-policy version, and execution-date domain tests in `test/features/company_os/domain/unified_operational_request_test.dart`
- [X] T048 [P] [US3] Add characterization tests proving Company OS requests reuse existing request history, notification, and approval rendering in `test/features/company_os/legacy_request_center_parity_test.dart`
- [X] T049 [P] [US3] Add Node tests for every cost category, mandatory Finance/owner stages, duplicate decisions, inactive owner, and fail-closed classification in `scripts/test/company-os-approval-policy.test.js`
- [X] T050 [P] [US3] Add cross-period approval tests proving execution/effective date is retained and payroll records are not mutated in `scripts/test/company-os-request-period.test.js` and `test/features/company_os/domain/financial_ledger_test.dart`
- [X] T051 [P] [US3] Add request form, approval journey, Finance, owner, payment, and safe-state widget tests in `test/features/company_os/presentation/company_os_requests_test.dart`

### Implementation for User Story 3

- [X] T052 [P] [US3] Define unified operational request, approval plan/stage/decision, managed owner policy, and financial ledger entities in `lib/features/company_os/domain/entities/`
- [X] T053 [P] [US3] Define operational request and finance read-model repository contracts/use cases in `lib/features/company_os/domain/repositories/operational_request_repository.dart`, `lib/features/company_os/domain/repositories/finance_repository.dart`, and `lib/features/company_os/domain/use_cases/`
- [X] T054 [US3] Implement server-side request classification and versioned approval-plan materialization with mandatory Finance and managed owner stages in `scripts/company-os/approval-policy.js`
- [X] T055 [US3] Implement managed Company Owner resolution initially from active employee code `ceo-100`, UID persistence, replacement, and historical-version retention in `scripts/company-os/owner-policy.js`
- [X] T056 [US3] Implement canonical request create/read/decision/payment/closure operations through the existing request aggregate and audit seams in `scripts/company-os/requests.js` and `scripts/notification-web.js`
- [X] T057 [US3] Implement access provisioning completion and specialist-stage operations without automatic external provisioning in `scripts/company-os/access-requests.js`
- [X] T058 [US3] Implement read-only payslip and source-linked financial ledger endpoints with no payroll writes in `scripts/company-os/finance.js`
- [X] T059 [US3] Implement operational request and finance DTO/cache/repository adapters in `lib/features/company_os/data/repositories/operational_request_repository_impl.dart` and `lib/features/company_os/data/repositories/finance_repository_impl.dart`
- [X] T060 [US3] Implement focused request form/history/detail/decision and finance ledger Cubits under 300 lines in `lib/features/company_os/presentation/cubit/`
- [X] T061 [US3] Extend the existing request creation/history/management screens with IT, access, and cost categories behind `company_os_requests_v1` in `lib/screens/employee/employee_requests.dart` and `lib/screens/manager/requests_mgmt.dart`
- [X] T062 [US3] Add Arabic approval journey, Finance/owner decision, payment/closure, payslip, and ledger presentation without duplicating the request system in `lib/features/company_os/presentation/widgets/approval_journey.dart` and `lib/features/company_os/presentation/pages/employee_finance_page.dart`
- [X] T063 [US3] Route eligible stage notifications to canonical request details with deduplicated Arabic messages in `scripts/company-os/notifications.js` and `lib/services/notification_service.dart`

**Checkpoint**: User Story 3 operates inside the existing request center and
can be rolled back without changing historical HR or payroll data.

---

## Phase 6: User Story 4 — Monitor operations and audit activity (Priority: P2)

**Goal**: Authorized roles use bounded dashboards, search, reports, exports,
and append-only audit history within their server-derived scope.

**Independent Test**: Query ticket, asset, software, employee, report, and audit
fixtures with each role and page size; verify filter/count/cursor agreement,
absence of unauthorized records, and no private notes or secrets.

### Tests for User Story 4

- [X] T064 [P] [US4] Add dashboard projection, supported-filter, cursor, sort, and page-size domain tests in `test/features/company_os/domain/company_operations_query_test.dart`
- [X] T065 [P] [US4] Add Node scope, pagination, search, report, export, audit-redaction, and read-budget tests in `scripts/test/company-os-operations.test.js` and `scripts/test/firestore-read-budget.test.js`
- [X] T066 [P] [US4] Add dashboard, search, report, audit, Arabic empty/error/retry, and responsive RTL widget tests in `test/features/company_os/presentation/company_os_operations_test.dart`

### Implementation for User Story 4

- [X] T067 [P] [US4] Define dashboard projection, scoped query/filter, search result, report row, and audit query entities in `lib/features/company_os/domain/entities/`
- [X] T068 [P] [US4] Define operations dashboard/search/report/audit repository contracts in `lib/features/company_os/domain/repositories/company_os_operations_repository.dart`
- [X] T069 [US4] Implement bounded role-scoped dashboard projections and filter/count endpoints in `scripts/company-os/dashboard.js`
- [X] T070 [US4] Implement bounded global search, report, export, and audit endpoints with server-side scope and private-field exclusion in `scripts/company-os/operations.js`
- [X] T071 [US4] Implement dashboard/search/report/audit data adapters and repository cache in `lib/features/company_os/data/repositories/company_os_operations_repository_impl.dart`
- [X] T072 [US4] Implement focused dashboard, search, reports, and audit Cubits under 300 lines in `lib/features/company_os/presentation/cubit/`
- [X] T073 [US4] Implement role-tailored Arabic operations dashboard, bounded global search, and filter controls in `lib/features/company_os/presentation/pages/company_operations_dashboard_page.dart` and `lib/features/company_os/presentation/pages/company_os_search_page.dart`
- [X] T074 [US4] Implement scoped reports/export and immutable audit explorer pages in `lib/features/company_os/presentation/pages/company_os_reports_page.dart` and `lib/features/company_os/presentation/pages/company_os_audit_page.dart`
- [X] T075 [US4] Add Finance, IT Manager, Manager, Admin, and Super Admin route/navigation surfaces behind `company_os_operations_v1` in `lib/navigation/router.dart` and `lib/navigation/navigation_wrapper.dart`

**Checkpoint**: User Story 4 resolves to bounded data, empty state, or retry
guidance within the selected scope and never exposes client-filtered broad data.

---

## Phase 7: Polish, migration gates, and release readiness

- [X] T076 [P] Audit all Company OS Arabic copy, RTL arrows, keyboard/browser selection, accessibility semantics, mobile, and desktop responsive states in `lib/features/company_os/presentation/` and `test/features/company_os/presentation/`
- [X] T077 [P] Add direct-infrastructure, unbounded query/listener, subscription lifecycle, and Cubit-size safeguards in `test/architecture_guard_test.dart`, `test/firestore_query_guard_test.dart`, and `test/stream_subscription_lifecycle_test.dart`
- [X] T078 [P] Add API rate limits, input size limits, attachment-reference validation, sensitive-log redaction, and abuse tests in `scripts/company-os/security.js` and `scripts/test/company-os-security.test.js`
- [X] T079 Verify one live scheduler per Company OS reminder/report responsibility and document manual recovery ownership in `scripts/HOSTINGER_DEPLOYMENT.md` and `specs/005-internal-company-os/quickstart.md`
- [X] T080 Add legacy/V2 parity fixtures, per-slice metrics, rollback controls, and non-production acceptance evidence template in `test/fixtures/company_os_parity_fixtures.dart` and `specs/005-internal-company-os/quickstart.md`
- [X] T081 Run `flutter analyze`, architecture/query guards, full Flutter tests, full Node tests, and record local release evidence in `specs/005-internal-company-os/quickstart.md`
- [ ] T082 Conduct non-production role-matrix acceptance for all four slices and record authorization, idempotency, privacy, query-budget, and rollback evidence in `specs/005-internal-company-os/quickstart.md`
- [ ] T083 Conduct an owner-reviewed limited pilot with every legacy fallback retained and document metrics, incidents, and rollback verification in `specs/005-internal-company-os/quickstart.md`
- [ ] T084 Switch each Company OS slice from disabled-by-default only after separate explicit owner approval and recorded pilot evidence in `scripts/feature-flags.js` and `specs/005-internal-company-os/quickstart.md`

---

## Phase 8: Requested scope gate — Fully customizable organization structure

**Purpose**: Reconcile the owner-requested organization editor with the
approved Phase 005 design before implementation. This scope replaces the
current fixed/default sector assumptions with stable, server-authorized
organization units while keeping the existing organization screen as the
rollback path.

- [X] T085 Add User Story 5, authorization policy, two-level sector/department boundary, stable-ID/rename/archive behavior, manager/member rules, routing effects, and acceptance scenarios to `specs/005-internal-company-os/spec.md`
- [X] T086 Update the architecture, rollout slice, hierarchy transaction strategy, query limits, migration/rollback approach, and non-production verification plan in `specs/005-internal-company-os/plan.md` and `specs/005-internal-company-os/research.md`
- [X] T087 Define organization unit, manager assignment, employee membership, hierarchy change set, impact preview, and audit fields plus authenticated API operations in `specs/005-internal-company-os/data-model.md` and `specs/005-internal-company-os/contracts/company-os-api.md`
- [X] T088 Obtain owner review of T085–T087 and record the approved organization-management roles, whether a department may be managerless, and how pending requests retain their original approver in `specs/005-internal-company-os/quickstart.md`

**Checkpoint**: Do not start User Story 5 implementation until T085–T088 are
reviewed. No production Firestore rule or existing employee record is changed
by this scope gate.

---

## Phase 9: User Story 5 — Customize sectors, departments, managers, and members (Priority: P1)

**Goal**: An authorized organization administrator can create, rename,
reorder, activate, and archive sectors and departments; place every department
under a sector; assign its active manager; and add, remove, or move employees
through a safe Arabic organization editor without hard-coded sector names or
employee codes.

**Independent Test**: In a non-production fixture, create a sector and two
departments, assign different active managers, bulk-add employees, move one
department and selected employees, reorder the tree, and archive an empty
department. Verify the resulting hierarchy, manager scope, new-request routing,
immutable pending-request approval plan, one audit event per operation, retry
idempotency, and denial for an unauthorized employee.

### Tests for User Story 5

- [X] T089 [P] [US5] Characterize the current fixed-division merge, department move, manager selection, employee profile assignment, and organization-map behavior before replacement in `test/features/organization_structure/legacy_organization_structure_characterization_test.dart`
- [X] T090 [P] [US5] Add domain tests for stable IDs, unique normalized names, sector-to-department containment, deterministic order, archive constraints, managerless policy, inactive-manager rejection, membership moves, and hierarchy-cycle prevention in `test/features/organization_structure/domain/organization_hierarchy_test.dart`
- [X] T091 [P] [US5] Add Node authorization tests for the managed `organization_structure_manage` capability and read scopes across Employee, Manager, HR, Admin, and Super Admin identities in `scripts/test/company-os-organization-authorization.test.js`
- [X] T092 [P] [US5] Add Node idempotency and atomicity tests for create, rename, reorder, manager assignment, bulk membership, archive/restore, impact preview, and changed-payload conflicts in `scripts/test/company-os-organization-operations.test.js`
- [X] T093 [P] [US5] Add routing regression tests proving new requests use the current approved manager relationship while already-materialized approval plans and historical records remain unchanged in `scripts/test/company-os-organization-routing.test.js`
- [X] T094 [P] [US5] Add Arabic RTL widget tests for full hierarchy loading, empty, search, create/edit, drag/reorder, manager vacancy, multi-select members, preview, pending-sync, conflict, denied, and responsive mobile/desktop states in `test/features/organization_structure/presentation/organization_editor_page_test.dart`

### Implementation for User Story 5

- [X] T095 [P] [US5] Define framework-independent organization unit, unit type, manager assignment, employee membership, hierarchy change set, impact preview, validation issue, and versioned snapshot entities in `lib/features/organization_structure/domain/entities/`
- [X] T096 [P] [US5] Define read, edit, impact-preview, manager-assignment, membership, archive/restore, reorder, and sync repository contracts/use cases in `lib/features/organization_structure/domain/repositories/organization_structure_repository.dart` and `lib/features/organization_structure/domain/use_cases/`
- [X] T097 [US5] Implement bounded server-derived organization authorization with active-employment checks and a managed capability instead of client role names or employee-code conditions in `scripts/company-os/organization-authorization.js`
- [X] T098 [US5] Implement paginated hierarchy reads and transactional create/rename/reorder/archive/restore operations for stable sector and department IDs in `scripts/company-os/organization-structure.js`
- [X] T099 [US5] Implement transactional primary-manager assignment/removal with active-manager validation, optional vacancy policy, version conflicts, and retained manager history in `scripts/company-os/organization-managers.js`
- [X] T100 [US5] Implement employee search plus atomic single/bulk add, remove, transfer, department assignment, and direct-manager update operations with dry-run impact previews in `scripts/company-os/organization-membership.js`
- [X] T101 [US5] Preserve already-materialized approval plans while refreshing only future request routing, manager scope projections, department dashboards, and eligible notification recipients after committed hierarchy changes in `scripts/company-os/organization-routing.js` and `scripts/company-os/dashboard.js`
- [X] T102 [US5] Route all organization mutations through operation-ID replay, expected-version checks, append-only audit, safe Arabic errors, rate/input limits, and bounded transactions in `scripts/company-os/router.js`, `scripts/company-os/operation-gateway.js`, and `scripts/company-os/audit.js`
- [X] T103 [US5] Implement organization DTO validation, authenticated API adapter, Drift cache/outbox, retry reconciliation, and legacy read fallback in `lib/features/organization_structure/data/remote/`, `lib/features/organization_structure/data/local/`, and `lib/features/organization_structure/data/repositories/`
- [X] T104 [US5] Implement focused hierarchy, editor, manager-picker, and employee-membership Cubits under 300 lines with saved/pending/conflict/status-check states in `lib/features/organization_structure/presentation/cubit/`
- [X] T105 [US5] Implement a full-width Arabic responsive organization editor with sector/department create, rename, reorder, archive/restore, expandable tree navigation, and accessible keyboard controls in `lib/features/organization_structure/presentation/pages/organization_structure_editor_page.dart`
- [X] T106 [US5] Implement searchable active-manager selection, manager vacancy warnings, employee filtering, multi-select add/remove/move, change summary, destructive-impact confirmation, and partial-selection preservation in `lib/features/organization_structure/presentation/widgets/`
- [X] T107 [US5] Render the read-only organization map from canonical dynamic units and memberships, including vacant managers, archived-unit filtering, counts, and role-derived employee visibility in `lib/features/organization_structure/presentation/pages/organization_structure_map_page.dart`
- [X] T108 [US5] Add the new editor beside `lib/screens/hr/department_performance_screen.dart` behind disabled-by-default `company_os_organization_v1`, retain the legacy screen as fallback, and enforce route capability checks in `lib/navigation/router.dart`, `lib/navigation/navigation_wrapper.dart`, `lib/core/feature_flags/company_os_feature_flags.dart`, and `scripts/feature-flags.js`
- [X] T109 [US5] Add a non-destructive idempotent migration that maps current `organization_divisions`, `departments`, employee department/manager fields, and default inferred sectors to stable units while reporting duplicates, unresolved managers, and orphan employees without applying changes by default in `scripts/company-os/migrate-organization-structure.js`

**Checkpoint**: User Story 5 is independently usable and reversible. Disabling
`company_os_organization_v1` returns users to the existing organization screen;
stable IDs and audit history remain intact, and no pending approval chain is
silently rewritten.

---

## Phase 10: Organization customization hardening and release gates

- [X] T110 [P] Add architecture, Cubit-size, subscription-lifecycle, and bounded organization-query guards in `test/architecture_guard_test.dart`, `test/stream_subscription_lifecycle_test.dart`, and `test/firestore_query_guard_test.dart`
- [X] T111 [P] Add accessibility semantics, Arabic copy, RTL arrow, browser selection, keyboard navigation, mobile overflow, desktop full-width, and large-hierarchy performance coverage in `test/features/organization_structure/presentation/organization_editor_accessibility_test.dart`
- [X] T112 Add dry-run migration, rollback, manager-vacancy, orphan-membership, duplicate-name, concurrent-transfer, request-routing, read-budget, and audit evidence procedures to `specs/005-internal-company-os/quickstart.md`
- [X] T113 Run `flutter analyze`, architecture/query guards, full Flutter tests, full Node tests, and record local organization-slice release evidence in `specs/005-internal-company-os/quickstart.md`
- [ ] T114 Conduct the real non-production organization role matrix, migration dry run, customization journey, retry/idempotency checks, request-routing verification, and rollback rehearsal in `specs/005-internal-company-os/quickstart.md`
- [ ] T115 Conduct an owner-reviewed limited organization pilot with the legacy screen retained and record metrics, incidents, audit verification, and rollback results in `specs/005-internal-company-os/quickstart.md`
- [ ] T116 Switch `company_os_organization_v1` from disabled-by-default only after separate explicit owner approval and accepted T114–T115 evidence in `scripts/feature-flags.js` and `specs/005-internal-company-os/quickstart.md`

## Dependencies and Execution Order

- Setup T001–T006 precedes the foundation.
- Foundation T007–T019 blocks every user story.
- US1, US2, and US3 are P1. Begin US1 after foundation; US2 can proceed from
  the same foundation, while US3 also requires the characterized request seam.
- US4 begins after the shared foundation and consumes only stable story
  repositories/projections; it never broad-reads their backing collections.
- T076–T084 follow the desired stories. T082 requires real non-production
  identities/runtime, T083 requires owner-reviewed pilot access, and T084
  requires a new explicit default-switch approval.
- T085–T088 are a new owner-requested specification/review gate and block all
  US5 implementation. T089–T109 implement US5 beside the legacy organization
  screen; T110–T116 harden and release that slice independently.
- T101 and T109 require approved organization invariants from T085–T088 and the
  characterized request/identity seams from T003–T004. T108 may not default the
  new route, and T116 requires separate approval after real evidence.
- Phase 006 is optional through T019's attachment contract; Company OS remains
  functional when Google Workspace is disabled.

## Parallel Opportunities

- T002–T005 can run in parallel after T001.
- T008–T011, T014, and T016 cover distinct foundation files and can run in
  parallel while the gateway and local outbox are built.
- Within each story, tasks marked `[P]` are independent test/domain work.
- After foundation, US1 and US2 can progress independently; US3 must preserve
  the existing request-center seam characterized by T003/T048.
- T064–T068 can start while stable story projections are being finalized, but
  operations UI must not ship until its scoped endpoints pass T065.
- After T085–T088, US5 domain, Node authorization, routing, and widget tests
  T089–T094 can proceed in parallel. T095–T096 can proceed together; server
  operations T097–T102 precede adapters/state/UI T103–T108.
- T110–T111 can run in parallel after the US5 implementation stabilizes; T114,
  T115, and T116 are sequential external release gates.

## Implementation Strategy

1. Complete setup and foundation without enabling user-facing flags.
2. Deliver US1 as the MVP and validate employee self-scope plus retry safety.
3. Deliver US2 for daily IT operations, then US3 inside the existing request
   center with mandatory Finance and Company Owner approval.
4. Add US4 only on bounded server projections and enable observability before
   any pilot.
5. Keep all legacy HR, request, payroll, attendance, and attachment flows as
   rollback paths until independent evidence and explicit owner approval exist.
6. Treat US5 as a separate Strangler slice: approve its specification first,
   implement canonical server-authorized structure operations, prove migration
   and request-routing behavior, pilot beside the legacy screen, then switch
   only with a separate owner decision.
