# Implementation Plan: 7DHUB Multi-Company Platform

**Branch**: `017-multi-company-platform` | **Date**: 2026-10-10 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/017-multi-company-platform/spec.md`

## Summary

Turn the current single-company ZaWolf HR product into the shared **7DHUB HR**
platform. Introduce a global control plane for company lifecycle, platform role
grants, global shared-services departments, entitlements, migration, health,
and cross-company audit. Introduce a
company data plane in which every identity membership, business record,
operation, cache entry, notification, attachment descriptor, scheduled job,
and report has one authoritative company scope.

Delivery follows a Strangler Fig migration. The current organization becomes
the first tenant. A server-resolved company context and additive ownership
fields/projections protect legacy slices while new multi-company slices use
tenant-native paths and contracts. No second company can activate until the
existing data is reconciled, cross-company isolation tests pass, and the owner
approves production rules, migration, and route switching.

## Technical Context

**Language/Version**: Dart 3.9 / Flutter 3.x; Node.js JavaScript on Hostinger

**Primary Dependencies**: Flutter BLoC/Cubit, go_router, Drift, http, Firebase
Authentication, Cloud Firestore, OneSignal, existing governed media provider

**Storage**: Firestore remains the canonical remote store; Drift provides
identity-and-company-namespaced UI cache/outbox; branding uses the governed
authorized media path and does not introduce Firebase Storage

**Testing**: flutter_test, architecture/query guards, Firestore emulator rules
matrix, Node.js built-in test runner, migration reconciliation fixtures,
Android/iOS/web acceptance

**Target Platform**: Android, iOS 15+, responsive web, Hostinger Node runtime,
GitHub Actions recovery jobs

**Project Type**: Existing Flutter clients plus authenticated Node operation
gateway and Firestore data/rules

**Performance Goals**: company switch reaches a usable cached state within 5
seconds; bounded global/company lists reach data, empty, denied, or retry state
within 10 seconds; complete global oversight uses bounded projections and
company drill-downs rather than raw cross-company client scans

**Constraints**: Arabic RTL; one explicit company per ordinary operation;
global and company roles are separate; no client-trusted role/company scope;
payroll and attendance semantics preserved; idempotent writes; no silent
impersonation; no unbounded listeners; no production migration/rules/default
switch without separate approval and rollback

**Scale/Scope**: initial acceptance at 100 companies, 10,000 memberships, one
shared mobile/store application, multiple independently scoped General HR
users, cross-company managers with explicit employee/team delegations, global
Accounting/HR/Legal/IT approval pools with independently scoped members,
multiple company memberships per person, current ZaWolf tenant migrated first

## Constitution Check

### Pre-design gate

- **Strangler Fig**: PASS. The tenant control plane, context resolver, and new
  data plane are additive. Existing routes remain available until each slice
  proves tenant parity and is deliberately switched.
- **Layer boundaries**: PASS. Domain contracts own tenant identity, context,
  authorization, company lifecycle, and operation outcomes. Flutter
  presentation does not import Firestore, HTTP, or concrete data adapters.
- **Focused Cubits**: PASS. Company selection, company registry, company setup,
  branding, global grants, tenant health, and migration status have separate
  presentation-state owners, each kept below 300 lines.
- **Payroll and attendance safety**: PASS with mandatory characterization.
  Company scoping is introduced without changing cycle calculations,
  deduction rules, approval/execution dates, deterministic attendance IDs, or
  reconciliation behavior. Company is added to deterministic identity where
  needed to prevent collisions.
- **Test-first delivery**: PASS. Failing isolation, migration, rules, query,
  scheduler, payroll, and attendance characterization tests precede each
  migrated vertical slice.
- **Offline/sync**: PASS. Local data and outbox keys include authenticated UID
  and company ID. Pending operations cannot replay in a different context.
- **Scheduled ownership**: PASS. Hostinger remains the live integration runtime
  where currently documented; GitHub workflows remain explicit recovery paths.

### Post-design gate

PASS. Research, data model, contracts, and validation guide retain all gates.
The plan adds no architecture exception. Production rule deployment, migration
apply, company activation, and default-route switching remain separately
approved operational actions.

## Architecture

```text
                         7DHUB global management
       companies | grants | global departments | health | audit | migration
                                  |
