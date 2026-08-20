# Feature Specification: Check-in Reliability Pilot

**Feature Branch**: `002-attendance-reliability`

**Created**: 2026-08-20

**Status**: Draft — ready for owner review

**Input**: Improve employee check-in reliability: use the shared safe-error outcome system, automatically retry or queue temporary outages, never show technical error text to employees, show Arabic saved/pending/check-status states, and test denied access, temporary outages, duplicate check-in, and interrupted submission. The experience must remain portable to future company-controlled services. Check-out is not part of this pilot.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Complete a reliable check-in (Priority: P1)

As an employee, I can check in smoothly and receive an unambiguous Arabic confirmation when my attendance is safely saved.

**Why this priority**: Attendance is a daily, time-sensitive workflow. Employees must not need to understand backend or connectivity failures to know whether they completed it.

**Independent Test**: Complete a check-in with a valid attendance window, location, and device. Verify the employee sees a saved confirmation and the attendance history shows exactly one check-in.

**Acceptance Scenarios**:

1. **Given** an employee has not checked in today and meets the attendance requirements, **When** they submit check-in, **Then** they receive an Arabic saved confirmation and exactly one check-in is recorded.
2. **Given** an employee repeats a completed check-in, **When** they submit again, **Then** the system confirms the existing attendance state without creating another check-in.

---

### User Story 2 - Continue safely through a temporary outage (Priority: P1)

As an employee, I can capture a valid check-in during a temporary connectivity or service interruption and know whether it was saved, is pending synchronization, or needs its status checked before I submit again.

**Why this priority**: A temporary outage must not prevent honest attendance or cause duplicate time records.

**Independent Test**: Simulate an outage before submission and another interruption after submission starts. Verify the first valid action becomes pending sync, the uncertain action instructs the employee to check status, and a later recovery results in at most one attendance event.

**Acceptance Scenarios**:

1. **Given** the employee is offline before submitting a valid check-in, **When** they submit, **Then** the action is retained for synchronization and the employee sees an Arabic pending-sync status.
2. **Given** a temporary failure occurs while sending a valid action, **When** the action can be retried safely, **Then** the system makes a bounded automatic retry before marking it pending sync.
3. **Given** the connection is interrupted after the final save status may be unknown, **When** the employee returns to attendance, **Then** the system checks the recorded status before allowing a new submission and clearly says to check request status if confirmation is still unavailable.
4. **Given** a pending action reaches the service later, **When** it is accepted or found already recorded, **Then** it is marked saved and removed from pending status without creating a duplicate.

---

### User Story 3 - Receive actionable Arabic guidance (Priority: P1)

As an employee, I receive concise Arabic guidance for a denied action, expired session, invalid attendance condition, or unexpected problem, and never see a technical error, exception code, or authorization-rule message.

**Why this priority**: Raw errors create confusion and encourage unsafe repeated submissions.

**Independent Test**: Trigger each supported attendance failure category and inspect the employee-visible message. Verify it is Arabic, names a next action, and contains no technical or implementation error text.

**Acceptance Scenarios**:

1. **Given** the employee is not permitted to perform an attendance action, **When** they submit, **Then** the system states in Arabic that the action could not be completed because access is unavailable and directs them to the responsible team; it is not queued or retried indefinitely.
2. **Given** the employee session is no longer valid, **When** they submit, **Then** the system asks them to sign in again in Arabic.
3. **Given** the location, device, time window, or attendance state is invalid, **When** they submit, **Then** the system explains the relevant correction in Arabic and does not retain an invalid action for synchronization.
4. **Given** an unexpected attendance failure occurs, **When** the action ends, **Then** the employee receives a safe Arabic fallback with the next step and no technical detail.

---

### User Story 4 - Preserve check-in business rules during migration (Priority: P2)

As HR and payroll staff, I can trust that improving employee-facing reliability does not alter established attendance policy, device requirements, approval reconciliation, deductions, or payroll-cycle allocation.

**Why this priority**: Attendance changes have downstream payroll consequences; reliability improvements must not silently change them.

**Independent Test**: Run characterization scenarios for valid check-in, duplicate submission, approved permission reconciliation, and delayed submission before and after the pilot. Verify the recorded attendance and downstream business state are unchanged apart from the new employee status wording and pending-sync tracking.

**Acceptance Scenarios**:

1. **Given** a valid attendance action is submitted multiple times or replayed after an outage, **When** synchronization completes, **Then** the final attendance record remains idempotent.
2. **Given** a late-arrival permission is approved after its execution date, **When** attendance reconciliation runs, **Then** the existing execution-date and payroll-cycle behavior is preserved.
3. **Given** the future attendance backend is changed, **When** the employee attendance workflow uses its approved service boundary, **Then** the employee-visible outcomes and business rules remain unchanged.

### Edge Cases

