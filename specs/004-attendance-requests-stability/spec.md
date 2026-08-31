# Feature Specification: Attendance and Requests Stability

**Feature Branch**: `004-attendance-requests-stability`

**Created**: 2026-08-20

**Status**: Approved by owner — planning complete, tasks pending review

**Input**: Stabilize automatic location attendance, request visibility and
approval, productivity/KPI calculations, device attendance binding, map location
selection, and mobile back navigation before building the Company Workspace and
Google Workspace centre.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Record attendance reliably with location (Priority: P1)

As an employee, I can check in reliably using validated location attendance,
whether I use manual check-in or the approved automatic-attendance option. I
receive a clear Arabic outcome and never see technical provider errors.

**Why this priority**: Attendance is payroll-adjacent and must be correct before
new collaboration features are introduced.

**Independent Test**: Test a valid in-range check-in, an out-of-range attempt,
an unavailable connection, an automatic-location attempt, and a duplicate
attempt. Verify at most one canonical attendance record is created for the
correct Cairo date and employees see saved, pending, or actionable Arabic
guidance.

**Acceptance Scenarios**:

1. **Given** an employee is eligible and inside the assigned location radius,
   **When** they check in, **Then** exactly one canonical daily attendance
   record is saved or safely queued for synchronization.
2. **Given** automatic attendance is enabled and the operating system permits
   an eligible location event, **When** the employee enters the authorized
   location, **Then** the system attempts one idempotent check-in and retains a
   manual fallback.
3. **Given** location, device, authentication, connectivity, or service checks
   prevent attendance, **When** the employee tries to check in, **Then** they
   receive safe Arabic guidance and no raw Firebase, HTTP, permission-rule, or
   exception text.
4. **Given** an employee has already checked in for the Cairo attendance date,
   **When** a manual or automatic duplicate attempt occurs, **Then** no second
   record or duplicate payroll consequence is created.

---

### User Story 2 - Submit, find, and approve every eligible request (Priority: P1)

As an employee, manager, HR user, or administrator, I can submit and manage
requests without permission errors caused by valid account state, and I can find
both current and historical requests in the correct request tab.

**Why this priority**: Missing requests and unreliable approvals prevent HR
from operating and may hide confirmed salary deductions or attendance outcomes.

**Independent Test**: Create each supported request type, including a
late-arrival permission and an attendance-correction request. Verify it appears
for its designated approvers. Verify approved, rejected, cancelled, and
historical confirmed salary-deduction records appear in their appropriate tabs
for authorized HR/admin/manager users.

**Acceptance Scenarios**:

1. **Given** an employee submits a valid request, **When** the request is
   saved, **Then** every designated current approver can see it without needing
   a manual database repair.
2. **Given** a request needs an approval chain, **When** one approver acts,
   **Then** the next eligible approver receives the request and no unauthorized
   user can approve it.
3. **Given** a request is old, approved, rejected, cancelled, or has produced
   a confirmed salary deduction, **When** an authorized user opens the matching
   history tab, **Then** it remains visible, searchable, and correctly
   classified.
4. **Given** a request fails because the user is not eligible or the outcome is
   temporarily uncertain, **When** the user submits or approves it, **Then**
   the screen gives clear Arabic next steps and does not expose technical
   permission errors.
5. **Given** HR, admin, or a manager changes request tabs or searches,
   **When** data is loading or no result exists, **Then** the screen finishes in
   a bounded time with records, an empty state, or an actionable retry state;
   it does not remain on an endless spinner.
6. **Given** an employee has a salary deduction from attendance, permission,
   leave, or an administrative decision, **When** they open its details,
   **Then** they see a clear Arabic explanation of the deduction reason,
   affected date or period, deduction fraction/amount when available, and its
   current review status.

---

### User Story 3 - View trustworthy productivity and KPI information (Priority: P1)

As HR, a manager, or an employee with access, I can view productivity and KPI
figures that are calculated from the correct attendance, task, and approved
business records for the selected employee and period.

**Why this priority**: Incorrect figures create bad management and payroll
decisions.