Firebase identity ---> server tenant-context resolver <--- platform grants
                                  |
                    explicit authorized company context
                                  |
        +-------------------------+--------------------------+
        |                         |                          |
 Flutter domain APIs      Hostinger operation API     scheduled workers
        |                         |                          |
 company-scoped Drift     tenant authorization        tenant leases/checkpoints
 cache + outbox           + idempotency receipt       + bounded tenant work
        |                         |                          |
        +---------------- company-owned canonical data ----------------+
```

The control plane contains only platform-level identity, companies, global
grants, global department definitions/memberships, entitlements, health
and HR operational summaries, migration state, and global audit.
Company business data is never copied into the control plane for convenience.
Cross-company dashboards consume complete, authorized, safe per-company
projections and open canonical company records for detail.

Authentication proves the person. Authorization is resolved for each request
from active platform grants or the requested company's active membership. A
client-provided company ID selects a requested context but never grants access.
The server returns an effective context receipt containing company, membership,
role/capabilities, policy/branding versions, and expiry/revision information.

## Migration Architecture

The current data model includes global collections, role labels that combine
platform and company authority, hard-coded `zawolf` defaults, and permissive
company reads. A direct rewrite would risk payroll, attendance, request, chat,
and notification failures. Migration therefore proceeds in reviewed slices:

1. **Control-plane foundation**: Introduce person identity, company registry,
   platform grants, global shared-services departments, company memberships,
   access projection, entitlements, and tenant context. Register the current
   company but keep tenant routing off.
2. **Ownership inventory**: Enumerate every collection, subcollection, file
   descriptor, cache table, route, API, query, scheduled job, notification,
   export, and integration. Classify it as platform-global, company-owned, or
   user-private-with-company-context.
3. **Initial-company backfill**: Dry-run and then idempotently attach the first
   company to resolvable records. Quarantine ambiguity. Preserve all old fields
   and paths during compatibility.
4. **Trusted-boundary enforcement**: Make rules and Hostinger operations require
   matching company context and resource ownership. Direct legacy reads remain
   only where a tested compatibility rule can enforce the same boundary.
5. **Vertical-slice migration**: Migrate identity/organization, requests,
   attendance, payroll/deductions, tasks, chat/media, notifications, reports,
   and integrations independently. New writes use tenant-native contracts;
   compatibility projections serve remaining legacy readers.
6. **Offline and scheduler isolation**: Namespace Drift/outbox data, introduce
   tenant leases/checkpoints, and prove notification/deep-link company checks.
7. **Branding and 7DHUB rebrand**: Switch in-app/web shell and reports to
   tenant branding with a bundled 7DHUB fallback derived from the approved
   `7dhub.co` source assets and documented checksums. Ship store name, launcher
   identity, and app icon as a reviewed native release while retaining
   bundle/package IDs.
8. **Pilot and activation**: Run the current company in tenant mode, reconcile
   parity, then activate one non-production/pilot second company. Production
   company creation stays disabled until owner approval.

Each slice has a read switch, write switch, compatibility projection, parity
report, rollback procedure, and explicit retirement follow-up. Legacy code is
not deleted during this feature.

## Project Structure

### Documentation

```text
specs/017-multi-company-platform/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── platform-management-api.md
│   └── tenant-context-contract.md
└── checklists/
    └── requirements.md
```

### Source Code

```text
lib/core/tenancy/
├── domain/
└── presentation/

lib/features/platform_management/
├── data/
├── domain/
└── presentation/

lib/features/company_context/
├── data/
├── domain/
└── presentation/

scripts/platform/
├── authorization/
├── companies/
├── memberships/
├── branding/
├── migrations/
└── audit/

