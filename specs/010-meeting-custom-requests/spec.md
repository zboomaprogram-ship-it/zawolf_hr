# Feature Specification: Meeting and Configurable Requests

**Feature Branch**: `010-meeting-custom-requests`  
**Created**: 2026-09-03  
**Status**: Draft — owner review required  
**Input**: Employee meeting requests, mission recipient search, HR-managed casual leave, HR-configured request types with approval routes and notifications, and audited HR manual attendance entry.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Request a meeting with Manager, HR, Admin, or CEO (Priority: P1)

An employee can request a meeting with any active recipient having a Manager,
HR Admin/Staff, Super Admin, or CEO role, choose an available meeting location,
provide a proposed date/time and reason, and track the decision. The selected
recipient (Manager, HR, Admin, or CEO) is assigned the sole approval turn for the request.

**Why this priority**: It gives employees a clear, auditable way to obtain an
executive, HR, or manager's time and prevents informal room conflicts.

**Independent Test**: An employee requests a meeting with an eligible Manager,
HR, Admin, or CEO account and room; the recipient receives a notification,
approves or rejects it from their decision queue, and the requester sees the
final result and history.

**Acceptance Scenarios**:

1. **Given** an active employee and active Manager, HR, Admin, or CEO accounts,
   **When** the employee selects one eligible recipient, a future date/time, an
   active room, and a reason, **Then** a meeting request is submitted in a pending
   state and only that selected recipient is assigned the approval step.
2. **Given** a pending meeting request, **When** its selected recipient approves
   it, **Then** the requester receives an approval notification and the request
   history records the decision, actor, and time.
3. **Given** a pending meeting request, **When** its selected recipient rejects
   it with a reason, **Then** the requester receives a rejection notification
   containing the reason and the request becomes terminal.
4. **Given** an approved booking for a room and time interval, **When** another
   employee tries to book the same room during an overlapping interval,
   **Then** the second request is not submitted and the employee is told to
   choose another room or time.

---

### User Story 2 - HR manages meeting rooms (Priority: P2)

HR can maintain the list of meeting locations used by meeting requests,
including the default office location, small meeting room, large meeting room,
and additional rooms.

**Why this priority**: Rooms must be controlled by HR rather than being
hard-coded or independently named by employees.

**Independent Test**: HR adds a room, makes it available, and it becomes
selectable in a new meeting request; when HR deactivates it, it is no longer
available for future requests while historical records retain its name.

**Acceptance Scenarios**:

1. **Given** HR opens meeting-room management, **When** HR adds a unique room
   name and capacity/description, **Then** active employees can select it for
   new requests.
2. **Given** an existing room with historical meetings, **When** HR deactivates
   it, **Then** pending and historical requests preserve their chosen room name
   but the room is absent from new-request choices.

---

### User Story 3 - Search mission recipients (Priority: P2)

When HR creates a field mission for one or more employees, HR can search the
active employee directory by name, employee code, department, or email before
selecting recipients.

**Why this priority**: A searchable selection is necessary for reliable
multi-employee missions in a growing directory.

**Independent Test**: HR searches for part of an employee's Arabic name or
employee code, selects one or more results, and only those selected employees
receive the mission-under-review notification.

**Acceptance Scenarios**:

1. **Given** HR is creating a field mission, **When** HR searches with at least
   two characters of a name, code, department, or email, **Then** matching
   active employees are shown without duplicates.
2. **Given** HR selected multiple employees, **When** HR creates the mission,
   **Then** one independently auditable request and notification flow is
   created per employee.

---

### User Story 4 - HR controls casual leave approval (Priority: P2)

HR can change a submitted casual leave from automatically approved to an
approval-required request, and can return an automatically approved casual
leave to review when business policy requires it. The affected employee and the
next approver receive clear notifications.

**Why this priority**: HR needs an exceptional-control path without silently
changing payroll or leave balances.

**Independent Test**: HR changes an automatically approved casual leave to
pending review; the leave remains auditable, the selected approval path is
visible, and notifications reach the employee and current approver.

**Acceptance Scenarios**:

1. **Given** a casual leave automatically approved by policy and not yet
   executed, **When** HR changes it to review-required with a reason,
   **Then** the automatic decision is retained in history, the next valid
   approval step is assigned, and the employee is notified.
2. **Given** a casual leave already approved manually or automatically,
   **When** HR attempts to alter it after its execution date or after payroll
   finalization, **Then** the action is refused with an Arabic explanation and
   no leave or payroll data changes.

---

### User Story 5 - HR creates a configurable request type (Priority: P3)

HR can define a reusable request type with an Arabic title, employee-facing
description, required fields, eligible employee audience, and ordered approval
chain. Eligible employees can submit the type; each designated approver sees
the request only when it is their turn and receives a notification.

**Why this priority**: It lets HR add controlled business workflows without
asking employees to use unrelated request categories.

**Independent Test**: HR publishes a request type to an eligible employee,
the employee submits it, every stage receives one turn notification in order,
and the requester can view the complete route and outcome.

**Acceptance Scenarios**:

