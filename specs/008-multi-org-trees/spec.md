# Feature Specification: Multiple Organization Trees

**Feature Branch**: `008-multi-org-trees`  
**Created**: 2026-08-24  
**Status**: Draft — owner review required before implementation  
**Input**: Create multiple customizable organization trees with different CEOs/root leaders while allowing one employee to belong to two or more trees.

## User Scenarios & Testing

### User Story 1 - Create an independent organization tree (Priority: P1)

An authorized organization administrator creates a named tree, assigns its root
leader, builds its sectors/departments, and activates it without changing the
existing canonical company tree.

**Why this priority**: Separate structures are not useful until each tree has a
stable identity, root, lifecycle, and independently managed hierarchy.

**Independent Test**: Create a second tree with a different root leader and two
units, reload it, and verify the current tree remains unchanged.

**Acceptance Scenarios**:

1. **Given** the current canonical tree, **When** an authorized administrator
   creates a new draft tree, **Then** it receives a stable identity and does not
   affect live routing until explicitly activated.
2. **Given** two active employees, **When** each is assigned as root leader of a
   different tree, **Then** each tree displays and authorizes its own root.
3. **Given** an active tree with dependencies, **When** it is archived, **Then**
   an impact preview and explicit confirmation are required and history remains.
4. **Given** the current company hierarchy, **When** an authorized administrator
   creates a tree using the default assisted flow, **Then** the system clones its
   units and eligible memberships into a separate draft tree without changing the
   current tree, its routing, or its historical requests.

---

### User Story 2 - Share an employee across trees (Priority: P1)

An administrator adds the same employee to multiple trees with a different unit,
title, and manager in each tree, without duplicating the employee account.

**Why this priority**: Matrix teams and project structures require shared people
while HR identity, attendance, salary, and request history remain singular.

**Independent Test**: Add one employee to two trees, assign different managers,
and verify both memberships while the employee has one profile and login.

**Acceptance Scenarios**:

1. **Given** an existing employee, **When** they are added to a second tree,
   **Then** a second membership is created and no employee record is copied.
2. **Given** an employee in three trees, **When** one membership is removed,
   **Then** the other memberships and historical evidence remain unchanged.
3. **Given** concurrent membership edits, **When** versions conflict, **Then**
   neither edit silently overwrites the other and the administrator sees an
   Arabic conflict/status-check outcome.

---

### User Story 3 - Keep business routing deterministic (Priority: P1)

HR designates exactly one active membership as the employee's primary company
membership. Only that membership projects the canonical department and manager
chain used for attendance, payroll scope, new HR requests, and notifications.

**Why this priority**: Multiple manager relationships must never make payroll or
approval routing ambiguous.

**Independent Test**: Give an employee two memberships, change the primary one,
submit a new request, and verify only the new request uses the new primary chain
while an existing request keeps its original approvers.

**Acceptance Scenarios**:

1. **Given** multiple active memberships, **When** HR changes the primary
   membership, **Then** the canonical user projection updates atomically.
2. **Given** a request whose approval plan is already materialized, **When** the
   primary membership changes, **Then** that request retains its original plan.
3. **Given** removal of the only primary membership, **When** no replacement is
   included in the same change set, **Then** the operation is rejected.

---

### User Story 4 - Navigate and administer tree-specific scope (Priority: P2)

An authorized user selects a tree, searches its hierarchy, manages its scoped
members, and sees clear indicators for shared and primary memberships.

**Independent Test**: Switch between two trees and verify hierarchy, counts,
permissions, search results, and shared-membership badges are tree scoped.

**Acceptance Scenarios**:

1. **Given** a tree-scoped administrator, **When** they open another tree,
   **Then** protected membership data and mutation controls are denied.
2. **Given** a shared employee, **When** their card is opened, **Then** authorized
   users can see the employee's permitted memberships and which one is primary.

### Edge Cases

- The root leader is deactivated, removed from the tree, or loses capability.
- A tree is created without a root leader and remains a visibly incomplete draft.
- A user is root leader in one tree and a regular member in another.
- A department has the same display name in multiple trees.
- Import encounters duplicate trees, cyclic parents, orphan units, or duplicated memberships.
- Two administrators attempt to set different primary memberships concurrently.
- A tree is archived while it is the source of a user's primary membership.
- Cached/offline changes are retried after a newer tree version was committed.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST represent each organization tree with a stable ID,
  name, purpose, root leader, lifecycle state, version, and audit metadata.
