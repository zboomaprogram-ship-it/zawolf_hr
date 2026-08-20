# Check-in Outcome Contract

## Purpose

Define the boundary between employee check-in presentation, domain behavior,
local pending synchronization, and the current/future attendance service. This
is an internal application contract, not a public API promise.

## Domain repository contract

```text
submit(CheckInAction) -> OperationResult<CheckInReceipt>
resolveStatus(CheckInAction) -> CheckInStatusResolution
pendingFor(employeeScopeId) -> PendingCheckIn?
synchronizePending(employeeScopeId) -> OperationResult<CheckInReceipt>?
```

### Outcome mapping

| Situation | Domain outcome | Presentation state | Queue behavior |
|---|---|---|---|
| New deterministic check-in accepted | Success: `recorded` | saved | Remove matching pending item. |
| Same check-in already exists | Success: `alreadyRecorded` | saved | Remove matching pending item; do not create another record. |
| Offline before send | Success: pending retained | pendingSync | Persist the original valid action. |
| Retryable temporary failure, no receipt | Pending after bounded retry | pendingSync | Persist original action; no new timestamp/identity. |
| Submission result uncertain | Unknown failure, status resolution required | requiresStatusCheck | Keep item until status resolution. |
| Status confirms matching record | Success: `alreadyRecorded` | saved | Remove matching pending item. |
| Access denied | Failure: access/contact responsible team | failed | Do not queue or auto-retry. |
| Session invalid | Failure: authentication/sign in again | failed | Do not queue or auto-retry. |
| Location/device/time/policy invalid | Failure: validation/correct input | failed | Do not queue or auto-retry. |
| Unclassified failure | Failure: unexpected/check status | requiresStatusCheck | Do not claim saved. |

## Service receipt/status contract

The current service adapter and a future company-controlled adapter must supply
the same semantic results.

### Submit receipt

| Field | Required | Meaning |
|---|---|---|
| attendanceId | Yes | Canonical daily attendance ID for the authenticated employee. |
| action | Yes | `check_in`. |
| status | Yes | `recorded` or `already_recorded`. |

### Status resolution

| Input | Required behavior |
|---|---|
| Authenticated employee + attendanceId | Return only the matching employee's check-in status. |
| Attendance record has check-in evidence | Return a saved/already-recorded semantic result. |
| Record absent | Return a confirmed not-recorded semantic result; retry eligibility is determined by the original failure category. |
| Different employee or malformed identity | Reject as confirmed access/validation failure without leaking record information. |

## Presentation contract

- Presentation consumes `CheckInPresentationState`, not gateway exceptions,
  HTTP errors, Firestore types, or local-store types.
- Every failure state uses `UserSafeFailureMessage` or an approved attendance-
  specific Arabic message derived from a structured `AppFailure`.
- Saved, pending-sync, and needs-status-check states must remain visibly
  distinct in Arabic.
- The button cannot trigger a second submission while state is `submitting` or
  `requiresStatusCheck` for the same daily action.
- Check-out continues to use the existing live presentation and is not routed
  through this contract.
