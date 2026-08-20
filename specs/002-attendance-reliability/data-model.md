# Data Model: Check-in Reliability Pilot

## CheckInAction

An immutable record of one employee's intended daily check-in.

| Field | Meaning | Validation / invariant |
|---|---|---|
| actionId | Deterministic action identity | Derived from the canonical daily attendance identity plus `checkIn`; stable for every retry and replay. |
| attendanceId | Canonical daily attendance identity | Uses the existing employee-plus-Cairo-date convention. |
| employeeScopeId | Owner used for local isolation | Must match the authenticated employee before submission or visibility. |
| executionDate | Cairo attendance date | Never replaced by a later retry date. |
| capturedAt | Original captured check-in time | Never replaced after the first valid capture. |
| attendanceEvidence | Required location, device, biometric, and policy-derived evidence | Created only after current validation succeeds; diagnostic-only fields are never shown to employees. |
| policyOutcome | Existing late/deduction calculation inputs | Must preserve current check-in policy behavior. |

## CheckInReceipt

The authenticated service's authoritative answer for a submitted check-in.

| Field | Meaning | Validation / invariant |
|---|---|---|
| attendanceId | The recorded daily attendance identity | Must equal the action's attendanceId. |
| result | `recorded` or `alreadyRecorded` | Both represent a saved final state for the same owner. |
| confirmedAt | Time at which the service confirmed the result | May be absent only if the service cannot confirm the result. |

## PendingCheckIn

A durable local outbox item for a valid check-in that has not reached a final
saved state.

| Field | Meaning | Validation / invariant |
|---|---|---|
| action | Original CheckInAction | Immutable after capture. |
| ownerScopeId | Employee who owns the item | Required for every read, retry, display, and deletion. |
| syncState | `pending`, `checkingStatus`, `saved`, `requiresAttention`, or `rejected` | Only `pending` is eligible for automatic retry. |
| attempts | Number of bounded delivery attempts | Never exceeds the feature retry policy per synchronization pass. |
| lastAttemptAt | Latest delivery/status attempt | Used for bounded, non-polling retry scheduling. |
| failure | Safe structured failure when known | Never stores credentials, raw exceptions, or authorization rules. |

### State transitions

```text
captured valid check-in
  -> saved                         (confirmed receipt)
  -> pending                       (offline / safely retryable temporary failure)
  -> checkingStatus                (final result uncertain)
checkingStatus
  -> saved                         (record exists for same owner/action)
  -> pending                       (safe retry remains eligible)
  -> requiresAttention             (status cannot be confirmed)
pending
  -> saved                         (receipt or already-recorded result)
  -> rejected                      (confirmed access/session/validation failure)
  -> requiresAttention             (outcome cannot be safely resolved)
```

## CheckInPresentationState

The only state exposed to the employee UI for the migrated action.

| State | Employee meaning | Permitted next action |
|---|---|---|
| idle | No check-in action is currently running. | Start a valid check-in. |
| submitting | Evidence is being validated or sent. | Wait; duplicate tap is disabled. |
| saved | Check-in is confirmed. | View today’s attendance. |
| pendingSync | Check-in is retained for later delivery. | Keep connectivity/location available; no duplicate resubmission. |
| requiresStatusCheck | Final result is not confirmed. | Refresh/check current status; do not blindly re-submit. |
| failed | Check-in was not saved due to a confirmed condition. | Follow Arabic guidance: correct, sign in, or contact responsible staff. |

## Relationships and ownership

- One employee has at most one `CheckInAction` per canonical attendance date.
- One `CheckInAction` has zero or one local `PendingCheckIn` item.
- A receipt completes the matching action and removes its pending item only for
  the same employee scope.
- Existing attendance records remain the canonical business record; the outbox
  is not a second payroll or attendance source of truth.
