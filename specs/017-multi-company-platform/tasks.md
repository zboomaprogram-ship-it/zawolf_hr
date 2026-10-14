# Tasks: 7DHUB Multi-Company Platform

**Status**: Draft — owner review required before implementation

**Input**: Design documents from `specs/017-multi-company-platform/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: Required by the repository constitution. For each behavior task,
write or identify the failing characterization/contract test first, confirm the
expected failure, then implement the smallest passing change.

**Organization**: Tasks are grouped by user story. Production Firestore-rule
deployment, production migration apply, second-company activation, store
submission, and default-route switching are explicitly outside these tasks and
require separate owner-approved runbooks.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes different files and has no
  dependency on an incomplete task in the same phase.
- **[Story]**: Maps the task to a user story from `spec.md`.

---

## Phase 1: Setup and Inventory Scaffolding

**Purpose**: Establish feature boundaries, flags, fixtures, and mechanical
guards without changing live behavior.

- [ ] T001 Create the clean-architecture directory/readme skeleton in `lib/features/platform_management/README.md`, `lib/features/company_context/README.md`, and `lib/core/tenancy/README.md`
- [ ] T002 [P] Define disabled-by-default platform, context, branding, per-slice, and company-creation feature keys in `lib/core/feature_flags/multi_company_feature_flags.dart`
- [ ] T003 [P] Add the matching server-owned flag registry and audience validation in `scripts/platform/feature-flags.js`
- [ ] T004 [P] Create the company-sensitive collection/route/job inventory schema and initial registry in `scripts/platform/migrations/ownership-inventory.js`
- [ ] T005 [P] Create reusable Flutter two-company identity and membership fixtures in `test/fixtures/multi_company_fixtures.dart`
- [ ] T006 [P] Create reusable Node two-company, global-role, suspended, and out-of-scope fixtures in `scripts/test/fixtures/multi-company-fixtures.js`
- [ ] T007 Extend layer and Cubit-size enforcement for `platform_management`, `company_context`, and `core/tenancy` in `test/architecture_guard_test.dart`
- [ ] T008 Extend company-scope query lint fixtures and expected violations in `test/firestore_query_guard_test.dart`

**Checkpoint**: New feature structure exists, every switch is off, and live
single-company behavior is unchanged.

---

## Phase 2: Foundational Tenant Safety

**Purpose**: Introduce shared identity, context, authorization, idempotency, and
offline boundaries that block all user-story implementation.

**⚠️ CRITICAL**: No user story may switch routes or write tenant data until this
phase passes its characterization and foundation tests.

### Failing characterization tests

- [ ] T009 [P] Characterize current single-role authentication and dashboard routing before separating platform/company authority in `test/features/company_context/legacy_identity_routing_characterization_test.dart`
- [ ] T010 [P] Characterize current Hostinger role resolution, hard-coded executive aliases, and company-wide bypasses in `scripts/test/platform-legacy-authorization-characterization.test.js`
- [ ] T011 [P] Add a failing two-company Firestore emulator matrix proving the current rules can list/read cross-company records in `scripts/test/platform-firestore-isolation.test.js`
- [ ] T012 [P] Characterize current `zawolf` company defaults and deterministic attendance/payroll identifiers in `test/features/company_context/legacy_company_defaults_characterization_test.dart` and `scripts/test/platform-critical-id-characterization.test.js`
- [ ] T013 [P] Characterize current scheduler, notification, deep-link, and recovery-workflow lack of company scope in `scripts/test/platform-worker-scope-characterization.test.js`

### Domain and server foundation

- [ ] T014 [P] Define `CompanyId`, `CompanyLifecycle`, `CompanyContextState`, and `ActiveCompanyContext` domain values in `lib/core/tenancy/domain/company_context.dart`
- [ ] T015 [P] Define platform capability, sensitive scope, authority source, and effective grant domain values in `lib/core/tenancy/domain/platform_authority.dart`
- [ ] T016 [P] Define tenant operation identity, company-bound receipt, safe conflict, and context mismatch outcomes in `lib/core/tenancy/domain/tenant_operation.dart`
- [ ] T017 Implement authenticated person, company lifecycle, membership, and platform-grant resolution in `scripts/platform/authorization/tenant-context-resolver.js`
- [ ] T018 Implement managed platform/company capability derivation without client role trust in `scripts/platform/authorization/capability-policy.js`
- [ ] T019 Make operation identity, receipt lookup, payload hash, and audit company-aware in `scripts/platform/tenant-operation-gateway.js`
- [ ] T020 [P] Add platform-safe error normalization for company inactive, membership inactive, scope mismatch, conflict, and status-check outcomes in `scripts/platform/safe-errors.js`
- [ ] T021 Mount authenticated `/platform/v1` routing with explicit global-versus-company route guards in `scripts/platform/router.js` and `scripts/notification-web.js`

### Flutter and offline foundation

- [ ] T022 Implement the domain-facing authenticated tenant operation client and context header/path matching in `lib/core/tenancy/data/tenant_operation_client.dart`
- [ ] T023 Implement `(uid, companyId)` cache/outbox namespace keys and cross-company replay rejection in `lib/core/tenancy/data/tenant_namespace_store.dart`
- [ ] T024 Wire remote multi-company flags into app composition while keeping every route disabled in `lib/main.dart` and `lib/core/feature_flags/remote_multi_company_feature_flags.dart`

**Checkpoint**: Identity proves only the person; every new operation resolves an
explicit company or declared global capability; tenant receipts and offline keys
cannot collide across companies.

---

## Phase 3: User Story 1 — Create and Activate a Company (Priority: P1) 🎯 First Reviewable Increment

**Goal**: A Platform Super Admin can create a draft company, configure required
operating settings, assign CEO/HR leadership, preview completeness, and activate,
suspend, restore, or archive it safely.

**Independent Test**: Create an incomplete draft, verify activation is blocked,
assign one CEO and two HR administrators, activate it once, repeat the operation
ID, then suspend/restore it while preserving history and audit.

### Tests for User Story 1

- [ ] T025 [P] [US1] Add failing company lifecycle and activation-completeness domain tests in `test/features/platform_management/company_lifecycle_test.dart`
- [ ] T026 [P] [US1] Add failing company registry/lifecycle API contract and pagination tests in `scripts/test/platform-companies.test.js`
- [ ] T027 [P] [US1] Add failing leadership minimum, invitation identity-linking, duplicate membership, and idempotency tests in `scripts/test/platform-company-bootstrap.test.js`
- [ ] T028 [P] [US1] Add failing Firestore emulator tests for company, leadership, membership, invitation, entitlement, receipt, and audit paths in `scripts/test/platform-company-rules.test.js`
- [ ] T029 [P] [US1] Add failing company setup/lifecycle Cubit tests for loading, incomplete, conflict, saved, and status-check states in `test/features/platform_management/company_setup_cubit_test.dart`
- [ ] T030 [P] [US1] Add failing Arabic RTL/responsive company registry and setup wizard widget tests in `test/features/platform_management/company_setup_page_test.dart`

### Implementation for User Story 1

- [ ] T031 [P] [US1] Implement Company, leadership assignment, feature entitlement, invitation, and activation-report domain entities in `lib/features/platform_management/domain/entities/company.dart`
- [ ] T032 [US1] Define company lifecycle/bootstrap repository contracts and preview/apply use cases in `lib/features/platform_management/domain/repositories/platform_company_repository.dart` and `lib/features/platform_management/domain/use_cases/manage_company_lifecycle.dart`
- [ ] T033 [US1] Implement transactional company, leadership, invitation, entitlement, operation-receipt, and audit persistence in `scripts/platform/companies/company-store.js`
- [ ] T034 [US1] Implement draft/create/update/preview/activate/suspend/restore/archive policy with expected versions and impact tokens in `scripts/platform/companies/company-lifecycle.js`
- [ ] T035 [US1] Implement effective-dated CEO/Company HR assignment and final-leader protection in `scripts/platform/companies/company-leadership.js`
- [ ] T036 [US1] Implement invite-existing-person, create-invitation, accept, expire, and duplicate-membership behavior in `scripts/platform/memberships/company-invitations.js`
- [ ] T037 [P] [US1] Implement company feature-entitlement preview/apply behavior separately from user permission in `scripts/platform/companies/company-entitlements.js`
- [ ] T038 [US1] Expose company registry, lifecycle, leadership, invitation, and entitlement endpoints from `scripts/platform/router.js`
- [ ] T039 [US1] Add tenant-safe control-plane rules and required indexes in `firestore.rules` and `firestore.indexes.json` without deploying them
- [ ] T040 [US1] Implement platform-company API DTO mapping and repository adapter in `lib/features/platform_management/data/platform_company_repository_impl.dart`
- [ ] T041 [P] [US1] Implement focused registry, setup, leadership, and lifecycle Cubits in `lib/features/platform_management/presentation/cubit/company_registry_cubit.dart`, `company_setup_cubit.dart`, and `company_lifecycle_cubit.dart`
- [ ] T042 [US1] Build Arabic RTL/responsive company registry, setup wizard, leadership picker, activation checklist, and impact dialog in `lib/features/platform_management/presentation/pages/company_registry_page.dart` and `company_setup_page.dart`
- [ ] T043 [US1] Add disabled-by-default global management routes and composition entry in `lib/navigation/platform_management_entry.dart` and `lib/navigation/router.dart`

**Checkpoint**: Company lifecycle works independently behind a disabled switch;
no ordinary company user can discover the registry or activate a company.

---

## Phase 4: User Story 2 — Govern All Companies Globally (Priority: P1)

**Goal**: Platform Super Admin, multiple independently scoped General HR users,
explicitly delegated cross-company managers, and members of global shared-service
departments can use their bounded global views/approval pools without inheriting
unassigned employee access or silent impersonation. Platform Super Admin sees
and manages all company operations; Global HR sees complete HR, salary, payroll,
deduction, attendance, request, employee, performance, task, report, and HR-file
data across every company in scope, with mutation and platform-secret powers
controlled separately.

**Independent Test**: Compare Platform Super Admin, two differently scoped
General HR users, payroll-enabled General HR, a manager delegated selected
employees in two companies, two Global Accounting members racing on one pool
step, Company HR, and employee access across registry, managed-work, health,
audit, grant, lifecycle, and salary-sensitive probes.

### Tests for User Story 2

- [ ] T044 [P] [US2] Add failing platform `view`/`sensitive_view`/`manage`/`decide`/`export` separation, grant-expiry, self-approval, incompatible-duty, distinct-actor/dual-control, plus global-department membership/company/request-scope matrix tests in `scripts/test/platform-global-authorization.test.js`
- [ ] T045 [P] [US2] Add failing complete Super Admin/Global HR cross-company summary, salary/payroll/deduction visibility, canonical drill-down reconciliation, registry health, global audit redaction, normalized Arabic/English search, authorization-before-count/facet, stable sort, filter-bound cursor, saved-view revalidation, pagination, and no-impersonation tests in `scripts/test/platform-global-management.test.js`
- [ ] T046 [P] [US2] Add failing Firestore emulator tests for own grant/department membership visibility, global-department administration, global audit, and company-health projection in `scripts/test/platform-global-rules.test.js`
- [ ] T047 [P] [US2] Add failing grant, registry-health, global search/filter/sort/saved-view, allowed-action, and global-audit Cubit tests in `test/features/platform_management/global_management_cubit_test.dart`
- [ ] T048 [P] [US2] Add failing Arabic RTL/responsive global dashboard, organization tree, search/filter/sort, read-only action state, grant editor, and audit widget tests in `test/features/platform_management/global_management_page_test.dart`

### Implementation for User Story 2

- [ ] T049 [P] [US2] Implement independent multi-holder platform grants, cross-company manager delegation, global department/membership, federated organization/job references, module governance capability dimensions, saved views, safe tenant health, and global audit filter domain entities in `lib/features/platform_management/domain/entities/platform_governance.dart`
- [ ] T050 [US2] Define global governance repository contracts and grant/global-department/organization/search/saved-view/health/audit use cases in `lib/features/platform_management/domain/repositories/platform_governance_repository.dart` and `lib/features/platform_management/domain/use_cases/manage_platform_governance.dart`
- [ ] T051 [US2] Implement effective-dated multi-holder platform grants, cross-company manager delegations, and global department/member preview/create/update/revoke with per-recipient access-revision invalidation in `scripts/platform/authorization/platform-grants.js`, `scripts/platform/authorization/manager-delegations.js`, and `scripts/platform/authorization/global-departments.js`
- [ ] T052 [US2] Implement append-only global/company audit indexes with field redaction and actual authority-source recording in `scripts/platform/audit/platform-audit.js`
- [ ] T053 [US2] Implement bounded per-company HR/operational summary projections covering workforce, attendance, requests/approvals, payroll/salary/deductions, performance/tasks, jobs/integrations, and alerts without copying raw records or private chat content in `scripts/platform/companies/tenant-health.js` and `scripts/platform/companies/global-operations-summary.js`
- [ ] T054 [US2] Implement bounded registry and cross-module global search with authorization-before-match/count, Arabic/English normalization, whitelisted stable sort, filter-bound cursor, access-revalidated saved views, company-origin labels, and server-calculated allowed actions in `scripts/platform/companies/company-registry.js` and `scripts/platform/search/global-search.js`
- [ ] T055 [US2] Expose grant, global-department/member, federated organization/job catalog, global search/saved-view, shared-work-inbox, health, registry, and global-audit endpoints with sensitive-scope and action-capability enforcement in `scripts/platform/router.js`
- [ ] T056 [US2] Add indexes and rules for grants, global departments/memberships, bounded shared-work projections, health, and global/company audit views in `firestore.rules` and `firestore.indexes.json` without deploying them
- [ ] T057 [US2] Implement global governance, complete authorized operations-summary/drill-down, federated organization/job catalog, global search/sort/filter/saved views, global-department administration, allowed-action mapping, and shared-work inbox API/repository mapping in `lib/features/platform_management/data/platform_governance_repository_impl.dart`
- [ ] T058 [P] [US2] Implement focused all-company HR operations dashboard, company comparison/drill-down, federated organization, search/saved-view, grant editor, global-department editor, shared-work inbox, health, and audit Cubits in `lib/features/platform_management/presentation/cubit/global_dashboard_cubit.dart`, `global_operations_cubit.dart`, `global_organization_cubit.dart`, `global_search_cubit.dart`, `platform_grant_cubit.dart`, `global_department_cubit.dart`, `global_department_work_cubit.dart`, `tenant_health_cubit.dart`, and `global_audit_cubit.dart`
- [ ] T059 [US2] Build the Arabic RTL/responsive global command center with all-company workforce, attendance, requests/approvals, salary/payroll/deductions, performance/tasks, reports/files, alerts, federated organization/job tree, search/filter/stable sort/saved views, explicit view/manage/decide/export states, comparison, canonical company drill-down, tenant health, grants, global departments, shared work, and audit in `lib/features/platform_management/presentation/pages/global_management_dashboard_page.dart`, `global_operations_page.dart`, `global_organization_page.dart`, `global_search_page.dart`, `platform_grants_page.dart`, `global_departments_page.dart`, `global_department_work_page.dart`, and `global_audit_page.dart`
- [ ] T060 [US2] Add capability-guarded global navigation that displays active company and authority without impersonation in `lib/navigation/navigation_wrapper.dart` and `lib/navigation/router.dart`

**Checkpoint**: Global management is usable with least privilege and complete
actor/company/authority audit, while Company HR remains tenant-only.

---

## Phase 5: User Story 3 — Join and Switch Company Context (Priority: P1)

**Goal**: One person can hold multiple company memberships, automatically enter
one valid company or choose among several, and switch all permission, cache,
navigation, notification, and branding context together.

**Independent Test**: Give one UID Company A and B memberships, queue offline A
work, switch to B, reconnect, revoke A, and open A deep links without showing A
data in B or submitting A work under B.

### Tests for User Story 3

- [ ] T061 [P] [US3] Add failing person/membership/context selection and revocation domain tests in `test/features/company_context/company_context_policy_test.dart`
- [ ] T062 [P] [US3] Add failing `/me/companies` and context-resolution API tests for one, multiple, expired, suspended, and global-grant access in `scripts/test/platform-company-context.test.js`
- [ ] T063 [P] [US3] Add failing Drift/cache/outbox namespace tests for switch, logout, revoked access, and cross-company replay in `test/features/company_context/tenant_namespace_store_test.dart`
- [ ] T064 [P] [US3] Add failing company picker, switch overlay, restored selection, and stale-route widget tests in `test/features/company_context/company_selector_page_test.dart`
- [ ] T065 [P] [US3] Add failing notification/deep-link company validation and safe switch-prompt tests in `test/features/company_context/company_notification_route_test.dart`
- [ ] T066 [P] [US3] Add failing membership uniqueness, identity linking, access-projection, and access-revision tests in `scripts/test/platform-memberships.test.js`

### Implementation for User Story 3

- [ ] T067 [P] [US3] Implement Person Identity, Company Membership, access projection, and context receipt entities in `lib/features/company_context/domain/entities/company_access.dart`
- [ ] T068 [US3] Define company access repository, choose/switch/revalidate use cases, and stream-shutdown contract in `lib/features/company_context/domain/repositories/company_context_repository.dart` and `lib/features/company_context/domain/use_cases/switch_company_context.dart`
- [ ] T069 [US3] Implement server-owned per-user company-access projection and repair behavior in `scripts/platform/memberships/user-company-access.js`
- [ ] T070 [US3] Implement membership create/activate/suspend/terminate policy with within-company employee-code uniqueness in `scripts/platform/memberships/company-memberships.js`
- [ ] T071 [US3] Implement `/platform/v1/me/companies` and `/me/company-context` endpoints with lifecycle and access-revision checks in `scripts/platform/router.js`
- [ ] T072 [US3] Implement secure company-selection persistence and `(uid, companyId)` local namespace storage in `lib/features/company_context/data/company_context_local_store.dart`
- [ ] T073 [US3] Implement remote context API and repository adapters in `lib/features/company_context/data/company_context_repository_impl.dart`
- [ ] T074 [US3] Implement a focused company selection/switch Cubit that closes old streams before exposing the new namespace in `lib/features/company_context/presentation/cubit/company_context_cubit.dart`
- [ ] T075 [US3] Build Arabic RTL/responsive automatic-entry, company picker, switch progress, revoked, suspended, offline, denied, and retry states in `lib/features/company_context/presentation/pages/company_selector_page.dart`
- [ ] T076 [US3] Add a company-context shell gate before role dashboard routing in `lib/navigation/company_context_entry.dart` and `lib/navigation/router.dart`
- [ ] T077 [US3] Add company namespace adapters for existing shared operation outboxes and local caches in `lib/core/sync/authenticated_operation_client.dart` and `lib/core/sync/workspace_operation_outbox.dart`
- [ ] T078 [US3] Add company ID and membership revalidation to local notification routing and active-company switch prompts in `lib/services/notification_service.dart` and `lib/navigation/notification_route.dart`
- [ ] T079 [US3] Add company-scoped notification target validation and OneSignal payload fields in `scripts/dispatch-notifications.js` and `scripts/notification-routing.js`
- [ ] T080 [US3] Revalidate company access on app resume/token change/logout and clear visible stale-company state in `lib/main.dart` and `lib/services/auth_service.dart`

**Checkpoint**: A multi-company person can switch safely; a single-company user
enters automatically; revocation and stale links fail closed.

---

## Phase 6: User Story 5 — Operate HR Independently Within Each Company (Priority: P1)

**Goal**: Every existing HR/ERP vertical slice reads, writes, caches, schedules,
exports, and notifies within exactly one company, allowing duplicate business
codes/names across companies without collisions.

**Independent Test**: Run matching organization, request, attendance, payroll,
task, chat, file, notification, dashboard, and report journeys in Companies A
and B and prove zero cross-company results or identifier collisions.

### Cross-company failing tests

- [ ] T081 [P] [US5] Build the reusable API/rules cross-company role matrix runner in `scripts/test/platform-tenant-isolation-matrix.test.js`
- [ ] T082 [P] [US5] Add failing Firestore tests for get/list/query/create/update/delete leakage across every inventoried company-owned collection in `scripts/test/platform-all-collections-rules.test.js`
- [ ] T083 [P] [US5] Add failing static query-guard fixtures for missing `companyId`/tenant path in repositories and scripts in `test/firestore_query_guard_test.dart` and `scripts/test/firestore-read-budget.test.js`
- [ ] T084 [P] [US5] Add failing federated organization ownership, cycle/orphan/ambiguous-primary prevention, vacant position, job-catalog override, reorganization route stability, user/employee-code collision, multi-company manager delegation, unassigned-employee denial, and manager-routing isolation tests in `scripts/test/platform-organization-isolation.test.js`
- [ ] T085 [P] [US5] Add failing request, approval-plan immutability, local/global department target distinction, eligible snapshot, self-approval and incompatible-duty denial, distinct-actor/dual-control, no-eligible blocked state, concurrent first-decision-wins, custom-type, and search/export isolation tests in `scripts/test/platform-request-isolation.test.js`
- [ ] T086 [P] [US5] Add failing attendance/location/schedule/leave/permission/day-off/timezone/deterministic-ID isolation tests in `scripts/test/platform-attendance-isolation.test.js`
- [ ] T087 [P] [US5] Add failing payroll-cycle/deduction/salary/advance/reward/report isolation and current-company parity tests in `scripts/test/platform-payroll-isolation.test.js`
- [ ] T088 [P] [US5] Add failing direct/group chat, membership, archive/mute, message, media, and upload/download isolation tests in `scripts/test/platform-conversation-isolation.test.js`
- [ ] T089 [P] [US5] Add failing tasks/productivity/notification/dashboard/report/workspace/file isolation tests in `scripts/test/platform-operational-isolation.test.js`

### Ownership and trusted-boundary implementation

- [ ] T090 [US5] Complete the platform-global/company-owned/person-private classification and module coverage registry for every live collection, route, cache, job, export, and integration—including notifications, chat/media, requests, meetings, reports, records/files/workspace, Company Services and Support, employee/request management, rewards/warnings, leave/permissions, attendance, locations, payroll/deductions, tasks/productivity, hiring, resignation, and configurable tools—with required ownership, capability, search, routing, audit, cache, report, retention, migration, and test evidence in `scripts/platform/migrations/ownership-inventory.js`
- [ ] T091 [US5] Add shared Firestore tenant helper rules, immutable ownership checks, and deny-by-default coverage for inventoried records in `firestore.rules`
- [ ] T092 [US5] Implement the federated global/company organization and job model; make memberships, branches, units, positions, primary/functional managers, employee search, and cross-company manager delegation explicitly owned, effective-dated, cycle-safe, sortable/filterable, and company-scoped in `scripts/company-os/organization-firestore-store.js`, `scripts/company-os/organization-routing.js`, and `lib/features/organization_structure/data/remote/organization_structure_api.dart`
- [ ] T093 [US5] Make custom request types, approval chains, request creation/decision/search/history, global-department pool snapshot/resolution, staffing alerts, and view/manage/decide/export separation company-scoped and idempotent; enforce self-approval, incompatible-duty, and distinct-actor rules in `scripts/configurable-requests.js`, `scripts/request-approval-routing.js`, `scripts/request-decision-operations.js`, and `lib/features/request_visibility/data/firestore_request_visibility_data_source.dart`
- [ ] T094 [US5] Make attendance action IDs, access grants, device bindings, location assignments, and policy resolution company-scoped while preserving existing semantics in `scripts/attendance-gateway.js`, `scripts/web-attendance-access.js`, `scripts/attendance-location-assignments.js`, and `lib/services/attendance_policy_service.dart`
- [ ] T095 [US5] Make daily absence, reminder, automatic attendance, permission reconciliation, and early-leave reconciliation resolve explicit company timezone/policy in `scripts/daily-tasks.js`, `scripts/attendance-reminders.js`, `scripts/auto-attendance.js`, and `scripts/early-leave-reconciliation.js`
- [ ] T096 [US5] Make payroll cycle IDs, reads, outputs, and close checkpoints company-scoped without changing cycle or amount rules in `scripts/payroll-cycle.js` and `scripts/monthly-tasks.js`
- [ ] T097 [US5] Make deductions, advances, warnings/rewards, payslip summaries, and finance ledger company-scoped in `lib/services/manual_deduction_service.dart`, `scripts/company-os/finance.js`, and `scripts/company-os/employee-portal.js`
- [ ] T098 [P] [US5] Make tasks, monthly tasks, productivity/KPI, sales mappings, and sales sync company-scoped in `scripts/monthly-tasks.js`, `scripts/sales-kpi-sync.js`, and `lib/services/task_service.dart`
- [ ] T099 [US5] Make conversation discovery, channel membership, direct eligibility, message identity, search, read state, mute, and archive company-scoped in `scripts/conversations/router.js`, `scripts/conversations/direct-policy.js`, and `scripts/conversation-operations.js`
- [ ] T100 [US5] Bind attachment upload/finalize/download/delete/cache descriptors to conversation company and authorization in `scripts/conversations/uploads.js`, `scripts/conversations/drive-media-provider.js`, and `lib/features/conversations/data/rich_chat_repository_impl.dart`
- [ ] T101 [US5] Make notification documents, global-department pool fan-out/resolution cleanup, unread counters, recipient projections, push deduplication, deep links, and module-origin labels company-scoped; support global/delegated recipients without exposing forbidden previews in `scripts/dispatch-notifications.js`, `scripts/sync-notification-recipients.js`, and `lib/services/notification_service.dart`
- [ ] T102 [US5] Make management dashboards, visual analysis, HR period reports, operational timelines, global HR summary projections, canonical drill-downs, and exports accept server-applied company/global scope plus authorized search/filter/stable sort and separate sensitive-view/export capabilities in `scripts/company-os/dashboard.js`, `lib/features/dashboard_visual_analysis/data/firestore_dashboard_visual_analysis_repository.dart`, `lib/features/hr_period_reports/data/firestore_hr_period_report_repository.dart`, and `scripts/operational-visibility.js`
- [ ] T103 [US5] Make Company Workspace resource grants, navigation, audit, Sheets reports, and file descriptors company-scoped in `scripts/workspace/authorization.js`, `scripts/workspace/resource-navigation.js`, `scripts/workspace/audit.js`, `scripts/workspace/reports.js`, and `lib/features/company_workspace/data/repositories/company_workspace_repository_impl.dart`
- [ ] T104 [US5] Make Company OS tickets, assets, software, finance requests, announcements, search, and audit company-scoped in `scripts/company-os/router.js`, `scripts/company-os/authorization.js`, `lib/features/company_os/data/remote/company_os_api_client.dart`, and `lib/features/company_os/data/repositories/company_os_operations_repository_impl.dart`
- [ ] T105 [P] [US5] Make manual attendance, web attendance, meetings, hiring, and configurable request repositories consume active company context; extend the approval-chain domain/editor/timeline with visibly distinct local/global department targets, eligibility validation, blocked state, and actual pool decision actor in `lib/features/manual_attendance/data/manual_attendance_repository_impl.dart`, `lib/features/web_attendance_access/data/web_attendance_access_repository_impl.dart`, `lib/features/meeting_requests/data/meeting_repository_impl.dart`, `lib/features/hiring_request/data/hiring_request_repository_impl.dart`, `lib/features/configurable_requests/data/configurable_requests_repository_impl.dart`, `lib/features/request_approval_routing/domain/entities/approval_stage.dart`, `lib/features/request_approval_routing/presentation/pages/approval_chains_settings_page.dart`, and `lib/components/request_approval_timeline.dart`

### Scheduler, cache, and presentation isolation

- [ ] T106 [US5] Implement bounded active-company enumeration with entitlement/lifecycle filtering in `scripts/platform/workers/tenant-job-enumerator.js`
- [ ] T107 [US5] Implement per-company job lease, policy snapshot, checkpoint, and deterministic run identity in `scripts/platform/workers/tenant-job-lease.js`
- [ ] T108 [US5] Route live daily attendance/absence/reminder work through tenant enumeration without creating a second scheduler in `scripts/notification-web.js` and `scripts/daily-tasks.js`
- [ ] T109 [US5] Route payroll close and monthly jobs through explicit company/cycle work items and company checkpoints in `scripts/monthly-tasks.js` and `.github/workflows/monthly-tasks.yml`
- [ ] T110 [US5] Route notification queue drain and conversation push through explicit company batches with membership revalidation in `scripts/notification-web.js` and `scripts/dispatch-notifications.js`
- [ ] T111 [US5] Add explicit company parameters and guarded all-company recovery mode to export/integration recovery jobs in `.github/workflows/daily-tasks.yml`, `.github/workflows/monthly-tasks.yml`, `.github/workflows/dispatch-notifications.yml`, and `scripts/google-sheets-integration.js`
- [ ] T112 [US5] Introduce company-context repository factories for migrated feature composition in `lib/core/tenancy/data/company_scoped_repository_factory.dart`
- [ ] T113 [US5] Make dashboard, request management, employee management, attendance, payroll, and task entry routes rebuild only after an active context switch; add a bounded company-labelled managed-work inbox for cross-company managers in `lib/navigation/router.dart`, `lib/navigation/navigation_wrapper.dart`, and `lib/features/platform_management/presentation/pages/managed_work_page.dart`
- [ ] T114 [US5] Make chat inbox/channel and company workspace entries close old streams and open the selected company namespace in `lib/navigation/rich_conversation_entry.dart` and `lib/navigation/company_workspace_v2_entry.dart`
- [ ] T115 [US5] Make report/export screens label company origin and prevent stale-company results after switches in `lib/features/hr_period_reports/hr_period_reports_entry.dart` and `lib/screens/hr/sheets_export_screen.dart`
- [ ] T116 [US5] Namespace remaining shared preferences, Drift rows, downloaded media, and in-memory stream registries by UID/company in `lib/core/tenancy/data/tenant_cache_registry.dart`
- [ ] T117 [US5] Generate and review the complete module governance/tenancy coverage matrix, then run the two-company business parity/isolation suite for every enabled module in `specs/017-multi-company-platform/evidence/module-governance-matrix.md` and `specs/017-multi-company-platform/evidence/tenant-isolation-matrix.md`

**Checkpoint**: Both companies can execute equivalent HR journeys with duplicate
business labels/codes, different policies/timezones, and zero cross-company
reads, writes, cache leakage, notifications, or job collisions.

---

## Phase 7: User Story 6 — Migrate the Current Organization Safely (Priority: P1)

**Goal**: Inventory, dry-run, idempotently assign, reconcile, and pilot all
current ZaWolf records as the first company without guessing ambiguous ownership
or losing the legacy rollback route.

**Independent Test**: Migrate a production-shaped fixture, interrupt and resume
the apply, reconcile every business area, compare critical screens/counts with
baseline, and disable the new route without removing proven ownership.

### Tests for User Story 6

- [ ] T118 [P] [US6] Add failing ownership-inventory completeness tests that detect unclassified collections/routes/jobs/caches in `scripts/test/platform-ownership-inventory.test.js`
- [ ] T119 [P] [US6] Add failing migration dry-run classification, ambiguity quarantine, no-write, and sensitive-redaction tests in `scripts/test/platform-initial-company-migration.test.js`
- [ ] T120 [P] [US6] Add failing interrupted-page, rerun-idempotency, receipt, checkpoint, and reconciliation-hash tests in `scripts/test/platform-migration-resume.test.js`
- [ ] T121 [P] [US6] Add failing current-company attendance/payroll/request/chat/report parity tests around migration and route rollback in `scripts/test/platform-migration-parity.test.js`
- [ ] T122 [P] [US6] Add failing migration dashboard Cubit/widget tests for preview, issue pages, pause, resume, reconcile, blocked, and complete states in `test/features/platform_management/migration_dashboard_test.dart`

### Implementation for User Story 6

- [ ] T123 [US6] Implement inventory enumeration and stable record classification for platform-global, company-owned, person-private, ambiguous, invalid, and blocked items in `scripts/platform/migrations/inventory-runner.js`
- [ ] T124 [US6] Implement no-write initial-company dry run with bounded pages, evidence hashes, and redacted issue summaries in `scripts/platform/migrations/initial-company-dry-run.js`
- [ ] T125 [US6] Implement explicit ambiguity resolution records and prevent unresolved items from apply in `scripts/platform/migrations/migration-issues.js`
- [ ] T126 [US6] Implement resumable/idempotent ownership apply pages with company-bound receipts and checkpoints in `scripts/platform/migrations/initial-company-apply.js`
- [ ] T127 [US6] Implement per-business-area counts, relationship checks, deterministic-ID collision checks, and reconciliation hash in `scripts/platform/migrations/migration-reconciliation.js`
- [ ] T128 [US6] Implement current-company compatibility projections for legacy user role/manager/company fields without rewriting historical approvals in `scripts/platform/migrations/legacy-company-projections.js`
- [ ] T129 [US6] Expose preview/status/issues/approve/apply-page/pause/reconcile endpoints with separate migration capability in `scripts/platform/router.js`
- [ ] T130 [US6] Define migration batch, issue, progress, reconciliation, and parity domain entities/repository contracts in `lib/features/platform_management/domain/entities/company_migration.dart` and `lib/features/platform_management/domain/repositories/company_migration_repository.dart`
- [ ] T131 [US6] Implement migration API/repository mapping and status polling in `lib/features/platform_management/data/company_migration_repository_impl.dart`
- [ ] T132 [US6] Implement focused migration preview, issue review, execution status, and reconciliation Cubits in `lib/features/platform_management/presentation/cubit/company_migration_cubit.dart`
- [ ] T133 [US6] Build Arabic RTL/responsive migration dashboard and issue/reconciliation views in `lib/features/platform_management/presentation/pages/company_migration_page.dart`
- [ ] T134 [US6] Add per-slice legacy/new read and write switches that preserve tenant authorization during rollback in `scripts/platform/migrations/tenant-slice-switches.js` and `lib/core/feature_flags/multi_company_feature_flags.dart`
- [ ] T135 [US6] Write the non-production rehearsal, production approval gates, backup verification, pause, rollback-route, and reconciliation runbook in `specs/017-multi-company-platform/migration-runbook.md`

**Checkpoint**: Every current record is assigned, intentionally global, or
quarantined; no second production company may activate until reconciliation is
complete and separately approved.

---

## Phase 8: User Story 4 — Experience Company Branding Inside 7DHUB HR (Priority: P2)

**Goal**: Publish accessible company branding for authenticated mobile/web
experiences, reports, exports, and communications while 7DHUB HR remains the
installed/store identity and reliable fallback.

**Independent Test**: Publish distinct A/B branding; test live refresh, offline
cache, invalid media/colors, reports/exports, signed-out fallback, web title/icon,
and unchanged 7DHUB installed identity.

### Tests for User Story 4

- [ ] T136 [P] [US4] Add failing branding validation, lifecycle, checksum, variant, accessibility, official 7DHUB baseline-token, and fallback domain tests in `test/features/platform_management/company_branding_policy_test.dart`
- [ ] T137 [P] [US4] Add failing governed branding upload/finalize/publish authorization and company-isolation tests in `scripts/test/platform-company-branding.test.js`
- [ ] T138 [P] [US4] Add failing theme contrast, cached update, fallback, RTL, and company-switch widget tests in `test/features/company_context/company_branding_shell_test.dart`
- [ ] T139 [P] [US4] Add failing web title/favicon and signed-out 7DHUB identity tests in `test/features/company_context/web_branding_test.dart`
- [ ] T140 [P] [US4] Add failing report/export/notification company-name/logo projection tests in `test/features/platform_management/branded_output_test.dart` and `scripts/test/platform-branded-notifications.test.js`

### Implementation for User Story 4

- [ ] T141 [P] [US4] Implement branding profile, logo descriptor, color palette, validation result, and publication-state domain entities in `lib/features/platform_management/domain/entities/company_branding.dart`
- [ ] T142 [US4] Define branding repository and validate/preview/publish use cases in `lib/features/platform_management/domain/repositories/company_branding_repository.dart` and `lib/features/platform_management/domain/use_cases/publish_company_branding.dart`
- [ ] T143 [US4] Implement governed logo upload sessions, content validation, bounded variants, checksums, and opaque descriptors without Firebase Storage in `scripts/platform/branding/branding-media.js`
- [ ] T144 [US4] Implement color contrast, display-name, version conflict, publish/supersede, and 7DHUB fallback policy in `scripts/platform/branding/company-branding.js`
- [ ] T145 [US4] Expose branding read/upload/finalize/preview/publish endpoints with company/global capabilities in `scripts/platform/router.js`
- [ ] T146 [US4] Implement branding API/repository adapter and versioned local cache in `lib/features/platform_management/data/company_branding_repository_impl.dart`
- [ ] T147 [P] [US4] Implement focused branding editor and active-branding Cubits in `lib/features/platform_management/presentation/cubit/company_branding_cubit.dart` and `lib/features/company_context/presentation/cubit/active_branding_cubit.dart`
- [ ] T148 [US4] Build the Arabic RTL/responsive logo/color preview, accessibility guidance, draft, publish, conflict, and fallback editor in `lib/features/platform_management/presentation/pages/company_branding_page.dart`
- [ ] T149 [US4] Vendor the owner-approved `7dhub.co` wordmark/icon with recorded checksums and create accessible dynamic company theme extensions derived from the documented 7DHUB green/graphite design tokens in `assets/branding/7dhub/`, `lib/theme/company_theme.dart`, and `lib/theme/theme.dart`
- [ ] T150 [US4] Apply company name/logo/theme to the authenticated shell and restore bundled 7DHUB fallback before context selection in `lib/main.dart` and `lib/navigation/navigation_wrapper.dart`
- [ ] T151 [US4] Apply branding descriptors and company origin to reports, exports, notifications, and company communications in `lib/features/hr_period_reports/presentation/hr_period_report_page.dart`, `lib/screens/hr/sheets_export_screen.dart`, and `scripts/dispatch-notifications.js`
- [ ] T152 [US4] Update web signed-out title/favicon/manifest to 7DHUB and switch authenticated title/icon from active branding in `web/index.html`, `web/manifest.json`, and `lib/features/company_context/presentation/web_company_branding.dart`
- [ ] T153 [US4] Update the Android launcher label/icon and iOS bundle display name/primary icon to 7DHUB HR in `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`, `ios/Runner/Info.plist`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`, and their declared density/size companion assets
- [ ] T154 [US4] Document optional prepackaged alternate-icon constraints and store-listing rename steps without promising a dynamic iOS label in `docs/releases/7dhub_hr_rebrand.md`

