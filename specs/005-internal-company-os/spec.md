# Feature Specification: Internal Company OS Foundation

**Feature Branch**: `005-internal-company-os`  
**Created**: 2026-08-20  
**Status**: Approved by owner for planning on 2026-08-23  
**Input**: Approved internal IT-management and Internal Company OS requirements; Google Workspace and Company Workspace are explicitly out of scope.

## User Scenarios & Testing

### User Story 1 - Use one internal operations portal (Priority: P1)

An employee uses the existing ZaWolf identity to see their profile, assigned
assets, software access, personal requests, and relevant knowledge articles.
They can create and track an IT support ticket, access request, or finance
service request without seeing restricted information belonging to others.

**Why this priority**: It creates the shared employee entry point and reuses
the HR identity that already exists rather than creating a second company
system.

**Independent Test**: A test employee can open the Company OS area, submit one
IT ticket, and see only their own ticket and assigned information.

**Acceptance Scenarios**:

1. **Given** an authenticated active employee, **When** they open the internal
   portal, **Then** they see their own profile-linked operational information
   and allowed self-service actions only.
2. **Given** an employee submits an IT ticket, **When** they open its details,
   **Then** they see its lifecycle, public comments, and status without private
   IT notes or other employees' records.
3. **Given** a user does not have an IT, Finance, or management role, **When**
   they attempt to open a management route, **Then** access is denied safely
   and no protected record data is displayed.

---

### User Story 2 - Operate IT tickets and assets safely (Priority: P1)

IT Support and IT Managers manage support tickets, company assets, asset
handover/return history, software licenses, and employee access requests from
one role-scoped operations area.

**Why this priority**: Daily IT work must be usable before broader company OS
modules can rely on it.

**Independent Test**: An IT Support user receives an assigned ticket, updates
its permitted status, records a public resolution, and an IT Manager assigns an
available asset to an employee with a permanent handover record.

**Acceptance Scenarios**:

1. **Given** a new IT ticket, **When** an IT Manager assigns it to an eligible
   IT Support user, **Then** both the assignment and its audit event appear.
2. **Given** an available asset, **When** an authorized user assigns it to an
   employee, **Then** it becomes assigned and its prior history remains intact.
3. **Given** an assigned asset, **When** it is returned or sent for maintenance,
   **Then** its current status changes without deleting the original assignment
   or maintenance evidence.

---

### User Story 3 - Use one approval chain for IT and every cost (Priority: P1)

Employees submit IT, access, and cost-bearing requests through the existing
ZaWolf request center. The same request history, notification approach, and
approval-chain experience are used across HR, IT, and Finance. A request is
routed to the appropriate specialist stage only when its type requires it.

**Why this priority**: The company has one system and one request journey; IT
and Finance must become integrated capabilities rather than separate portals.

**Independent Test**: An employee submits an IT access request, an asset
purchase request, and a reimbursement. Each appears in the existing request
history and reaches the manager, IT, and Finance stages required by its policy.

**Acceptance Scenarios**:

1. **Given** an employee requests access to an approved target, **When** their
   manager approves it, **Then** the existing request record moves to IT review
   and cannot be approved twice.
2. **Given** a request includes a purchase, reimbursement, custody, advance,
   payment, license cost, asset cost, or any other company cost, **When** its
   manager and required IT reviewer approve it, **Then** it moves to Finance
   review and then to the Company Owner for mandatory final approval before a
   payment, purchase, or closure status is recorded.
3. **Given** an approved access or IT service request, **When** IT provisions
   or rejects it, **Then** the employee receives a safe status update and the
   action is part of the same request audit history.

---

### User Story 4 - Monitor operations and audit activity (Priority: P2)

IT Managers, Finance, and authorized administrators view operational
dashboards, global search, reports, and immutable audit history within their
permitted scope.

**Why this priority**: Management needs reliable operational visibility, but it
must not create broad data reads or expose employee data unnecessarily.

**Independent Test**: An IT Manager can filter tickets/assets by status and
department, find an asset by serial number, and open a report whose records
match the selected scope and period.

**Acceptance Scenarios**:

1. **Given** authorized management data, **When** the user filters by status,
   department, date, or owner, **Then** results, counts, and pagination match
   the selected filters.
2. **Given** a mutation to a ticket, asset, license, access request, or finance
   request, **When** an authorized auditor opens history, **Then** actor, time,
   target, action, and before/after change summary are available.

---

### User Story 5 - Customize the organization structure (Priority: P1)

An authorized organization administrator creates and manages the company's
sectors and departments, assigns an active manager to each unit, and places
employees under the correct department and direct manager. The structure is
fully data-driven and does not depend on fixed sector names, department names,
or employee codes.

