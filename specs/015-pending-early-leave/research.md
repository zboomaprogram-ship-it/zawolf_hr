# Research: Pending Early-Leave Checkout

## Decision 1: Keep the server authoritative for early checkout

**Decision**: The client may display eligibility, but `scripts/attendance-gateway.js`
must re-read the user, attendance row, work schedule, checkout policy, and exact
permission before accepting an early checkout.

**Rationale**: Current clients calculate display times locally, while the Admin
gateway owns the canonical attendance write. Trusting the displayed state would
let a stale or altered client bind checkout to the wrong request or time.

**Alternatives considered**:

- Direct Firestore checkout from Flutter: rejected because it bypasses the
  existing gateway and weakens retry/security behavior.
- Treat any same-day permission as sufficient: rejected because multiple
  requests can exist and the evidence must retain the exact request used.

## Decision 2: Store the consequence on the permission

**Decision**: Add a nested `rejectionConsequence` object to the exact permission
document. Store a reference to it in immutable attendance checkout evidence.

**Rationale**: Attendance currently has one flat salary-deduction slot. Reusing
it could overwrite a late-arrival, absence, or missed-checkout deduction. The
permission is already execution-date scoped, carries the approval trail, and is
read by payroll. A nested consequence preserves the original rejected request
without converting the request itself into an approved request.

**Alternatives considered**:

- Overwrite or aggregate attendance deduction fields: rejected because HR
  could not review independent causes and unrelated evidence would be lost.
- Create a `manual_deductions` record: rejected because this is an automatic
  attendance consequence, not a manager-authored manual deduction, and current
  payroll does not consistently include that collection.
- Create a new top-level collection: rejected for this increment because it
  adds indexes, rules, queries, and a new lifecycle when permission identity is
  already a stable one-to-one parent.

## Decision 3: Calculate from requested whole hours

**Decision**: Use `min(1.0, requestedHours * 0.25)` for valid one-to-four-hour
requests. Store the fraction snapshot when checkout evidence is accepted.

**Rationale**: This exactly matches the approved product rule and the warning
shown before checkout. It is deterministic across retries and independent of
network delay.

**Alternatives considered**:

- Round actual early minutes: rejected because it can disagree with the request
  and warning.
- Reuse the current deductible-permission bands: rejected because that policy
  maps one/two hours to 0.25 and three/four to 0.50, which differs from this
  approved rule.

## Decision 4: Reconcile both event orderings

**Decision**: The checkout transaction creates the consequence immediately when
the request is already rejected. When checkout occurs first, the existing
decision flow calls a new idempotent reconciliation endpoint after rejection.
A bounded Hostinger repair worker processes records marked
`rejectionConsequence.reconciliationState == pending`.

**Rationale**: Either checkout or reviewer decision can happen first, and a
network failure can occur after the status write. The deterministic permission
identity makes all paths converge.

**Alternatives considered**:

- Rely only on the reviewer client callback: rejected because closing the app or
  a network failure could omit the deduction.
- Scan all rejected permissions: rejected because it is unbounded and expensive.
- Add a second GitHub schedule: rejected because Hostinger already owns live
  integration reconciliation and two schedulers would race.

## Decision 5: Preserve execution-date payroll semantics

**Decision**: `monthKey` remains derived from `requestDate`. Payroll includes a
rejection consequence only when its own HR review status is `approved`; it does
not require the rejected permission's top-level status to be approved.

**Rationale**: The request is correctly rejected while its consequence can be
approved independently. This preserves the 26–25 cycle and existing governance.
Finalized cycles remain unchanged and require the existing adjustment policy.

**Alternatives considered**:

- Change the permission status to approved after HR approves the deduction:
  rejected because it falsifies the leave decision.
- Apply the deduction at rejection: rejected because pending deductions must not
  affect payroll or discipline before HR review.

## Decision 6: Preserve original event time during offline replay

**Decision**: The gateway uses the queued action's original event time, validates
it under the existing stale-event window, and snapshots the current/final request
state plus the original checkout time. Duplicate submissions return the existing
receipt and never create another consequence.

**Rationale**: Replay time is not the attendance execution time. Existing gateway
identity is deterministic per employee/date and must remain so.

**Alternatives considered**:

- Use server receipt time: rejected because it can move the event past the
  requested time or into another date.

## Decision 7: Use additive fields and a feature flag for rollback

**Decision**: Add fields that old clients ignore and gate pending/rejected early
checkout with `pending_early_leave_checkout_v1`. Deploy server support before
enabling the client path.

**Rationale**: This follows the repository's Strangler Fig model and permits an
immediate rollback without deleting evidence or changing old attendance rules.

**Alternatives considered**:

- Replace existing approved-permission logic in one release: rejected because
  it increases the blast radius for attendance and payroll.