**Checkpoint**: Authenticated branding is tenant-specific and accessible;
missing/invalid branding always falls back to 7DHUB HR; no company creation
requires a mobile release unless an optional launcher icon is requested.

---

## Phase 9: Cross-Cutting Verification, Security, and Release Readiness

**Purpose**: Prove scale, isolation, parity, rollback, and review readiness.
These tasks prepare evidence and artifacts only; they do not execute production
migrations, deploy rules, activate a second production company, or submit stores.

- [ ] T155 [P] Add 100-company/10,000-membership bounded registry, picker, normalized Arabic/English search, filters, stable sorting, saved views, federated organization tree, complete Global HR/Super Admin operations dashboard, canonical total/drill-down reconciliation, audit, and report performance/read-budget fixtures in `scripts/test/platform-multi-company-scale.test.js`
- [ ] T156 [P] Add Android/iOS/web Arabic RTL company selection, switching, branding, federated organization/search/filter/sort, read-only versus actionable states, denied, suspended, offline, conflict, and retry acceptance coverage in `integration_test/multi_company_journey_test.dart`
- [ ] T157 [P] Add scheduler overlap, differing timezone/workweek, suspension, checkpoint, deterministic-ID, and recovery-mode tests in `scripts/test/platform-tenant-scheduler.test.js`
- [ ] T158 Add automated ownership-inventory completeness and missing-company-scope checks to required CI in `.github/workflows/test.yml` and `scripts/package.json`
- [ ] T159 Review and document Firestore indexes, rules diff, authorization-before-search/count/facet behavior, normalized-token exposure, stable cursor/read budgets, and rollback prerequisites in `specs/017-multi-company-platform/evidence/security-and-query-review.md`
- [ ] T160 Review and document organization, notifications, chat/media, requests/approvals, meetings, reports/exports, records/workspace, Company Services and Support, employee/request management, rewards/warnings, permissions/leave, attendance/locations, payroll/deductions, tasks/productivity, hiring/resignation, and configurable-tools current-company parity plus second-company isolation in `specs/017-multi-company-platform/evidence/critical-business-parity.md`
- [ ] T161 Run the full validation sequence from `specs/017-multi-company-platform/quickstart.md` and record command/results in `specs/017-multi-company-platform/evidence/quickstart-results.md`
- [ ] T162 Run `flutter analyze`, architecture/query guards, all Flutter tests, and all Node tests; record exact results in `specs/017-multi-company-platform/evidence/required-checks.md`
- [ ] T163 Prepare the owner-review rollout checklist for control plane, current-company pilot, each slice switch, branding release, and later second-company activation in `specs/017-multi-company-platform/rollout-checklist.md`
- [ ] T164 Update platform administrator and company administrator guidance without exposing credentials in `docs/7dhub_platform_admin_guide_ar.md` and `docs/7dhub_company_admin_guide_ar.md`