**Why this priority**: Manager scope, request routing, department reporting,
and employee visibility all depend on an accurate organization structure.

**Independent Test**: Create a sector and two departments, assign managers,
bulk-add employees, move one department and selected employees, reorder the
tree, and archive an empty department. The visible hierarchy and future request
routing update once, while existing approval plans and history stay unchanged.

**Acceptance Scenarios**:

1. **Given** an authorized administrator, **When** they create, rename,
   reorder, activate, or archive a sector or department, **Then** the change is
   validated, audited, and displayed consistently without changing its stable
   identity.
2. **Given** an active employee, **When** the administrator assigns them as a
   sector or department manager, **Then** their new scope applies to future
   requests and permitted management views without exposing unrelated records.
3. **Given** one or more active employees, **When** the administrator previews
   and confirms an add, remove, or transfer operation, **Then** membership and
   direct-manager relationships change atomically or remain unchanged on
   failure.
4. **Given** a request with an already-materialized approval plan, **When** its
   department or manager later changes, **Then** that request retains its
   original approver evidence while new requests use the current structure.
5. **Given** a user without the managed organization capability, **When** they
   attempt any structure mutation, **Then** access is denied safely and no
   hierarchy or employee data is changed.

## Edge Cases

- A duplicated submit caused by retry or a temporary outage must result in one
  request/ticket/assignment only, with a safe pending or status-check message.
- An asset cannot be assigned to two active employees at the same time; a
  conflict must preserve existing history and explain the next action safely.
- Private IT notes must never appear in employee-visible comments, notifications,
  exports, search results, or audit views outside authorized IT scope.
- A license or access seat cannot exceed its approved capacity without an
  authorized explicit override and audit event.
- A terminated or inactive employee retains historical records but cannot create
  new operational requests or receive a new assignment.
- A sector cannot be placed under a department, a department cannot contain a
  sector, and no organization operation may create a hierarchy cycle.
- An organization unit with active child units or employee memberships cannot
  be archived until the administrator previews and resolves those dependencies.
- An inactive employee cannot become a manager. A manager may be removed only
  when the approved manager-vacancy policy permits it, with a visible warning.
- Duplicate normalized names are rejected within the same parent even when
  differences are limited to case, whitespace, or Arabic presentation forms.
- Concurrent moves or manager changes use the latest version and must never
  partially update employee membership, manager scope, or future routing.
- Existing HR attendance, payroll, check-in, leave, permission, and check-out
  policy behavior must not change as a side effect of this phase.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST reuse the existing authenticated employee
  identity, department, manager relationship, and active/inactive employment
  status as the starting point for Company OS authorization.
- **FR-002**: The system MUST provide role-scoped Company OS navigation for
  Employee, IT Support, IT Manager, Finance/Accountant, Manager/Department
  Head, Admin, and Super Admin without changing the meaning of existing HR
  roles.
- **FR-003**: The system MUST extend the existing ZaWolf request center,
  request history, notifications, approval-audit display, and role-scoped
  management views for Company OS request types; it MUST NOT create a separate
  IT or Finance request system.
- **FR-004**: The system MUST provide employee-linked views for assigned assets,
  software access, relevant tickets, access requests, and cost-bearing
  requests.
- **FR-005**: The system MUST support an IT ticket lifecycle of New, Assigned,
  In Progress, Waiting for Employee, Resolved, and Closed, with authorized
  transitions, public comments, private IT notes, attachments, and activity
  history.
- **FR-006**: The system MUST support the approved ticket categories and
  priorities from the requirements specification, including SLA due-state
  visibility.
- **FR-007**: The system MUST manage assets, assignments, returns, maintenance,
  and retirement while retaining immutable assignment and maintenance history.
- **FR-008**: The system MUST manage software/licenses, seat capacity, renewal
  date, cost metadata, and employee assignments without exceeding a license
  capacity unintentionally.
- **FR-009**: The system MUST route IT access requests through employee
  submission, manager decision, IT decision, and provisioning completion;
  each decision must be idempotent and auditable.
- **FR-010**: The system MUST classify every request that creates, changes, or
  reimburses a company cost as a Finance-reviewed request. This includes salary
  advances, reimbursements, custodies, payment requests, asset purchases,
  maintenance/repair costs, software or license purchases/renewals, and other
  operational expenses.
- **FR-011**: A cost-bearing request MUST use the existing approval-chain
  experience and include, in order, the requester, direct-manager review,
  required specialist review (such as IT for IT goods/services), Finance
  review, Company Owner final approval, and payment/closure status. A policy may
  omit a specialist stage only when it is not relevant; Finance review and
  Company Owner final approval may never be omitted for a cost-bearing request.
