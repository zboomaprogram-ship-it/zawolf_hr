# Research: Check-in Reliability Pilot

## Decision 1: Add a parallel check-in slice; retain the live check-out path

**Decision**: Implement only employee manual check-in under
`features/attendance_checkin`, selected through a deliberate pilot seam in the
existing employee dashboard. Leave `handleCheckInOrCheckOut` and the existing
check-out branch behavior unchanged until a future reviewed slice replaces it.

**Rationale**: The user explicitly removed check-out from scope. The legacy
service currently combines check-in and check-out, and directly changing it
would risk deductions and payroll-adjacent behavior. A parallel slice follows
the required Strangler Fig migration and lets parity be proven before rollout.

**Alternatives considered**:

- Refactor the combined legacy service in place — rejected: would change the
  check-out code path in a check-in-only feature.
- Disable or remove check-out — rejected: outside approval and disrupts live
  attendance.

## Decision 2: Model receipt and status explicitly

**Decision**: The remote check-in adapter returns a structured receipt for both
`recorded` and `already_recorded`, and supports a bounded status lookup for the
current employee's deterministic daily attendance identity.

**Rationale**: The current gateway already uses `{actor UID}_{Cairo date}` and
returns `recorded` or `already_recorded` for check-in. Its Flutter client drops
that response. Capturing the receipt makes duplicates safe and allows a timeout
to resolve as saved rather than be misrepresented. When no final receipt is
available, one authenticated, actor-owned status lookup prevents a blind second
submission.

**Alternatives considered**:

- Treat every temporary failure as a failure — rejected: a valid check-in could
  already have been recorded and employees would retry unnecessarily.
- Blindly retry indefinitely — rejected: poor user experience, excess traffic,
  and violates bounded retry requirements.
- Query attendance directly from presentation — rejected: violates the feature
  boundary and keeps UI tied to the current provider.

## Decision 3: Use a dedicated durable, account-scoped check-in outbox

**Decision**: Create a new Drift-backed local outbox abstraction for the pilot.
It persists only valid check-in actions and their synchronization state, keyed
by employee identity plus deterministic action identity. It exposes actions
only for the currently authenticated employee.

**Rationale**: The constitution requires a durable local source of truth for
migrated offline-capable modules. Drift provides the required durable local
source of truth across the supported Flutter targets. The existing
`SharedPreferences` queue holds both check-in and check-out legacy actions and
synchronizes all entries under the current session; changing it risks the
out-of-scope checkout path. A new outbox protects account isolation and can
later be reused by a server-backed implementation.

**Alternatives considered**:

- Extend the existing queue — rejected: it touches check-out and lacks a clean
  migration boundary.
- Keep pending state only in memory — rejected: lost on app restart.
- Store all actions without account partitioning — rejected: a sign-out/account
  switch could attempt delivery under the wrong session.

## Decision 4: Retry only deterministic, idempotent check-in actions

**Decision**: Retry the identical, deterministic check-in action at most twice
after its initial transient failure. If no final receipt is received, perform
one status check; then report saved, pending synchronization, or needs status
check. Confirmed access/session/validation failures bypass retry and queue.

**Rationale**: The existing server creates the deterministic attendance record
only if absent and returns `already_recorded` for repeats. That makes the same
check-in action safe to retry. The app must never retry with a new action ID or
new timestamp after an uncertain attempt, because that changes audit evidence.

**Alternatives considered**:

- Retry every error — rejected: denied and invalid actions cannot recover this
  way and should not be queued.
- Require manual retry on every transient failure — rejected: fails the stated
  smooth attendance goal.

## Decision 5: Classify at the data boundary; render only safe state

**Decision**: Map gateway, location/security, session, and local-outbox errors
to `AppFailure` inside feature data/use cases. The Cubit receives only domain
outcomes and maps those to defined presentation states; it never receives a raw
exception or infrastructure type.

**Rationale**: The current dashboard inspects exception text, including raw
provider-specific strings. The completed error foundation already defines safe
categories and Arabic messages. Central mapping prevents future server changes
from leaking into employees' screens.

**Alternatives considered**:

- Continue string matching in the dashboard — rejected: fragile, exposes
  implementation details, and prevents portability.
- Put HTTP/local storage work in the Cubit — rejected: violates the focused
  Cubit and layered-boundary rules.

## Decision 6: Do not add a continuous attendance listener or poller

**Decision**: Refresh only after a submitted action, a pending-sync attempt, or
the existing attendance view refresh. Status resolution is one bounded request
per uncertain action.

**Rationale**: The project has Firestore quota pressure. The current monthly
attendance stream remains legacy behavior; this pilot must not add another
listener or background polling loop.

**Alternatives considered**:

- Repeatedly poll until confirmation — rejected: unpredictable quota cost and
  battery/network use.
- Add a second real-time listener — rejected: unnecessary for a single action
  and violates the read-budget goal.
