# Contract: Early-Leave Checkout and Reconciliation

This contract extends existing authenticated Hostinger APIs. Every request uses
a Firebase ID token. The server derives employee identity from the token and
does not trust identity, status, schedule, fraction, or salary values sent by the
client.

## Submit attendance checkout

`POST /attendance/actions`

Existing payload fields remain. For an early-leave checkout, add:

```json
{
  "action": {
    "type": "checkOut",
    "attendanceId": "USER_2026-09-16",
    "date": "2026-09-16",
    "eventTime": 1789556400000,
    "eventId": "device-generated-stable-id",
    "earlyLeavePermissionId": "permission-document-id"
  }
}
```

### Server behavior

1. Apply existing authentication, device, location, stale-event, and checkout
   policy validation.
2. Load the exact permission and require matching employee, type, and date.
3. Reconstruct requested and normal checkout times from the server schedule.
4. Reject an event earlier than requested checkout.
5. In one transaction, write checkout and immutable evidence. If the request is
   already rejected, also project its nested consequence.

### Success

```json
{
  "ok": true,
  "action": "check_out",
  "status": "recorded",
  "attendanceId": "USER_2026-09-16",
  "earlyLeave": {
    "permissionId": "permission-document-id",
    "requestStatus": "pending_manager",
    "potentialDayFraction": 0.5,
    "consequenceStatus": "pending_decision"
  }
}
```

Duplicate submission returns `status: already_recorded` with the original
attendance identity and does not replace its evidence.

### Errors

| HTTP | Code | Meaning |
|---|---|---|
| 400 | `invalid_early_leave_request` | ID/type/date/duration is invalid |
| 403 | `early_leave_not_owned` | Request belongs to another employee |
| 409 | `early_checkout_too_early` | Event precedes requested departure |
| 409 | `checkout_policy_disabled` | Global checkout is disabled |
| 409 | `checkout_already_bound` | Existing checkout is linked to different evidence |
| 503 | `early_leave_validation_unavailable` | Request cannot be safely validated |

The client falls back to normal scheduled checkout when validation is
unavailable; it must not silently send an unbound early checkout.

## Reconcile a permission decision

`POST /attendance/early-leave/reconcile`

```json
{
  "permissionId": "permission-document-id"
}
```

The authenticated actor must be an authorized reviewer or the trusted recovery
worker. The server re-reads the final permission and linked attendance evidence.
It never accepts a status or deduction amount from the caller.

### Result variants

```json
{ "ok": true, "status": "not_used" }
```

```json
{
  "ok": true,
  "status": "consequence_pending_hr",
  "consequenceId": "early_leave_rejection:permission-document-id",
  "dayFraction": 0.5
}
```

```json
{ "ok": true, "status": "authorized" }
```

Repeated calls return the same semantic result. They cannot create another
consequence or change an HR-reviewed consequence.

## HR consequence review

The existing HR review surface calls a server-authoritative mutation using the
permission ID and decision `approved` or `rejected`. The mutation changes only
`rejectionConsequence.status`, records reviewer/time/revision, writes an audit
event, and notifies the employee. It cannot change the top-level rejected
permission decision.

## Recovery worker contract

Hostinger queries a bounded set of permissions with:

- `rejectionConsequence.reconciliationState == pending`;
- a recent `updatedAt` lower bound;
- a fixed page limit and cursor.

Each result is passed to the same reconciliation function as the HTTP endpoint.
No second live scheduler owns this responsibility.