**Independent Test**: Use known test employees with attendance, approved leave
or permission, tasks, and KPI records. Compare displayed per-employee and
team totals with the documented input records. Confirm the selected date period
is respected and unavailable source data is labelled rather than silently
counted as zero.

**Acceptance Scenarios**:

1. **Given** a selected employee and date period, **When** productivity or KPI
   is calculated, **Then** only records belonging to that employee and period
   contribute to the result.
2. **Given** approved leave or permission affects attendance, **When** the
   result is calculated, **Then** it is handled according to the documented
   policy and is not mistaken for an unexplained absence.
3. **Given** a source record is unavailable or incomplete, **When** the screen
   shows the result, **Then** it identifies the unavailable input rather than
   misleadingly presenting it as a complete zero-value result.
4. **Given** a manager changes employee, team, or period filters, **When** the
   data refreshes, **Then** the visible totals and drill-down rows update to the
   same filter selection.

---

### User Story 4 - Manage attendance devices and locations (Priority: P1)

As authorized HR or IT staff, I can reset an employee's attendance device when
needed and select a company attendance location from an interactive web map.

**Why this priority**: A stuck device binding blocks attendance, and typed
coordinates are error-prone for HR.

**Independent Test**: Bind a test device, reset it through the authorized
employee-management path, then bind a replacement device. In a web browser,
open the location picker, select a point on the map, save it, and confirm the
displayed radius/location matches the saved selection.

**Acceptance Scenarios**:

1. **Given** an authorized HR or IT user opens an employee profile, **When**
   they reset the attendance-device binding with a reason, **Then** the old
   device cannot sign in for attendance and the next validated device can bind.
2. **Given** an unauthorized user attempts a device reset, **When** they access
   the employee data, **Then** the reset control and mutation are denied.
3. **Given** an authorized location editor opens the web location selector,
   **When** they select a point and radius, **Then** the map, coordinates, and
   radius are saved together and shown for later review.
4. **Given** the map service cannot load, **When** the location editor opens,
   **Then** it shows a safe fallback allowing an authorized user to retain or
   enter reviewed coordinates without losing the existing location.

---

### User Story 5 - Navigate naturally on mobile (Priority: P2)

As a mobile user, I can use a back swipe or system-back action to return to the
previous ZaWolf screen. The app only exits when I am at its intended root
screen and explicitly confirm or use the platform's normal exit behavior.

**Why this priority**: Back navigation that exits the app discards context and
makes normal mobile use feel broken.

**Independent Test**: On Android and iOS test devices, navigate from a list to
a detail screen and use back swipe/system back. Verify navigation returns to
the previous in-app screen. At the root screen verify it does not unexpectedly
discard a pending request or attendance action.

**Acceptance Scenarios**:

1. **Given** a user is on a nested ZaWolf screen, **When** they use a back
   swipe or system back, **Then** they return to the prior in-app screen.
2. **Given** an attendance submission or request form is in progress, **When**
   the user attempts to go back, **Then** the app prevents accidental loss or
   clearly asks whether to discard the unsaved action.
3. **Given** the user is at the intended app root, **When** they use back,
   **Then** platform-consistent exit behavior occurs without trapping them in
   navigation loops.

## Edge Cases

- An automatic attendance event is delivered late, repeatedly, or while the
  app is not open.
- The employee switches accounts after a pending check-in is stored locally.
- The manager relationship or employee role changes while a request is in the
  approval chain.
- Historical deduction documents use legacy fields or no longer match a current
  request-tab filter.
- A request query fails, returns no records, or is paginated while the user
  changes tabs/search terms.
- The same employee has multiple device-reset attempts made close together.
- Web map access is blocked, unavailable, or has no selected location yet.
- A mobile back action occurs while a write is pending or synchronization is
  unresolved.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Manual and automatic location attendance MUST preserve the
  canonical one-check-in-per-employee-per-Cairo-date identity.
- **FR-002**: Automatic attendance MUST remain opt-in, platform-permitted, and
  safely idempotent; it MUST NOT claim a successful check-in without an
  authoritative saved result.
- **FR-003**: Attendance and request screens MUST render only safe Arabic
  outcome text and MUST NOT expose Firebase, HTTP, permission-rule, exception,
  credential, identifier, or stack-trace details to employees.