1. **Given** HR creates a request type with title, description, audience, and
   one to four active approvers, **When** HR publishes it, **Then** only the
   configured audience can see and submit the type.
2. **Given** an employee submits a configurable request, **When** an approver
   approves, **Then** the next approver alone is notified and becomes able to
   decide; the requester is notified on submission, final approval, rejection,
   cancellation, and HR amendment.
3. **Given** HR deactivates a request type, **When** employees open the request
   centre, **Then** it cannot be submitted by new employees, while existing
   requests remain viewable and completable.

---

### User Story 6 - HR records manual check-in, check-out, and check-out disable (Priority: P1)

HR can record a manual check-in or check-out for any active employee from the HR
dashboard, and can disable the sign-out requirement for current employees on an
active attendance session when an exceptional business shift occurs. Each manual
entry records the HR actor, reason, effective date/time, and an immutable audit
history.

**Why this priority**: HR needs a controlled operational path for valid attendance
recovery and shift check-out bypasses while preserving employee accountability.

**Independent Test**: An HR user records a manual check-in or check-out, or disables
the check-out requirement for an active shift; the employee's attendance status
updates cleanly, the employee receives a notification, and the audit record identifies HR.

**Acceptance Scenarios**:

1. **Given** an active employee without a check-in for the business day, **When** HR
   enters a manual check-in with a required reason, **Then** one attendance record
   is created and marked as HR-entered, and the employee is notified.
2. **Given** an employee with an open check-in, **When** HR records a manual check-out
   or sets check-out as disabled/not-required for that session with a reason, **Then** the
   record updates once and the employee receives a notification.
3. **Given** a past attendance day in a finalized payroll cycle, **When** HR attempts
   a manual entry, **Then** the action is refused and directs HR to the formal correction path.

---

### User Story 7 - HR excludes employee from company attendance reporting (Priority: P2)

HR can configure an employee account to be excluded from company attendance reporting
("حالة حضور الشركة اليوم"). The account remains active so the employee can sign in, submit
requests, view chat, and use all non-attendance features of the app, but attendance check-in/out
is disabled for that account and the employee is not counted or listed in company attendance reports.

**Why this priority**: Executives, contractors, or specific roles who do not record daily
attendance must not clutter daily attendance counters or trigger absence alerts while keeping full
access to requests, chat, and company services.

**Independent Test**: HR toggles attendance reporting exclusion for an active employee; the
employee's app remains accessible, attendance check-in buttons display "غير مطبق عليك تسجيل الحضور",
and the employee disappears from "حالة حضور الشركة اليوم" counts and lists.

**Acceptance Scenarios**:

1. **Given** an active employee, **When** HR enables attendance reporting exclusion for their account,
   **Then** `status` remains `'active'`, the employee can sign in and submit requests, but check-in/out buttons are disabled with an informative message.
2. **Given** an excluded employee account, **When** HR views "حالة حضور الشركة اليوم",
   **Then** the excluded employee is not counted in total/present/absent metrics and does not appear in the daily attendance report list.
3. **Given** an excluded employee account, **When** HR disables the exclusion flag,
   **Then** normal attendance check-in/out capabilities and reporting visibility are restored immediately.

---

### Edge Cases

- A meeting request must not target an inactive user, the requester themself,
  or a non-manager account.
- Deactivating a room or request type never erases it from historical requests.
- An approver removed or made inactive after a request starts must not be
  silently skipped; HR must amend the route through an audited action before
  the request can continue.
- Meeting decisions, cancellations, and retries must produce one durable state
  transition and no duplicate notifications.
- Room availability is evaluated for approved bookings and pending requests
  awaiting the selected manager, to prevent competing requests for one slot.
- Searching must not expose inactive employees or employees outside HR's
  existing employee-directory permission.
- The casual-leave override must preserve approval-date versus execution-date
  semantics and cannot reopen payroll.
- Manual attendance must not bypass inactive-user checks, company-day-off or
  approved-leave safeguards, or the existing payroll-finalization boundary.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow an employee to submit a meeting request to
  one active manager with proposed date/time, purpose, and one active meeting
  location.
- **FR-002**: The system MUST accept a manager as a meeting approver only when
  that account is active and has a manager-capable role.
- **FR-003**: The system MUST store a one-stage, auditable approval route for
  each meeting request and permit only the selected manager to approve or
  reject it.
- **FR-004**: The system MUST prevent overlapping room bookings and present an
  Arabic, actionable availability message without creating a duplicate
  request.
- **FR-005**: HR and super-admin accounts MUST be able to add, edit, activate,
  and deactivate meeting locations; standard employees and managers MUST have
  read-only access to active locations for meeting submission.
- **FR-006**: The system MUST provide office, small meeting room, and large
  meeting room as initial selectable locations, while allowing HR to add more.
- **FR-007**: The field-mission creation screen MUST provide an Arabic RTL
  search that finds active employees by display name, employee code,
  department, or email and preserves the selected recipient list while the
  search changes.
