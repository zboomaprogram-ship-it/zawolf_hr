# Feature Specification: Check-out Policy Control

**Feature Branch**: `003-checkout-retirement`

**Created**: 2026-08-20

**Status**: Approved by owner — planning complete, tasks pending review

**Input**: Employees must continue to submit leave and attendance-permission
requests. Check-out is disabled by default, but authorized HR staff can turn the
check-out system on or off from the HR dashboard. Historical attendance and
payroll evidence remains unchanged.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Submit leave and valid attendance requests (Priority: P1)

As an employee, I can submit leave and attendance-permission requests even when
check-out is disabled, and I see only request choices that can affect my active
attendance policy.

**Why this priority**: Disabling check-out must not prevent employees from
requesting official leave or a valid late-arrival permission.

**Independent Test**: With check-out disabled, submit an official leave request
and late-arrival/early-leave permissions; each enters the normal approval chain.
Confirm that approving early leave while check-out is disabled does not create a
check-out obligation or deduction.

**Acceptance Scenarios**:

1. **Given** check-out is disabled, **When** an employee opens requests,
   **Then** official leave, late-arrival permission, and early-leave permission
   remain available.
2. **Given** check-out is disabled, **When** an employee submits a valid leave
   or late-arrival permission, **Then** it follows the existing approval chain.
3. **Given** check-out is disabled, **When** an employee opens a
   time-permission request, **Then** early-leave permission remains available
   and follows the normal approval chain, without requiring a check-out.
4. **Given** early leave is approved while check-out is disabled, **When** the
   attendance day is processed, **Then** the employee is not marked as missing
   check-out and no check-out deduction is created.

---

### User Story 2 - Control check-out from the HR dashboard (Priority: P1)

As authorized HR staff, I can see whether check-out is enabled and safely turn
it on or off from the HR dashboard. It is off by default.

**Why this priority**: HR needs a clear operational control without a code
deployment, while the safe default prevents unwanted check-out deductions.

**Independent Test**: Sign in as HR, verify the default status is off, enable
check-out, confirm the employee check-out/early-leave flow becomes available,
then disable it and confirm it disappears for future actions.

**Acceptance Scenarios**:

1. **Given** no authorized HR action has enabled it, **When** any user opens
   attendance, **Then** check-out is off by default.
2. **Given** an authorized HR user opens the HR dashboard, **When** they change
   the check-out control, **Then** the system shows a clear confirmation,
   effective status, and audit entry.
3. **Given** a non-HR employee or an unauthorized manager/admin opens the
   dashboard, **When** they attempt to change check-out status, **Then** they
   cannot do so.
4. **Given** HR enables check-out, **When** an eligible employee refreshes
   their attendance view, **Then** normal check-out behavior is available;
   early-leave permission remains available regardless of the switch.
5. **Given** HR disables check-out, **When** the setting takes effect,
   **Then** no new check-out actions, reminders, or missed-check-out
   consequences are created while it remains disabled; leave permissions remain
   available.

---

### User Story 3 - Prevent check-out consequences while disabled (Priority: P1)

As HR and payroll staff, I do not receive missed-check-out deductions, reviews,
approvals, or notifications for attendance dates/times while the control was
disabled.

**Why this priority**: Hiding the employee button alone would still allow
scheduled processing or stale clients to create payroll consequences.

**Independent Test**: Disable check-out, process a completed workday with a
check-in and no check-out, send a stale action/automatic signal, and pass the
former reminder time. Verify no check-out deduction, review, approval, or
notification is created.

**Acceptance Scenarios**:

1. **Given** check-out is disabled for an attendance date, **When** daily
   attendance processing runs, **Then** no missed- or early-check-out deduction
   or review is created.
2. **Given** check-out is disabled, **When** reminders or automatic attendance
   are evaluated, **Then** no check-out prompt, push, or attendance mutation is
   generated.
3. **Given** an old client or queued action attempts check-out while disabled,
   **When** it reaches the attendance authority, **Then** the action is safely
   refused without changing attendance or payroll state.
4. **Given** check-out is re-enabled later, **When** future attendance is
   processed, **Then** normal approved check-out policy resumes only from the
   recorded enablement point and does not retroactively create deductions for a
   disabled period.

---

### User Story 4 - Keep history and prior payroll auditable (Priority: P1)

As an authorized HR, payroll, or auditor user, I can view historical check-out,
early-leave, deductions, and payroll outcomes with the status that was in effect
at the time, without deletion or automatic recalculation.

**Why this priority**: Toggling policy must not damage auditability or rewrite
past payroll.

**Independent Test**: Compare historical dates from an enabled period and a
disabled period. Verify historical data stays unchanged, while reports make the
applicable check-out status clear.

**Acceptance Scenarios**:

1. **Given** an attendance record was created while check-out was enabled,
   **When** an authorized user views history, **Then** its original check-out
   information and audit context remain available read-only.
2. **Given** a date fell in a disabled period, **When** HR views attendance or
   payroll history, **Then** it is not presented as a missing check-out.