- **FR-012**: The initial Company Owner approval assignment MUST resolve to the
  active employee whose employee code is `ceo-100`. This assignment MUST be a
  managed approval-policy setting, not a hard-coded client-side condition, so
  an authorized administrator can replace the owner without code changes while
  retaining historical approval evidence.
- **FR-013**: The system MUST provide finance request details, approved cost
  status, payslip viewing, and an employee financial ledger view inside the
  same ZaWolf request and profile experience, without changing existing payroll
  calculation or writing a payroll deduction unless a separately approved
  payroll integration performs that action.
- **FR-014**: The system MUST notify only eligible recipients about relevant
  ticket assignments, status changes, approvals, asset handovers, expiring
  licenses, and finance decisions using safe Arabic user-facing text.
- **FR-015**: The system MUST record every Company OS mutation in an append-only
  audit history with actor, Cairo timestamp, action, target, and safe change
  summary; access to audit data MUST be role scoped.
- **FR-016**: The system MUST provide global search, filters, sorting,
  pagination, and export only for records the current user is allowed to see.
- **FR-017**: The system MUST provide role-tailored dashboards for IT, Finance,
  management, and employees with bounded, selected-scope data and explicit
  empty/loading/retry states.
- **FR-018**: Every new Company OS write MUST expose saved, pending sync,
  conflict, or needs-status-check state without presenting Firebase, HTTP, or
  raw exception text to end users.
- **FR-019**: The system MUST preserve all current HR modules and routes during
  the rollout; a Company OS feature may become the default only after parity,
  tests, non-production acceptance, and an approved rollback path.
- **FR-020**: Google Workspace, Google Drive, Google Sheets, social media,
  WhatsApp, SEO, CRM, external device monitoring, and any bulk historical data
  migration are outside the scope of Phase 005.
- **FR-021**: The system MUST provide a fully data-driven two-level organization
  structure consisting of sectors containing departments and departments
  containing employee memberships; no client may rely on fixed unit names or
  employee codes to construct the hierarchy.
- **FR-022**: An authorized organization administrator MUST be able to create,
  rename, reorder, activate, archive, and restore sectors and departments while
  retaining stable identities and historical references.
- **FR-023**: Every active department MUST belong to exactly one active sector.
  A unit with active dependencies MUST not be archived until an impact preview
  identifies and the administrator resolves its child units, memberships, and
  manager assignment.
- **FR-024**: The system MUST support one current primary manager per sector or
  department and MAY temporarily leave a unit managerless with an explicit
  vacancy warning. Only active employees may be assigned, and every replacement
  MUST retain manager-assignment history.
- **FR-025**: The system MUST support searchable single and bulk employee add,
  remove, and transfer operations. A confirmed change MUST atomically update
  organization membership and the employee's current department/direct-manager
  projection, or update neither.
- **FR-026**: Before a manager, membership, move, or archive mutation, the system
  MUST show a safe impact preview including affected units, employees, future
  routing, and unresolved constraints; destructive changes require explicit
  confirmation.
- **FR-027**: Organization management authorization MUST be derived server-side
  from a managed `organization_structure_manage` capability. It MUST NOT trust
  client role labels or hard-coded employee codes. The approved initial grant
  covers active HR, Admin, and Super Admin administrators and remains editable
  without a client release.
- **FR-028**: Committed hierarchy changes MUST update manager scope, department
  dashboards, eligible notification recipients, and approval routing for new
  requests only. Existing materialized approval plans, payroll allocation,
  attendance history, and audit records MUST remain unchanged.
- **FR-029**: Every organization mutation MUST be versioned, idempotent, and
  append an audit event containing actor, action, target, and safe before/after
  summary. Retry, conflict, pending, and status-check outcomes MUST use Arabic
  user-facing states without raw provider errors.
- **FR-030**: The organization editor MUST provide Arabic RTL search, expandable
  tree navigation, keyboard and browser selection, responsive mobile and
  full-width desktop layouts, multi-select employee operations, and explicit
  loading, empty, denied, offline, pending-sync, conflict, and retry states.
- **FR-031**: Existing organization data MUST be importable through a
  non-destructive dry run that reports duplicate units, orphan employees,
  unresolved managers, and inferred sectors. Applying the migration requires a
  separate confirmation and MUST be safe to retry.
- **FR-032**: The legacy organization screen MUST remain available behind an
  independent rollback path until role-matrix acceptance, migration rehearsal,
  request-routing verification, and owner-reviewed pilot evidence pass.

### Key Entities