- **FR-008**: HR MUST be able to override an auto-approved casual leave before
  its execution date by recording a reason and changing it to the existing
  valid approval path; the original automatic decision MUST remain in history.
- **FR-009**: The casual-leave override MUST not alter payroll records, leave
  entitlement, or an executed/finalized leave outside the existing authorised
  correction process.
- **FR-010**: HR MUST be able to create, edit, activate, and deactivate a
  configurable request type with Arabic title, employee-facing description,
  required-field configuration, audience, and one to four ordered active
  approvers.
- **FR-011**: HR MUST be able to target a configurable request type to all
  active employees, selected departments, selected individual employees, or a
  combination of those audience modes; employees outside that audience MUST
  not see or submit the type.
- **FR-012**: The system MUST create an immutable, sequential approval history
  for every meeting and configurable request, including submitter, stage,
  decision, timestamp, and optional reviewer comment.
- **FR-013**: On submission, each new approval turn, final approval, rejection,
  cancellation, or HR amendment, the system MUST write one idempotent in-app
  notification and queue a push notification for the affected person.
- **FR-014**: Employees, managers, HR, and super-admin accounts MUST see only
  requests and routes they are authorised to view; unauthorized URL navigation
  and direct data access MUST be refused.
- **FR-015**: All new and changed screens MUST support Arabic RTL, mobile,
  desktop web, loading, empty, and failure states.
- **FR-016**: HR and super-admin accounts MUST be able to create a manual
  check-in or check-out for any active employee from the HR dashboard only
  after providing a non-empty reason and a valid business date/time.
- **FR-017**: A manual attendance entry MUST record the HR actor, reason,
  creation time, effective event time, and entry source, and MUST be visible
  to the employee and authorised HR reviewers.
- **FR-018**: Manual attendance MUST use the canonical attendance record for
  the employee and business date, remain idempotent under repeated submission,
  and never create a second check-in or check-out for the same event.
- **FR-019**: Manual attendance MUST refuse an inactive employee, an invalid
  event order, an event outside the authorised correction window, a company
  day off, approved leave, or a completed payroll period; it MUST not
  automatically alter an existing salary deduction.
- **FR-020**: The employee MUST receive one notification when HR records or
  corrects a manual attendance event that affects their visible attendance
  record.

### Key Entities

- **Meeting location**: An HR-managed location name, optional capacity and
  description, active status, and history-safe identifier.
- **Meeting request**: An employee's request to meet one manager at one
  location and time, with a status, route, decision history, and conflict-safe
  booking interval.
- **Configurable request type**: An HR-managed definition containing title,
  description, submission fields, intended audience, active status, and
  template approval route.
- **Configurable request**: An employee submission based on a published type,
  with a snapshot of the type information, responses, an approval route, and
  append-only decision history.
- **Casual leave override**: An HR-recorded policy exception that references
  the original automatic decision and the reason for requiring review.
- **Manual attendance event**: An HR-authorised check-in or check-out attached
  to the employee's canonical business-day attendance record, with actor,
  reason, timestamps, idempotency identity, and audit status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An employee can submit a valid meeting request in under two
  minutes and the selected manager sees it in their requests and notifications
  within 30 seconds under normal connectivity.
- **SC-002**: 100% of attempted overlapping room bookings are stopped before a
  second active request is created for the same room and time interval.
- **SC-003**: HR can find a target employee for a field mission by partial name
  or employee code in under three seconds for a directory of 500 active users.
- **SC-004**: For every approved, rejected, cancelled, or amended request in
  the new flows, the requester and current approver can see a complete,
  time-ordered history with no duplicate notification for the same event.
- **SC-005**: HR can publish or deactivate a configurable request type without
  changing or losing any previously submitted request.
- **SC-006**: The casual-leave override refuses 100% of requests that would
  affect a completed payroll period or an already executed leave.
- **SC-007**: An authorised HR user can complete a valid manual attendance
  entry in under one minute, and the employee sees the entry and notification
  within 30 seconds under normal connectivity.
- **SC-008**: 100% of manual-attendance attempts that violate event order,
  company-day-off, approved-leave, inactive-user, or payroll-finalization
  rules are refused without changing the attendance record.

## Assumptions

- The current authenticated user, notification dispatcher, request history,
  and sequential approval-route behavior remain the source of truth.
- Managers eligible for meeting requests are active users with an existing
  manager-capable role; an employee may choose any eligible manager, not only
  their reporting manager.
- HR owns the room inventory and initial locations are created once without
  overwriting an HR-edited list.
- Meeting requests use the company's Cairo business time and require a future
  proposed time interval.
- Configurable request approvers are selected from active authorised approver
  accounts, not ordinary employees, unless the owner later explicitly expands
  that policy.
- Configurable request types may be targeted through all three approved
  audience modes: all active employees, selected departments, and named
  employees.
- Manual attendance is an exceptional HR recovery path for the current open
  payroll cycle; past payroll and attendance corrections remain governed by
  the existing correction process.
- This feature does not introduce calendar invitations, recurring meetings,
  external room calendars, payroll changes, or a production Firestore-rule
  deployment without separate owner approval and rollback plan.