3. **Given** an approved check-out-related deduction predates a later status
   change, **When** payroll history is viewed, **Then** it remains unchanged and
   auditable.

### Edge Cases

- HR disables check-out while an employee is already checked in.
- HR enables check-out after an employee was checked in while it was disabled.
- An old client, automatic location signal, or queued action attempts check-out
  after the control is disabled.
- A leave or late-arrival permission spans a time when check-out is disabled.
- An early-leave permission was submitted or approved before a disable action.
- A daily job is rerun for a historical date with a different current setting.
- Multiple authorized HR users change the status close together.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Check-out MUST be disabled by default until an authorized HR user enables it through the HR dashboard.
- **FR-002**: The check-out control MUST be available only to authorized HR users and must record who changed it, when, the prior status, the new status, and the reason where one is supplied.
- **FR-003**: When check-out is disabled, employee attendance MUST present check-in only and MUST NOT show a check-out action, timing prompt, pending state, or check-out confirmation.
- **FR-004**: Employees MUST continue to submit official leave requests, late-arrival permissions, and early-leave permissions regardless of check-out status, using the existing approval chain.
- **FR-005**: When check-out is disabled, an approved early-leave permission MUST authorize the employee to leave without requiring, creating, approving, reconciling, or notifying a check-out event or a check-out-only deduction.
- **FR-006**: When check-out is disabled, every manual, queued, automatic, reminder, daily-processing, deduction, notification, approval, and report path MUST prevent new check-out events and check-out-only consequences.
- **FR-007**: A check-out request received while disabled MUST leave attendance, deductions, payroll, approvals, and notifications unchanged, and employees must receive concise Arabic guidance without raw technical detail.
- **FR-008**: Enabling check-out MUST apply prospectively from its recorded enablement point and MUST NOT retroactively create missed-check-out deductions, reviews, or reminders for a disabled period.
- **FR-009**: Disabling check-out MUST take effect for subsequent actions immediately after confirmation; an in-progress or queued check-out that reaches the authority afterward MUST be handled as disabled.
- **FR-010**: The status evaluated at the attendance action or processing time, together with its audit history, MUST determine whether check-out policy applies; a later toggle cannot rewrite historical attendance or payroll outcomes.
- **FR-011**: Historical check-out events, early-leave permissions, related deductions, reviews, approvals, notifications, and payroll entries MUST remain viewable to authorized users without deletion or automatic recalculation.
- **FR-012**: HR, payroll, and reports MUST distinguish records created while check-out was enabled from dates where check-out was disabled, and MUST NOT label a disabled period as missing check-out.
- **FR-013**: The system MUST protect against concurrent HR changes so each toggle produces one ordered, auditable final status.
- **FR-014**: The system MUST have automated coverage for default-off status, authorization, enable/disable transitions, interrupted/queued actions, stale clients, reminders, automation, deductions, early-leave permissions, late-arrival permissions, leave requests, and historical reruns.

### Key Entities

- **Check-out Policy Status**: The currently effective HR-controlled on/off status for check-out.
- **Check-out Status Change**: An ordered audit event containing the change actor, time, old/new value, optional reason, and effective point.
- **Attendance Policy Snapshot**: The status applicable to a specific attendance action or processing decision, derived from the status history.
- **Time Permission**: An employee attendance request. Late-arrival and early-leave remain valid independently of the check-out switch; when check-out is off, early leave does not create a check-out obligation.
- **Historical Check-out Consequence**: A prior check-out-related deduction, review, approval, notification, or payroll entry retained for audit.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In acceptance tests with default configuration, 100% of employee attendance screens show no check-out control and 100% of HR dashboard checks show it as disabled.
- **SC-002**: In enable/disable transition tests, 100% of authorized HR changes are immediately visible after refresh and create exactly one ordered audit entry.
- **SC-003**: In disabled-state scheduled-processing, replay, and stale-client tests, zero new check-out attendance mutations, deductions, reviews, approvals, reminders, or notifications are created.
- **SC-004**: In disabled-state tests, 100% of valid leave, late-arrival, and early-leave permission requests reach the normal approval chain, and zero approved early-leave requests create a check-out-only consequence.
- **SC-005**: In historical audit tests, 100% of sampled enabled-period check-out records and approved consequences remain unchanged and available to authorized users.
- **SC-006**: Employees complete a valid check-in and receive a saved or pending-safe status within 10 seconds under normal connectivity, regardless of check-out status.

## Assumptions

- “Leave permission” means official leave requests and valid attendance permissions. Official leave, late-arrival permission, and early-leave permission stay available regardless of the check-out switch.
- When check-out is off, an approved early-leave permission authorizes leaving early only; it does not require a check-out record or create a missed-/early-check-out deduction.
- Authorized HR includes the normal HR role; super administrators retain their existing oversight access, but ordinary employees and unauthorized managers cannot change the switch.
- The policy is off by default and changes apply prospectively. Historical attendance and payroll are never deleted or recalculated by a status change.
- Production activation, any access-rule change, and deployment require separate owner approval after the revised plan and tasks are reviewed.
