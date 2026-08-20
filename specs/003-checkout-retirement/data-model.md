# Data Model: Check-out Policy Control

## Current Policy

Logical document: `publicConfig/checkoutPolicy`

| Field | Type | Meaning |
|---|---|---|
| `enabled` | boolean | Current status; absence means `false` |
| `revision` | integer | Monotonically increasing transaction version |
| `effectiveAt` | server timestamp | When state became effective |
| `changedByUserId` | string | Authorized HR/super-admin actor |
| `changedByRole` | string | Normalized role at change time |
| `reason` | string/null | Optional, bounded audit reason |
| `updatedAt` | server timestamp | Last server update |

The final field names can follow the project configuration convention, but
default-off behavior is contractual.

## Policy Audit Event

Logical collection: `publicConfig/checkoutPolicy/events/{eventId}`

| Field | Type | Meaning |
|---|---|---|
| `revision` | integer | Unique committed revision |
| `previousEnabled` | boolean | Prior state |
| `enabled` | boolean | New state |
| `effectiveAt` | server timestamp | Effective point |
| `changedByUserId` | string | Actor |
| `changedByRole` | string | Role snapshot |
| `reason` | string/null | Optional reason |
| `source` | string | `hr_dashboard` |

Events are append-only and ordered by revision.

## Snapshot on a Decision

New check-out-only actions/consequences record:

| Field | Type | Meaning |
|---|---|---|
| `checkoutPolicyEnabled` | boolean | Status evaluated |
| `checkoutPolicyRevision` | integer | Revision used |
| `checkoutPolicyEvaluatedAt` | timestamp | Server evaluation time |
| `checkoutPolicyDecisionPoint` | string | `action_received`, `reminder_enqueue`, or `attendance_cutoff` |

Do not backfill or alter historic records merely to add this snapshot.

## Request and Attendance Rules

- Official leave, `late_arrival`, and `early_leave` retain existing approvals.
- No `checkOutTime` is created for an early-leave request when disabled.
- Disabled periods cannot create `missed_checkout_quarter_day`,
  `early_checkout_quarter_day`, or other check-out-only work.
- Historical documents remain immutable unless an already-authorized manual
  correction process changes them.