- **FR-002**: Authorized administrators MUST be able to create, rename, clone,
  reorder, activate, archive, and restore trees through previewed change sets.
- **FR-003**: Each tree MUST own an independent hierarchy and MAY have a different
  active root leader; no client may hard-code `ceo-100` or a role label as root.
- **FR-004**: An employee MUST have one canonical identity and MAY have multiple
  concurrent tree memberships with tree-specific unit, title, manager, dates,
  ordering, and active state.
- **FR-005**: A duplicate active membership for the same employee, tree, and unit
  MUST be rejected or converge idempotently to the existing membership.
- **FR-006**: Every active employee participating in company routing MUST have
  exactly one active primary membership; secondary memberships MUST NOT alter
  attendance, payroll, or HR-request routing.
- **FR-007**: Changing the primary membership MUST atomically update the legacy
  department/direct-manager projection used by current consumers or update neither.
- **FR-008**: Primary-membership changes MUST affect only future approval-plan
  materialization; existing request assignees and evidence MUST remain immutable.
- **FR-009**: Tree and membership access MUST be authorized server-side through
  managed global and tree-scoped capabilities, not employee codes or client roles.
- **FR-010**: Root leaders and delegated tree administrators MUST see and mutate
  only their permitted trees and actions.
- **FR-011**: Every mutation MUST be versioned, idempotent, and append exactly one
  safe audit event with actor, target, tree, operation, and before/after summary.
- **FR-012**: Tree lists, unit lists, and membership lists MUST be paginated and
  bounded; dashboards MUST use projections rather than collection-wide streams.
- **FR-013**: The editor MUST support Arabic RTL, desktop and mobile layouts,
  keyboard/browser selection, search, multi-select, loading, empty, denied,
  offline, pending-sync, conflict, status-check, and retry states.
- **FR-014**: Existing organization data MUST migrate non-destructively into one
  default tree by dry run; the employee's current department/manager becomes the
  initial primary membership without deleting legacy fields.
- **FR-015**: The legacy single-tree implementation MUST remain available behind
  a separate rollback switch until migration, routing, role-matrix, and pilot
  acceptance pass.
- **FR-016**: The feature MUST default off under `company_os_multi_tree_v1` and
  MUST NOT become default without owner approval and rollback evidence.
- **FR-017**: Archiving a tree, unit, root assignment, or primary membership MUST
  fail closed when unresolved active dependencies remain.
- **FR-018**: User-facing failures MUST be safe Arabic outcomes and MUST never
  expose Firebase, Firestore, HTTP, or stack-trace text.
- **FR-019**: The tree-creation flow MUST offer an assisted clone of the current
  canonical hierarchy as the default option and an empty-tree option. A clone
  MUST create new tree/unit/membership identities, preserve source history,
  remain draft until activated, and never change a member's primary routing
  unless a separately previewed primary-membership action is approved.

### Key Entities

- **Organization Tree**: Independent named hierarchy and lifecycle boundary.
- **Tree Leadership Assignment**: Effective-dated root or delegated administrator assignment.
- **Tree Unit**: Sector/department belonging to exactly one tree.
- **Tree Membership**: Employee placement inside one tree and unit.
- **Primary Membership Designation**: The one membership that drives canonical HR routing.
- **Organization Change Set**: Previewed, versioned, idempotent group of mutations.
- **Organization Audit Event**: Append-only record of a permitted change.

## Success Criteria

- **SC-001**: An authorized administrator creates and activates a second tree
  with a different root and at least two units in under five minutes.
- **SC-002**: One employee can appear in three trees with three managers while
  retaining one profile, one attendance identity, and one request history.
- **SC-003**: In 100% of primary-membership tests, new requests use the selected
  primary chain and pre-existing requests keep their original approval evidence.
- **SC-004**: Unauthorized users read or mutate zero out-of-scope tree records in
  the non-production role matrix.
- **SC-005**: Retry and concurrency tests yield one complete audited result or no
  organization change, with no silent partial state.
- **SC-006**: A 20-tree, 500-employee fixture produces a usable bounded result,
  empty state, or retry guidance within 10 seconds under normal connectivity.

## Assumptions

- HR/Admin users create trees and memberships; employees cannot grant themselves
  hierarchy access or choose their primary company manager.
- The existing organization tree becomes the default primary tree.
- Secondary trees model projects, brands, committees, or matrix reporting and do
  not change payroll/attendance authority unless HR makes that membership primary.
- Existing Phase 005 organization APIs remain available during strangler rollout.