---

## Dependencies and Execution Order

### Phase dependencies

1. **Phase 1 — Setup** starts immediately and changes no live behavior.
2. **Phase 2 — Foundation** depends on Phase 1 and blocks every story.
3. **US1 — Company lifecycle** depends on Phase 2.
4. **US2 — Global governance** depends on the US1 company registry but can
   develop grant/audit tests alongside late US1 UI work.
5. **US3 — Company context** depends on US1 memberships and the Phase 2 resolver;
   it is required before tenant business routes can switch.
6. **US5 — Independent company operations** depends on US3 context and is the
   mandatory tenant-safety gate for a second company.
7. **US6 — Current-company migration** may begin inventory/dry-run work after
   Phase 2, but apply/parity/rollback tasks depend on the corresponding US5
   vertical slices.
8. **US4 — Branding** depends on US3 active context; its server media work can
   proceed beside US5/US6 because it uses separate paths.
9. **Phase 9 — Verification** depends on every story included in the release.

### User-story dependency graph

```text
Setup -> Foundation -> US1 Company Lifecycle
                         |
                         +-> US2 Global Governance
                         |
                         +-> US3 Company Context -> US5 Tenant Operations -> US6 Migration Completion
                                                  |
                                                  +-> US4 Dynamic Branding
All selected stories -------------------------------------------------> Final Verification
```

