# Feature Specification: Web Attendance Access Grants

**Feature directory**: `specs/web_attendance_access`  
**Created**: 2026-09-13  
**Status**: Draft  
**Input**: Allow an authorized administrator to give a named employee permission to record attendance from the web for a defined period or permanently.

## Purpose

Attendance is normally recorded through the mobile application. This feature creates a narrowly scoped, auditable exception for an individual employee to check in and check out from the web application. It does not change attendance, leave, schedule, payroll, discipline, location, or approval rules.

## User Scenarios & Testing

### User Story 1 — Grant web attendance access (Priority: P1)

An HR user or Super Admin selects an active employee and grants web attendance access either permanently or for an inclusive date range. The employee can then use the existing web check-in/check-out flow while the grant is active.

**Why this priority**: The permission cannot be used until it can be granted safely and consistently.

**Independent Test**: Grant a dated access period to an eligible employee, sign in to the web as that employee during the period, and complete a valid check-in/out. Repeat with a permanent grant.

**Acceptance Scenarios**:

1. **Given** an HR user or Super Admin, **when** they choose an active employee and a valid start/end period, **then** the system stores one active dated grant and confirms its inclusive dates in Cairo time.
2. **Given** an active employee, **when** an authorized administrator grants permanent web attendance access, **then** the employee may use web attendance until the grant is revoked.
3. **Given** an employee without an active grant, **when** they open attendance on the web, **then** they receive the current mobile-only guidance and cannot submit a web attendance action.
4. **Given** an employee with an active grant, **when** the current Cairo date is within the grant period, **then** the web attendance action is available only if the normal attendance gate permits it.

---

### User Story 2 — Enforce the exception at the attendance gateway (Priority: P1)

The attendance gateway verifies an active web-access grant before accepting a web-originated attendance action. Client UI state alone can never authorize the action.

**Why this priority**: A hidden or modified browser UI must not allow unauthorized attendance writes.

**Independent Test**: Send the same authenticated web attendance action through the gateway with and without an active grant; only the granted request succeeds when all normal policy checks pass.

**Acceptance Scenarios**:

1. **Given** a valid authenticated web action from an employee without an active grant, **when** it reaches the gateway, **then** the gateway rejects it without creating or changing an attendance record.
2. **Given** an active grant that was revoked or expired, **when** a previously open browser submits an action, **then** the gateway rejects it immediately.
3. **Given** an active grant and a normal attendance restriction such as an approved leave, day off, invalid location, invalid time window, or already-completed action, **when** the employee submits web attendance, **then** the existing restriction still decides the outcome.

---

### User Story 3 — Review and revoke grants (Priority: P2)

Authorized administrators can see each employee's current web-attendance grant, its scope and dates, and can revoke it immediately. The system retains the administrative audit trail.

**Why this priority**: Exceptions need an operational way to be removed and investigated.

**Independent Test**: Create a permanent grant, confirm it is shown as active, revoke it, and verify that a subsequent web action is rejected while the prior audit remains visible.

**Acceptance Scenarios**:

1. **Given** an active grant, **when** an authorized administrator revokes it, **then** the employee loses web attendance access immediately.
2. **Given** expired, revoked, and active grants, **when** an authorized administrator views the grant list, **then** each shows an accurate status, scope, administrator, and relevant dates.
3. **Given** an administrator lacks HR or Super Admin authority, **when** they attempt to view, create, edit, or revoke grants, **then** the operation is denied.

## Functional Requirements

- **FR-001**: Only users with the existing HR or Super Admin authority may manage web-attendance grants.
- **FR-002**: A grant applies to one active employee and permits only web check-in and web check-out.
- **FR-003**: A grant has exactly one scope: `period` or `permanent`.
- **FR-004**: A period grant requires a start date and end date; both dates are inclusive and evaluated in the Cairo business timezone. The end date cannot precede the start date and the period cannot exceed 366 days.
- **FR-005**: A permanent grant has no end date and remains active until an authorized administrator revokes it or the employee becomes inactive.
- **FR-006**: There is at most one active grant per employee. Changing its scope or dates replaces the current active grant and records the change in the audit trail.
- **FR-007**: The attendance gateway, not the client, must determine whether the employee currently has an active grant before it accepts a web-originated action.
- **FR-008**: A web grant does not bypass any existing attendance validation, including authentication, deterministic action identity, duplicate protection, attendance schedule, approved leave/day-off handling, location policy, time window, and check-in/check-out state.
- **FR-009**: The web attendance screen must show an active grant's status and expiry in Arabic, or state that it is permanent. It must keep the existing mobile-only guidance when no grant is active.
- **FR-010**: An unauthorized or expired web action must receive a clear Arabic error and must not be queued for later offline replay.
- **FR-011**: Every creation, change, and revocation must record the target employee, scope, dates, actor, timestamp, action type, and optional administrative note in an immutable audit history.
- **FR-012**: Grant data is stored in Firestore as the source of truth; the Hostinger attendance gateway uses it only to authorize the action and does not become a second source of truth.
- **FR-013**: The feature must use a new vertical slice with domain contracts, data adapters, and focused Cubits. Presentation code must not access Firestore or the gateway directly.
- **FR-014**: Existing mobile attendance behavior and existing developer-tool access remain unchanged by this feature.

## Key Entities

- **Web Attendance Access Grant**: The current employee-specific authorization, its scope, validity dates, status, and revision.
- **Web Attendance Access Audit Event**: An immutable record of a grant creation, replacement, or revocation.
- **Grant Manager**: An HR or Super Admin who performs a grant action.

## Non-Functional Requirements

- The server must treat a grant change or revocation as effective on the next web attendance request; browser refresh timing cannot extend access.
- The list and employee status must include RTL, loading, empty, error, and offline states.
- Attendance actions retain their existing idempotency and canonical IDs.
- The feature must not add an unbounded attendance or employee query.

## Success Criteria

- **SC-001**: An active employee with a valid grant can complete an otherwise-valid web check-in or check-out in one submission.
- **SC-002**: An ungranted, expired, or revoked employee cannot create an attendance action through the web gateway.
- **SC-003**: A grant never permits attendance that existing attendance policy would deny.
- **SC-004**: An HR user or Super Admin can identify the active scope, dates, and managing actor for a grant without inspecting raw database records.
- **SC-005**: Revoking a grant prevents the employee's next web action, including from a browser page that was already open.

## Assumptions

- “Pirof” means a **period** of access, not a proof attachment.
- The initial release covers check-in and check-out; it does not authorize web attendance corrections or manual attendance records.
- HR and Super Admin are the administrative roles for this exception. Other management roles retain their current rights.
- An administrative note is optional, while the actor and timestamps are always recorded.