- **Operational Role Grant**: A role-specific Company OS capability linked to
  an existing authenticated employee identity.
- **IT Ticket**: A support request with requester, category, priority, owner,
  SLA state, lifecycle, comments, notes, attachments, and activity history.
- **Asset**: A company hardware item with identity, state, location, custody,
  assignment, maintenance, and retirement history.
- **Asset Assignment**: An immutable handover/return record linking an asset,
  employee, operator, time, and condition.
- **Software License**: A product subscription or license allocation with
  capacity, renewal, ownership, cost, and employee seat assignments.
- **Access Request**: An employee request to access a target system, with
  business reason, manager/IT decisions, provisioning outcome, and audit trail.
- **Cost-Bearing Request**: An existing ZaWolf request with a cost type, amount
  where applicable, supporting documents, specialist stage where relevant,
  mandatory Finance and Company Owner stages, payment/closure status, and one
  audit history.
- **Company Owner Approval Assignment**: The managed designation of the active
  final financial approver, initially assigned to employee code `ceo-100`.
- **Financial Ledger Entry**: A read-model entry for an employee's advances,
  custody, reimbursements, earnings, or deductions, with source and status.
- **Knowledge Article**: A searchable internal help article with category,
  content, author, and revision history.
- **Operational Audit Event**: An append-only event describing a Company OS
  mutation and its permitted change summary.
- **Organization Unit**: A stable sector or department record with parent,
  display name, order, active/archive state, version, and audit metadata.
- **Organization Manager Assignment**: Historical and current evidence linking
  one active employee to a unit as its primary manager for an effective period.
- **Organization Membership**: The current and historical placement of an
  employee in a department with a direct-manager projection.
- **Organization Change Set**: A previewed, versioned group of create, move,
  manager, membership, reorder, archive, or restore actions applied atomically.

## Success Criteria

### Measurable Outcomes

- **SC-001**: An employee can submit and track an IT ticket in under three
  minutes, including a safe outcome if connectivity is interrupted.
- **SC-002**: Authorized IT users can assign, update, and close a ticket with a
  visible complete activity history in at most five user actions after opening
  it.
- **SC-003**: An authorized asset handover or return produces exactly one
  current-state change and one retained history record in 100% of tested retry
  and duplicate-submit scenarios.
- **SC-004**: In non-production acceptance, role-scoped search and lists show
  no unauthorized records across Employee, IT Support, IT Manager, Finance,
  Manager, Admin, and Super Admin test accounts.
- **SC-005**: All tested Company OS mutations show Arabic saved/pending/conflict
  or status-check feedback and display no technical provider error to the end
  user.
- **SC-006**: Selected-scope dashboard and list views resolve to records, an
  empty state, or retry guidance within 10 seconds under normal connectivity.
- **SC-007**: An authorized administrator can create a sector and department,
  assign a manager, and add an employee in under three minutes without editing
  the employee from a separate screen.
- **SC-008**: In 100% of tested retry and concurrent-change cases, a hierarchy
  operation produces one complete result and one audit event or changes no
  organization state.
- **SC-009**: Across the non-production role matrix, unauthorized identities
  perform zero organization mutations and receive no out-of-scope employee or
  hierarchy data.
- **SC-010**: For every tested manager or membership change, new request routing
  uses the current structure while all pre-existing approval plans retain their
  original assignee evidence.
- **SC-011**: A hierarchy containing at least 500 employees and 100 units loads
  a usable result, empty state, or retry guidance within 10 seconds without an
  unbounded read.

## Assumptions

- Existing ZaWolf authentication, employee profiles, department names, manager
  relationships, notification infrastructure, Cairo timezone, and safe-error
  foundation remain the authoritative shared platform services.
- Phase 005 is a modular, additive rollout; it does not replace the existing
  HR/payroll/attendance core or alter its Firestore rules until separately
  reviewed.
- IT Manager is a dynamic role/capability determined from the current user role
  and permissions; no employee code is hard-coded.
- Organization editing is initially available to active HR, Admin, and Super
  Admin users through a managed server capability. The policy can later add or
  remove eligible roles without changing the client.
- A department or sector may temporarily have no manager so restructures do not
  require fake employee assignments; the UI must show a vacancy and new request
  routing must follow the approved fallback policy.
- Employee membership has one canonical department and one direct-manager
  projection at a time. Historical membership and manager assignments are
  retained for audit and reporting.
- Initial attachments use the existing approved application attachment pattern;
  any new storage provider, retention policy, or malware scanning integration
  requires a dedicated later decision.
- Accounting payment execution, payroll posting, external provisioning, and
  external integration APIs are represented by auditable status steps in the
  existing request journey rather than automatic external actions.