US1 is independently demonstrable in a non-production draft-only environment.
US2 is independently testable against draft companies. US3 is independently
testable with fixture memberships. US5 validates equivalent workflows in two
fixture companies. US6 validates a production-shaped copy. US4 validates
branding while falling back to 7DHUB.

## Parallel Opportunities

### Foundation

After T008, characterization tasks T009–T013 can run in parallel. Domain tasks
T014–T016 can run in parallel before server/client adapters consume them.

### User Story 1

Tests T025–T030 can be written in parallel. After T032, server lifecycle work
T033–T037 can be divided by file; Flutter Cubits T041 can proceed once the
repository contract is stable.

### User Story 2

Tests T044–T048 can run in parallel. Grant, audit, health, and registry services
T051–T054 touch separate modules and can run in parallel after T050.

### User Story 3

Tests T061–T066 can run in parallel. Access projection T069, membership policy
T070, and local store T072 can proceed in parallel after the contracts exist.

### User Story 5

Characterization/isolation tasks T081–T089 are parallel. After shared ownership
and rules tasks T090–T091, vertical slices T092–T105 can be assigned separately,
then worker tasks T106–T111 and presentation/cache tasks T112–T116 converge in
T117.

### User Story 6

Tests T118–T122 can run in parallel. UI contracts T130–T133 can proceed against
fixtures while migration engine tasks T123–T129 are implemented.