- **FR-004**: Valid requests MUST be visible to all and only their designated
  approvers according to the current approval chain.
- **FR-005**: Authorized HR, administrator, and manager history views MUST
  show relevant active and historical requests, including confirmed salary
  deductions and late-arrival salary deductions, in their appropriate tabs.
- **FR-006**: Request tabs and search MUST produce a loaded result, explicit
  empty state, or safe retry state; no request tab may spin indefinitely.
- **FR-007**: Request creation, approval, rejection, cancellation, and
  modification MUST preserve existing approval and audit history rather than
  deleting or silently recreating requests.
- **FR-008**: Productivity and KPI views MUST use the selected employee/team
  and period consistently, identify unavailable inputs, and preserve approved
  attendance-policy effects.
- **FR-009**: Device reset MUST be limited to authorized HR/IT roles, require
  an audit reason, invalidate the previous attendance-device binding, and leave
  historical attendance immutable.
- **FR-010**: Authorized web users MUST be able to select and review company
  attendance locations and radius using an interactive map, with a safe
  coordinate fallback when map content is unavailable.
- **FR-013**: Employees MUST be able to open each salary-deduction entry and
  view a clear Arabic explanation of its source, reason, affected date or
  period, deduction fraction/amount when available, and approval/review
  status. Legacy records with incomplete data MUST show an honest Arabic
  fallback rather than a fabricated explanation.
- **FR-011**: Mobile back interactions MUST navigate within ZaWolf before
  exiting the application and MUST protect pending attendance/request writes.
- **FR-012**: The feature MUST add automated coverage for duplicate/late
  automatic attendance, request visibility and legacy history, safe-error
  presentation, loading/empty/retry states, productivity filtering, device
  resets, location selection fallback, and mobile back behavior.

### Key Entities

- **Attendance Check-in Attempt**: A manual or automatic location-based attempt
  tied to one employee and canonical Cairo attendance date.
- **Request Visibility Record**: The status, approval stage, history
  classification, and authorized viewers of an employee request or deduction.
- **Productivity Input Set**: The attendance, approved request, task, KPI, and
  selected-period records used to produce a visible productivity result.
- **Attendance Device Binding**: The current authorized device association,
  reset history, reset actor, reason, and time.
- **Company Attendance Location**: The reviewed coordinates, radius, editor,
  and latest change time used for attendance validation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In automated and non-production acceptance tests, duplicate or
  delayed automatic check-in attempts create zero additional attendance records.
- **SC-002**: In all covered attendance and request failures, employees see
  safe Arabic guidance and zero raw provider technical messages.
- **SC-003**: In a sample spanning every request type and lifecycle status,
  100% of records visible to an authorized approver are shown in the correct
  request/history tab, including historical confirmed deductions.
- **SC-004**: In request-tab, search, empty-result, and temporary-failure
  tests, 100% of screens finish in a record, empty, or retry state rather than
  an endless loading state.
- **SC-005**: For prepared productivity/KPI fixtures, displayed employee and
  team totals match the documented selected-period input set in 100% of cases.
- **SC-006**: In device-reset tests, the previous device is rejected and one
  replacement device can register without altering historical attendance.
- **SC-007**: In mobile navigation tests, 100% of nested-screen back actions
  return in-app and no protected pending attendance/request write is silently
  discarded.

## Assumptions

- The current check-out policy remains separately controlled by the completed
  phase 003 work; this feature does not re-enable check-out by default.
- “Automatic attendance” means automatic check-in only. It remains constrained
  by platform location and background-execution rules; manual check-in stays
  available.
- Existing request and salary-deduction history must be read and classified;
  no historical payroll amount may be recalculated or deleted in this phase.
- The normal HR role, authorized administrators, and managers retain their
  existing responsibilities. Device and location management permissions will be
  documented during planning rather than hard-coded to a particular employee.
- Company Workspace and Google Workspace implementation are explicitly deferred
  until this reliability feature has been reviewed, implemented, and accepted.
- Production deployment, Firebase rules changes, credential changes, device
  resets, location changes, or historic data repairs require separate owner
  authorization after plan and task review.