scripts/company-os/                 # adapted only at tenant-aware seams
scripts/test/
test/core/tenancy/
test/features/platform_management/
test/features/company_context/
```

**Structure Decision**: `platform_management` owns global company lifecycle and
governance. `company_context` owns selecting and resolving one company for the
authenticated person. Stable tenant primitives may enter `lib/core/tenancy`
only after both features prove the shared contract. Existing feature folders
remain in place and adopt tenant contracts one vertical slice at a time.

## Global Oversight Experience

The global dashboard is an operational command center rather than only a
company registry. It supports all-company summary, comparison, filtering, alert
and drill-down experiences while preserving the company origin of every value.

**Platform Super Admin** receives complete read and management visibility across
all companies: company setup and policy, organization and employees, attendance,
leave and permissions, requests and approvals, payroll/salary/deductions,
performance and tasks, reports and files, integrations, operational health,
and audit. Every action is executed as the actual administrator inside an
explicit target company context.

**Global HR** receives complete read visibility across all permitted companies
for employee profiles, organization, attendance, leave, permissions, requests,
approval history, payroll, salary, deductions, performance, task status, HR
reports, and HR files. Global HR can search a person across companies, compare
company/department results, see pending and abnormal conditions, and drill into
the exact company record. Creating, changing, approving, exporting, or deleting
data is controlled by separate mutation capabilities.

Platform credentials, developer settings, security administration, billing,
company lifecycle actions, and private direct-message contents remain separate
capabilities. Global HR can see communication activity/audit needed for HR
oversight; message content requires an explicit compliance/legal capability.

The dashboard includes at least:

- active/inactive workforce and organization changes by company;
- today's attendance, late, absence, permission, leave, mission, and no-check-in
  conditions plus period trends;
- pending requests and approvals by company, category, age, and responsible
  approver or global department;
- payroll-cycle state, salary/deduction totals and exceptions, with authorized
  employee-level drill-down;
- performance, productivity, overdue-task, and manager-action signals;
- unresolved migration/configuration issues, failed jobs/integrations,
  notification failures, and other operational alerts;
- company, department, employee, request type, status, and date filters with
  export only when export authority is present.

Global management uses server-side search, filters, sorting, and cursor
pagination. Search normalizes Arabic/English text and supports company,
employee name/code/email, organization unit, job family/title, request type,
status, responsible actor, and period. Results always show company origin and
the server-calculated allowed actions. Saved views store presentation choices,
not authority; reopening one revalidates every company, field, and action.

## Federated Organization and Job Architecture

The platform presents one governed hierarchy without merging tenant ownership:

```text
7DHUB Platform
├── Global Management and Shared Services
│   ├── Global HR
│   ├── Global Accounting
│   ├── Global IT
│   └── Global Legal
└── Companies
    └── Company
        └── Legal entity / branch
            └── Department
                └── Team
                    └── Position
                        └── Company membership