### User Story 4

Tests T136–T140 can run in parallel. Branding media/policy T143–T145, Flutter
repository/Cubits T146–T147, and native/web preparation T152–T154 can proceed in
parallel after the domain contracts are stable.

## Implementation Strategy

### First reviewable increment

1. Complete Phase 1 and Phase 2.
2. Complete US1 behind `platform_control_plane_v1` with company activation
   restricted to non-production fixtures.
3. Validate company lifecycle, leadership, idempotency, audit, and rules.
4. Stop for owner review; do not enable company creation in production.

### Usable platform pilot

1. Add US2 global governance.
2. Add US3 company selection/context.
3. Pilot only the current company with all new routes still reversible.
4. Add US5 one vertical slice at a time, starting with identity/organization and
   requests, then attendance/payroll, then chat/files/reports/workers.
5. Rehearse US6 continuously; complete reconciliation before second-company use.
6. Add US4 branding and ship the 7DHUB native/store rebrand as a separate
   reviewed release action.

### Production safety boundary

The following remain off until T155–T164 pass and the owner separately approves
the exact production runbook: production Firestore rules deployment, migration
apply, current-company default switch, `multi_company_creation_v1`, second
production company activation, native store submission, and legacy retirement.

## Notes

- `[P]` indicates file-level parallel work, not permission to skip dependencies.
- Story tests must fail for the intended missing behavior before implementation.
- Every task preserves unrelated dirty worktree changes.
- Every new company-owned query must be bounded and mechanically guarded.
- Every mutation must retain company-bound idempotency and actual-actor audit.
- Legacy deletion is a later reviewed retirement feature.
