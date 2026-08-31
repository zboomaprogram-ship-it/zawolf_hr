# Research: Internal Company OS Foundation

## Decision 1: Extend the existing ZaWolf request center

**Decision**: Access requests and every cost-bearing request use one normalized
request aggregate, history, notification route, and approval-chain renderer.

**Rationale**: The owner explicitly rejected separate IT and Finance request
systems. A normalized request envelope lets current HR requests keep their
behavior while specialist stages are added only where policy requires them.

**Alternatives considered**: Separate ticket/request collections with separate
approval screens were rejected because they duplicate authorization, create
missing-request regressions, and split the employee history.

## Decision 2: Policy-driven cost approval

**Decision**: The server classifies cost-bearing requests and materializes a
versioned approval plan: direct manager, relevant specialist, Finance, Company
Owner, then payment/closure. Finance and owner cannot be skipped. The initial
owner policy resolves active employee code `ceo-100`, but clients never
hard-code that code.

**Rationale**: This preserves historical evidence when roles or employees
change and prevents a manipulated client from omitting approval stages.

**Alternatives considered**: Client-generated chains and role-name-only lookup
were rejected because both are mutable and unsafe for financial approval.

## Decision 3: Operation gateway plus local outbox

**Decision**: All new mutations use the authenticated Hostinger operation API,
client-generated operation IDs, expected aggregate versions, a Drift outbox,
and server transactions that write state plus audit atomically.

**Rationale**: This matches the constitution and the existing safe check-in and
Workspace foundations. It handles retries without duplicate tickets,
assignments, payments, or approvals.

**Alternatives considered**: Direct client Firestore writes were rejected for
privileged workflows. Hostinger-only business storage was rejected because
Hostinger is an integration runtime, not the source of truth.

## Decision 4: Separate public comments and private IT notes

**Decision**: Private notes use a distinct role-protected resource and DTO.
Employee ticket reads, notifications, exports, search, and diagnostics never
serialize private note fields.

**Rationale**: Redaction at presentation time is too late and too fragile.

**Alternatives considered**: A shared comments array with an `isPrivate` flag
was rejected because one missed filter can expose confidential information.

## Decision 5: Immutable history with mutable projections

**Decision**: Tickets, assets, licenses, and requests maintain mutable current
state plus append-only activity/assignment/maintenance/audit records.

**Rationale**: Operational screens need fast current state while investigations
and financial approvals need permanent evidence.

**Alternatives considered**: Reconstructing every view from a full event stream
was rejected for Phase 005 complexity; overwriting history was rejected for
audit and custody requirements.

## Decision 6: Bounded role-scoped reads

**Decision**: List/search/report endpoints require a role-derived scope,
supported filters, cursor, and page size capped at 100. Dashboard counts use
selected-scope projections.

**Rationale**: This controls Firestore cost, avoids loaders that never resolve,
and makes unauthorized records absent at the data boundary.

**Alternatives considered**: Client-side filtering of broad collections was
rejected for security and read-budget reasons.

## Decision 7: Finance reads do not mutate payroll

**Decision**: Payslips, deductions, advances, reimbursements, custodies, and
ledger entries are displayed as source-linked read models. A request cannot
write a payroll deduction without a separately approved payroll integration.

**Rationale**: Payroll-cycle allocation is a critical business boundary and is
outside this phase.

**Alternatives considered**: Automatic advance deduction was deferred until a
separate payroll spec characterizes cycle and reopening behavior.

## Decision 8: Phase 006 remains independent

**Decision**: Ticket attachments depend on an abstract attachment reference.
When Company Workspace is enabled, its Drive bridge may implement the contract;
otherwise the existing attachment flow remains available.

**Rationale**: Phase 005 must remain testable and deployable without completing
or defaulting Phase 006.

**Alternatives considered**: Making Google Drive mandatory was rejected because
the approved Phase 005 scope explicitly excludes Google Workspace.

## Decision 9: Stable two-level organization units

**Decision**: The canonical editable structure uses stable opaque sector and
department IDs. Departments have exactly one sector parent; employees have one
current department membership. Display names and order are mutable, but IDs and
historical references are not.

**Rationale**: This provides the requested customization without making request
routing and reporting depend on mutable names or an unbounded arbitrary graph.

**Alternatives considered**: Fixed default sectors were rejected because they
cannot represent company changes. Arbitrary-depth nesting was deferred because
it makes manager inheritance, cycle detection, reporting, and approvals
ambiguous beyond the requested sector/department boundary.

## Decision 10: Managed capability and server-authorized mutations

**Decision**: Organization mutations require a managed
`organization_structure_manage` capability resolved by the server. The initial
policy covers active HR, Admin, and Super Admin identities, but no client role
or employee code is authoritative.

**Rationale**: Hierarchy changes alter manager visibility and future approval
routing, so direct client Firestore writes and UI-only checks are insufficient.

**Alternatives considered**: Hard-coded roles or employee codes were rejected
because they require releases to change governance and can be bypassed by a
manipulated client.

## Decision 11: Previewed atomic change sets

**Decision**: Manager, membership, move, reorder, archive, and restore actions
first return an impact preview. Confirmation submits a stable operation ID and
expected versions; canonical structure, employee projections, future routing
scope, and one audit event commit together or not at all.

**Rationale**: Bulk moves can affect many employees and approvals. Preview plus
atomic execution prevents partial departments, duplicate transfers, and hidden
routing changes.

**Alternatives considered**: Per-employee client loops were rejected because
network interruption creates partial assignments. Silent last-write-wins was
rejected because it loses concurrent administrator changes.

## Decision 12: Preserve materialized approvals and retain legacy rollback

**Decision**: A hierarchy change affects manager scope and approval routing only
for requests created after the change. Existing approval plans keep their
resolved assignees. The new organization slice remains disabled by default and
the current organization screen remains the rollback route through the pilot.

**Rationale**: Rewriting pending or historical approvals destroys evidence and
can move a decision to an unintended approver.

**Alternatives considered**: Re-resolving every open request was rejected as
unsafe. Replacing the legacy screen in place was rejected because it removes the
Strangler rollback path.
