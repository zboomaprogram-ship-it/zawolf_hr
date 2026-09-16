# Data Model: Pending Early-Leave Checkout

All dates and time eligibility use `Africa/Cairo`. New fields are additive.

## Early-Leave Request (`permissions/{permissionId}`)

Existing identifying fields remain authoritative:

| Field | Type | Rule |
|---|---|---|
| `userId` | string | Must equal authenticated employee for checkout |
| `permissionType` | string | Must be `early_leave` |
| `requestDate` | `YYYY-MM-DD` | Must equal checkout execution date |
| `durationMinutes` | integer | 60, 120, 180, or 240 |
| `status` | string | `pending_manager`, `pending_hr`, `approved`, or `rejected` may expose checkout |
| `monthKey` | string | Payroll cycle key derived from `requestDate`, not decision date |

### New nested object: `rejectionConsequence`

| Field | Type | Meaning |
|---|---|---|
| `consequenceId` | string | Deterministic: `early_leave_rejection:{permissionId}` |
| `attendanceId` | string | Canonical `{userId}_{requestDate}` |
| `checkoutEventId` | string | Stable client/outbox event identity |
| `executionDate` | string | Copy of `requestDate` |
| `requestedMinutes` | integer | Validated duration snapshot |
| `dayFraction` | number | 0.25, 0.50, 0.75, or 1.00 |
| `amount` | number | Snapshot using existing payroll workdays and salary |
| `currency` | string | Employee salary currency |
| `reasonCode` | string | `rejected_early_leave_used` |
| `reasonLabel` | string | Arabic employee-facing reason |
| `rejectionReason` | string | Reviewer's recorded reason |
| `requestRejectedBy` | string | Reviewer UID from request trail |
| `requestRejectedAt` | timestamp | Final request decision time |
| `status` | string | `pending_hr`, `approved`, `rejected`, or `reversed` |
| `createdAt` | timestamp | First server projection time |
| `reviewedAt` | timestamp/null | HR consequence review time |
| `reviewedBy` | string/null | HR reviewer UID |
| `reconciliationState` | string | `not_applicable`, `pending`, or `complete` |
| `revision` | integer | Monotonic server revision for conflict detection |

The object is absent until early checkout evidence exists. A pending request may
set only `reconciliationState: pending` after checkout; no deduction is visible
or payable until a rejection exists and the projector fills the consequence.

## Early Checkout Evidence (`attendance/{userId}_{date}`)

### `earlyLeaveCheckoutEvidence`

| Field | Type | Meaning |
|---|---|---|
| `permissionId` | string | Exact validated request |
| `permissionStatusAtCheckout` | string | State observed by gateway |
| `requestedMinutes` | integer | Validated request duration |
| `requestedCheckoutAt` | timestamp | Scheduled end minus duration on execution date |
| `normalCheckoutAt` | timestamp | Normal scheduled end on execution date |
| `actualCheckoutAt` | timestamp | Original action event time |
| `checkoutEventId` | string | Stable action/outbox identity |
| `potentialDayFraction` | number | Warning/deduction snapshot |
| `gatewayRevision` | integer | Validation contract revision |
| `validatedAt` | timestamp | Server validation time |

Evidence is written in the same transaction as the first successful checkout.
A duplicate checkout returns the existing receipt and cannot replace evidence.

## Client Eligibility Read Model

`EarlyLeaveCheckoutEligibility` is domain-only and is not stored independently.

| Field | Type |
|---|---|
| `permissionId` | string |
| `requestState` | enum |
| `requestedCheckoutAt` | DateTime |
| `normalCheckoutAt` | DateTime |
| `requestedHours` | integer |
| `potentialDayFraction` | double |
| `warningArabic` | string |
| `canCheckoutNow` | boolean |

The repository watches only the current user's current Cairo-date early-leave
requests and deterministically chooses the earliest valid departure, breaking
ties by submission time and then document ID. The gateway still validates the ID.

## State Transitions

```text
pending_manager/pending_hr
  ├─ no checkout ──> approved or rejected (no consequence)
  └─ checkout used ──> immutable attendance evidence
                         ├─ approved ──> authorized / no consequence
                         └─ rejected ──> rejection consequence pending_hr

rejected before checkout
  └─ checkout used ──> evidence + rejection consequence pending_hr atomically

pending_hr consequence ──approve──> approved ──reverse──> reversed
                       └─reject────> rejected
```

Only an `approved` consequence contributes to discipline or payroll. A top-level
request status of `rejected` is expected and does not suppress it.

## Validation and Invariants

1. Employee, permission, attendance, and execution date identities must match.
2. Actual checkout must be at/after requested checkout and before normal end to
   create evidence for this feature.
3. Checkout at/after normal end follows the existing flow and creates no
   rejection consequence.
4. The feature cannot override a disabled global checkout policy.
5. `consequenceId` is unique per permission and never uses decision time.
6. Reconciliation updates only `rejectionConsequence`; existing flat attendance
   deduction fields remain untouched.
7. Approval of the request clears/marks not applicable only the matching
   consequence and never clears unrelated attendance deductions.
8. HR approval is required before payroll and discipline aggregation.
9. Finalized payroll cycles are not rewritten.
