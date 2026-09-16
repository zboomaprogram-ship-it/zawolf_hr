# Feature Specification: Pending Early-Leave Checkout

**Feature Branch**: `main`

**Created**: 2026-09-16

**Status**: Approved on 2026-09-16

**Input**: Allow an employee to see and use checkout at the time requested in an early-leave permission before final approval. If the request is rejected and the employee used the early checkout, create a salary deduction of one quarter day per requested hour and warn the employee before checkout.

## User Scenarios & Testing

### User Story 1 - Checkout While Approval Is Pending (Priority: P1)

An employee who has checked in and submitted an early-leave request can see the checkout action at the requested departure time even while the request is still awaiting a manager or HR decision.

**Why this priority**: Employees must be able to leave at the requested time without waiting on a delayed approval screen refresh, while preserving a clear record of the unresolved decision.

**Independent Test**: Submit a two-hour early-leave request for a 17:00 workday, leave it pending, and verify that checkout becomes available at 15:00 without reopening the application.

**Acceptance Scenarios**:

1. **Given** an employee checked in today and has a pending two-hour early-leave request, **When** the time reaches 15:00 for a 17:00 workday, **Then** the checkout action becomes available immediately.
2. **Given** the request is still pending, **When** the employee opens the checkout confirmation, **Then** the employee sees that the request is not approved and that rejection can produce a half-day deduction.
3. **Given** the employee has not submitted an early-leave request, **When** the time is earlier than the scheduled end, **Then** checkout remains unavailable under the existing attendance policy.

---

### User Story 2 - Rejected Request Produces a Reviewable Deduction (Priority: P1)

When an employee uses an early checkout tied to a request that is later rejected, the system creates one auditable salary deduction consequence for HR review, calculated as one quarter day for each requested hour.

**Why this priority**: The company needs a predictable financial consequence without duplicate deductions or a payroll impact before authorized review.

**Independent Test**: Check out at 15:00 using a pending two-hour request, reject that request, and verify that exactly one half-day deduction appears for HR review and in the employee's deduction details.

**Acceptance Scenarios**:

1. **Given** an employee used a one-hour early checkout and the linked request is rejected, **When** the decision is finalized, **Then** one quarter-day deduction is created for HR review.
2. **Given** an employee used a four-hour early checkout and the linked request is rejected, **When** the decision is finalized, **Then** one full-day deduction is created for HR review.
3. **Given** the employee did not use the requested early checkout, **When** the request is rejected, **Then** no attendance deduction is created.
4. **Given** the same rejection or scheduled reconciliation is processed more than once, **When** processing completes, **Then** only one deduction consequence exists.

---

### User Story 3 - Approval Removes the Financial Consequence (Priority: P2)

An employee who used an early checkout while the request was pending receives no early-checkout deduction when the request is finally approved.

**Why this priority**: Final approval must reconcile the provisional attendance event according to the execution date and protect the employee from an incorrect deduction.

**Independent Test**: Check out using a pending request, approve it later, and verify that the attendance day remains authorized with no early-checkout salary deduction.

**Acceptance Scenarios**:

1. **Given** the employee checked out at the requested time while approval was pending, **When** the request is approved, **Then** no early-checkout deduction remains.
2. **Given** a provisional deduction was created before final approval, **When** approval is finalized, **Then** the provisional deduction is cleared without changing unrelated lateness or absence consequences.
3. **Given** the approval occurs in a later payroll cycle, **When** reconciliation runs, **Then** the consequence remains assigned to the request execution date and follows the existing closed-cycle adjustment policy.

### Edge Cases