```

Global nodes and each company's nodes have different owners and authorization
boundaries even when the UI renders them in one tree. A platform job catalog
provides stable job families and titles; companies may use audited local labels
or policy overrides. A position is separate from its occupant and may be vacant.
Each membership has one active primary placement and may have effective-dated
functional, dotted-line, or cross-company manager relationships.

Every node, position, reporting edge, and placement is versioned,
effective-dated, audited, and validated against cycles, orphaned parents,
ambiguous primary managers, and invalid company ownership. Approval routing
materializes the organization/policy version and eligible actors when work is
submitted, so later reorganization does not rewrite an open or completed flow.

## Visibility, Management, and Approval Boundaries

Authorization is expressed as separate `view`, `sensitive_view`, `manage`,
`decide`, and `export` capabilities for each module and scope.

| Actor | May view | May manage | May approve or reject |
|---|---|---|---|
| Platform Super Admin | All companies and platform operations | Platform/company configuration allowed by explicit capabilities | Only when explicitly targeted or granted business decision authority |
| General HR | Complete HR data in granted companies, including sensitive fields when granted | Only the HR mutations named in the grant | Only a configured chain/pool/delegation step in which the actor remains eligible |
| Global department member | Safe summaries for assigned shared-service work | Department administration only when separately granted | Only the materialized pool steps within company/request scope |
| Cross-company manager | Assigned employees, teams, and work with company labels | Only delegated management actions | Only routed/delegated decisions for assigned scope |
| Company HR/manager | Own-company data permitted by company role | Own-company permitted actions | Own-company configured approval steps |

The service never derives action authority from visibility or a title. It
prevents requester self-approval, incompatible duties, same-actor stages where
separation is required, and duplicate decisions. Optional dual control requires
two distinct valid actors. Each response declares presentation-safe allowed
actions, but the trusted decision endpoint revalidates the current actor,
scope, materialized step, conflict policy, and version atomically.

## Cross-Module Tenancy and Governance Matrix

The ownership inventory contains one mandatory row for every live module:

| Module group | Required tenant-ready coverage |
|---|---|
| Notifications and deep links | Company ownership, global/delegated recipient scope, deduplication, company-labelled routing, mute/archive state, audit |
| Chat and media | Company/channel membership, direct-chat policy, bounded search, uploads/downloads/cache, private-content capability, retention |
| Requests and request management | Company/request ownership, local/global targets, searchable history, materialized approvals, conflict rules, staffing alerts |
| Meetings | Rooms, participants, approvals, calendar/history, reminders, attendance, company/global visibility |
| Reports and exports | Company-labelled filters, periods, sensitive columns, totals/drill-down reconciliation, export capability, audit |
| Records, files, and workspace | Resource grants, folders/files, search, media authorization, download cache, retention, audit |
| Company Services and Support | Tickets, assets, software, finance services, announcements, assignment, SLA/status, search, audit |
| Employee and organization management | Memberships, placements, positions, reporting lines, job catalog, transfers, manager delegations, lifecycle |
| Rewards, warnings, payroll, and deductions | Company policy/cycle, salary scope, reason/evidence, calculations, approvals, reports, immutable history |
| Attendance, leave, permissions, and locations | Schedules, branches/geofences, assignments, devices/web access, reconciliation, reminders, timezone, approvals |
| Tasks, productivity, and sales | Ownership, assignee/manager scope, KPI mappings, status, reports, notifications, cross-company delegation |
| Hiring, resignation, and configurable tools | Candidate/new-employee scope, approval routing, effective dates, documents, onboarding/offboarding, audit |

Every row must define ownership, read and sensitive-read audiences, mutation and
decision authority, server-side search/filter/sort, notification/deep-link
behavior, cache/offline namespace, reports/exports, retention, audit, and
automated parity/isolation evidence. A central coverage check blocks tenant
activation if an enabled live module lacks any required surface.

## Data and Query Strategy

- Control-plane collections are small, bounded, and readable only through
  platform capabilities or a user's own company-access projection.
- Canonical company-owned records carry immutable `companyId`; tenant-native
  records live below a company boundary where practical. Legacy top-level
  collections add indexed company ownership during strangler migration.
- A server-owned per-user company-access projection supports sign-in/company
  selection without scanning companies or memberships.
- Company/member IDs use opaque stable identifiers. Employee code uniqueness is
  enforced within a company; operation receipts use `companyId + operationId`
  to prevent cross-company replay/collision.
- Global pages use precomputed complete per-company HR/operational summaries for
  authorized fields. They do not download every raw employee, attendance,
  request, or payroll record; details use bounded server-side company queries.
- Global departments and memberships remain control-plane records. Their
  actionable inbox is a bounded company-labelled projection; full requests
  remain company-owned and are opened through their company context.
- Every list requires a whitelisted stable sort, supported filters, page size,
  and filter-bound cursor. Query guards reject missing company filters on
  company-owned collections. Search indexes contain normalized Arabic/English
  tokens and authorized projection fields only; authorization is applied before
  search, counts, facets, or suggestions are calculated.
- Drift tables and file-cache keys include UID and company ID. Logout revokes
  access to cached bytes; company switching closes current streams before
  exposing the next namespace.
- Branding assets use opaque authorized media descriptors, checksums, bounded
  variants, and versioned cache keys. No public provider URL becomes canonical.
- Audit is append-only and partitioned by company plus a safe global index for
  authorized cross-company review.

## Authorization Model

1. Verify the identity token and active person state.
2. Resolve requested company and its lifecycle state.
3. Resolve active platform grants and active membership for that company.
4. For a global department decision, resolve the materialized eligible snapshot
   and revalidate the actor's active department membership/capability.
5. Derive separate view, sensitive-view, manage, decide, and export capabilities
   from managed policies; never accept submitted roles or infer decisions from
   visibility.
6. Verify resource company ownership and operation scope.
7. Enforce expected revision, idempotency identity, and transition policy.
8. Commit business change, operation receipt, and company audit atomically
   where the underlying operation permits.
9. Return only safe fields and safe outcome codes.

Platform Super Admin has complete cross-company read and management visibility,
but every operation still requires an explicit target company and produces
audit. Global HR has complete HR read visibility, including payroll, salary,
and deductions, across every company in the grant scope. Mutation/decision
authority and platform security, billing, lifecycle, developer, credential, or
private-message-content access remain separate capabilities.

Global departments provide bounded shared-service authority rather than global
company access. Approval-chain publication validates department lifecycle,
company/request scope, and at least one eligible decision maker. Request
submission snapshots eligible actors and policy versions. The first valid
approve/reject operation wins through a server transaction and idempotency
receipt; subsequent attempts receive `already_decided`. If every snapshotted
actor loses eligibility, the step becomes visibly blocked for governed
escalation and is never skipped automatically.

## Scheduler and Integration Strategy

- Enumerate eligible active companies in bounded pages.
- Acquire a company/job/period lease before running company work.
- Load the company's timezone, policy version, and feature entitlement.
- Use deterministic IDs that include company, business date/cycle, employee,
  and job/action identity.
- Persist per-company checkpoint and safe summary; retries resume/converge.
- A suspended company follows the configured suppression/finalization policy
  and is never processed through another company's defaults.
- Notification queue entries include company ID; dispatch revalidates
  membership, mute/archive state, and target resource before delivery.
- GitHub recovery workflows require explicit company/range parameters or a
  reviewed all-company recovery mode and never compete with the live worker.

## Verification Strategy

- Characterize every current company-sensitive route and query before changing
  it, especially payroll, attendance, approvals, chat, and scheduled work.
- Domain tests cover company lifecycle, membership overlap, leadership minimums,
  global/company capability separation, global department scope and pool-step
  resolution, branding validation, and context expiry.
- Firestore emulator tests use at least two companies and all platform/company
  roles to prove zero cross-company discovery, reads, writes, and list leakage.
- Node contract tests cover context mismatch, ownership, global grants/global
  departments, concurrent first-decision-wins approval, idempotency, audit,
  normalized search, filter-bound cursors, stable sorting, saved-view
  revalidation, pagination, safe serialization, suspension, and retry.
- Organization tests cover global/company node ownership, positions versus
  occupants, job catalog overrides, primary/functional reporting lines, cycle
  and orphan prevention, and immutable in-flight routing after reorganization.
- A generated cross-module coverage report proves ownership, visibility/action
  separation, search/filter/sort, notification, audit, cache, reporting, and
  isolation behavior for every enabled module before activation.
- Migration tests cover dry-run counts, ambiguous quarantine, interrupted apply,
  rerun convergence, parity reconciliation, and rollback routing.
- Flutter tests cover Arabic RTL, company picker, context switch, stale links,
  cached/offline states, branding fallback, permission changes, complete global
  oversight, company-labelled drill-downs, and responsive web.
- Global oversight reconciliation tests compare every dashboard total and
  filtered drill-down with canonical company fixture results for Platform Super
  Admin and Global HR, including salary/payroll/deduction visibility.
- Scheduled-job tests cover two companies with different timezone/policy values,
  overlapping workers, suspension, deterministic IDs, and bounded read budgets.
- Existing payroll-cycle and attendance/absence characterization suites remain
  green for the initial company before and after tenant routing.
- Full required checks run before handoff. Production rollout additionally
  requires migration rehearsal, security/rules review, and owner approval.

## Rollout and Rollback

Feature controls are layered:

- `platform_control_plane_v1`: creates inactive control-plane records.
- `company_context_v1`: resolves tenant context for selected pilot users.
- `tenant_scoped_<slice>_v1`: one flag per migrated vertical slice.
- `tenant_branding_v1`: company branding with 7DHUB fallback.
- `multi_company_creation_v1`: remains off until all mandatory gates pass.

Rollback disables the affected read/write route and returns the current company
to its legacy adapter. Additive company ownership, audit, receipts, and
migration evidence remain intact. Rollback never removes company IDs or rewrites
business history. Once a second production company owns business data, global
rollback to an unscoped single-company model is forbidden; rollback must be per
slice within the tenant-safe platform.

## Complexity Tracking

No constitution violation is required. The temporary coexistence of legacy
top-level records and tenant-native records is the deliberate Strangler Fig
compatibility layer, bounded by feature switches, parity reports, and a later
reviewed retirement change.