- The device is offline before location validation, versus losing connectivity after a valid check-in begins.
- A check-in is saved but its confirmation cannot return to the employee.
- A queued check-in is replayed after another client has already checked the employee in.
- The user changes account, signs out, or changes device while actions for a different account remain pending.
- A pending action is no longer valid because its allowed time window has ended before synchronization.
- A denied access response is reported after a previously working device binding; the action must be kept out of the retry loop and support diagnostics must not be shown to the employee.
- The same employee opens the attendance screen repeatedly while a pending action is synchronizing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The check-in pilot MUST expose every attempted check-in as one of: saved, pending synchronization, needs status check, or not saved.
- **FR-002**: The check-in pilot MUST use the shared structured outcome and safe-message foundation for all employee-visible check-in results.
- **FR-003**: The system MUST show employee-facing attendance outcomes in Arabic and MUST NOT expose technical service names, exception classes, error codes, raw authorization details, stack traces, credentials, or diagnostic identifiers.
- **FR-004**: The system MUST perform a bounded automatic retry only for an action that is safe to retry; it MUST stop retrying after the configured bounded attempt limit.
- **FR-005**: The system MUST retain a valid attendance action for later synchronization when it was not sent because of an outage or when a safely retryable temporary failure remains unresolved.
- **FR-006**: The system MUST distinguish a confirmed failure from an unknown final state. For an unknown final state, it MUST check recorded attendance status before offering a new action that could duplicate it.
- **FR-007**: The system MUST keep check-in idempotent across automatic retry, manual retry, app restart, reconnect, and queued synchronization.
- **FR-008**: The system MUST not queue or automatically retry actions rejected for access, authentication/session, invalid location, device/security requirements, invalid attendance time, or other confirmed validation conditions.
- **FR-009**: The system MUST surface pending synchronization status on the employee attendance view until the action is saved, rejected with a user-safe explanation, or requires employee/HR follow-up.
- **FR-010**: The system MUST keep queued attendance actions isolated to their authenticated employee and must not submit an action under a different employee account after sign-out, account switch, or device reuse.
- **FR-011**: The system MUST retain authorized diagnostics for support investigation while keeping those diagnostics separate from employee-visible messages.
- **FR-012**: The pilot MUST preserve existing check-in identity, location/device validation, attendance policy, late-arrival permission reconciliation, deduction, and payroll-cycle behavior unless a later reviewed specification explicitly changes it.
- **FR-013**: The employee check-in experience and business rules MUST remain unchanged if the company later replaces its backing service with a company-controlled service.
- **FR-014**: The system MUST have automated characterization and outcome tests for denied access, temporary service outage, duplicate check-in, interrupted submission, pending synchronization, and successful check-in.
- **FR-015**: The pilot MUST NOT alter check-out behavior, its employee messages, its synchronization behavior, or its business rules.

### Key Entities

- **Check-in Action**: A uniquely identifiable employee request to check in, including its intended time and required attendance evidence.
- **Check-in Outcome**: The employee-visible confirmed state of a check-in action: saved, pending synchronization, needs status check, or not saved.
- **Pending Attendance Action**: A valid, employee-owned action retained for later synchronization, with an idempotent identity and synchronization state.
- **Attendance Failure**: A categorized non-success outcome with safe retry guidance and restricted support diagnostics.
- **Status Check**: A verification step that determines whether a potentially interrupted check-in was recorded before another duplicate-prone submission is offered.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the migrated attendance pilot, 100% of employee-visible failures are Arabic, name a next action, and contain no raw technical error text or identifier.
- **SC-002**: Automated tests prove that a duplicate check-in creates no additional attendance event in 100% of covered retry, reconnect, and replay scenarios.
- **SC-003**: Automated outage scenarios prove that every valid action ends as saved, pending synchronization, or needs status check; none is represented to the employee as a false confirmed success.
- **SC-004**: A valid check-in completes with a visible final or pending status within 10 seconds under normal connectivity, excluding any time required for the employee to grant location/device permission.
- **SC-005**: In automated denied-access and invalid-condition scenarios, zero actions enter the automatic retry or pending-sync queue.
- **SC-006**: Existing characterization scenarios for attendance policy, deterministic identity, permission execution-date reconciliation, and payroll-cycle behavior remain passing after the pilot is introduced.
- **SC-007**: The migrated attendance experience can be verified against a substitute backing service in automated tests without changing employee outcomes or attendance business rules.

## Assumptions

- This phase is limited to employee manual check-in, including existing pending/offline synchronization. Check-out, automatic geofence attendance, reminders, HR attendance correction, and device-reset administration remain out of scope unless separately reviewed.
- The current canonical attendance identity and Cairo date/time rules remain authoritative for this pilot.
- A temporary outage is eligible for bounded retry only when the operation can be shown to be idempotent; otherwise it follows the status-check path rather than a blind retry.
- The user sees a concise status near the attendance action and in the attendance history; support diagnostics remain visible only to authorized staff.
- This feature does not authorize production access-rule changes, destructive data repair, migration of historical attendance, or any payroll/deduction policy change.
- The completed shared error foundation is the approved common contract for this pilot; its gradual adoption does not require replacing the current backing service in this phase.