- A rejected request can expose early checkout at its requested time, but the confirmation must state the exact deduction fraction before the employee proceeds.
- A request that becomes rejected while the dashboard is open updates the hint immediately.
- Checking out at or after the normal scheduled end creates no rejection-based early-leave deduction.
- A request covering one to four whole hours produces fractions of 0.25, 0.50, 0.75, or 1.00 day respectively; the result never exceeds one day.
- If multiple same-day requests exist, the checkout event must retain the exact request used, and one request cannot create more than one deduction consequence.
- Existing lateness, absence, missed-checkout, and permission-deduction consequences must not be overwritten or counted twice.
- If the global checkout policy is disabled, this feature cannot expose checkout or create checkout-only consequences.
- If the request cannot be validated, the application keeps the normal scheduled checkout time and explains that the request status could not be confirmed.
- Queued or retried checkout events retain the original event time, request identity, and decision snapshot.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST calculate a requested early checkout time from the employee's work schedule and the request duration.
- **FR-002**: A valid same-day early-leave request in a pending, approved, or rejected final state MUST make checkout available at the requested time when checkout is globally enabled and the employee has checked in.
- **FR-003**: The employee MUST see the request state before confirming early checkout.
- **FR-004**: For a pending request, the confirmation MUST state that rejection can create a deduction of one quarter day per requested hour and MUST show the resulting fraction for that request.
- **FR-005**: For a rejected request, the confirmation MUST state that using early checkout will create the displayed deduction for HR review.
- **FR-006**: The employee MUST be able to cancel the confirmation and remain checked in without any deduction being created.
- **FR-007**: Each checkout performed before the normal scheduled end MUST retain the exact early-leave request identity, request state observed at checkout, requested duration, effective departure time, and original checkout event time.
- **FR-008**: A rejected request MUST create a deduction consequence only when the employee actually checked out before the normal scheduled end using that request.
- **FR-009**: The rejection-based deduction fraction MUST equal `requested whole hours × 0.25 day`, capped at one full day.
- **FR-010**: A rejection-based deduction MUST enter the existing HR deduction-review flow; it MUST NOT reduce payroll or discipline metrics until HR approves it.
- **FR-011**: Final approval MUST authorize the linked early checkout and clear only the matching provisional early-checkout consequence.
- **FR-012**: Rejection and approval processing MUST be idempotent and MUST use the execution date rather than the decision date for attendance and payroll attribution.
- **FR-013**: The system MUST prevent the same permission and checkout event from producing both a permission deduction and an attendance deduction.
- **FR-014**: Repeated client submissions, offline replay, scheduled reconciliation, and repeated approval callbacks MUST converge to one attendance checkout and at most one matching deduction consequence.
- **FR-015**: Request-state changes MUST update the open employee dashboard without requiring application restart or manual refresh.
- **FR-016**: Employee deduction details MUST show the request date, requested hours, actual checkout time, rejection reason, calculated fraction, monetary estimate when available, and HR review state.
- **FR-017**: Authorized reviewers MUST be able to trace the deduction to the employee, attendance day, permission request, checkout event, and rejecting reviewer without exposing diagnostic data to the employee.
- **FR-018**: Existing scheduled-end checkout, approved permission, checkout-disabled, absence, and closed-payroll-cycle rules MUST remain unchanged except where this specification explicitly defines the pending/rejected early-leave path.

### Key Entities

- **Early-Leave Request**: The employee's requested execution date, duration, calculated departure time, approval state, decision reason, and approval trail.
- **Early Checkout Evidence**: The immutable link between the actual checkout event and the exact request state used to expose it.
- **Rejection-Based Deduction**: A deterministic, reviewable salary consequence linked to one early checkout and one rejected request.
- **Deduction Hint**: Employee-facing Arabic guidance showing request state and the exact possible or applicable day fraction before checkout.

## Success Criteria

### Measurable Outcomes

- **SC-001**: In all tested pending-request cases, checkout becomes available within five seconds of the requested departure time or a request-state update.
- **SC-002**: One-, two-, three-, and four-hour rejected requests produce exactly 0.25-, 0.50-, 0.75-, and 1.00-day reviewable deductions when early checkout was used.
- **SC-003**: Replaying a checkout, rejection, approval, or scheduled reconciliation ten times produces one checkout record and no more than one matching deduction consequence.
- **SC-004**: Approved requests produce zero rejection-based payroll impact, including when approval occurs after checkout.
- **SC-005**: Rejected requests that were not used produce zero attendance deduction records.
- **SC-006**: Every early checkout confirmation communicates the request state and exact deduction fraction before the employee confirms.
- **SC-007**: Existing attendance and payroll regression suites remain fully passing, including execution-date, pending-review, checkout-disabled, and closed-cycle cases.

## Assumptions

- Early-leave requests remain limited to one through four whole hours.
- “Not approved” includes requests still awaiting a decision; a final rejection still permits the requested early checkout but with the displayed deduction consequence.
- A rejected request creates a deduction awaiting HR review, consistent with existing salary-deduction governance; payroll and discipline change only after HR approval.
- The deduction uses the requested whole-hour duration, not elapsed wall-clock rounding, because the request and warning both present that duration before checkout.
- No deduction is created merely because a request was rejected; the employee must actually use early checkout before the scheduled end.
- Existing policy for adjustments after a payroll cycle is finalized remains unchanged.
