# Internal Contract: Web Attendance Access

All endpoints require the existing Firebase bearer token. They are internal Hostinger operations, not public developer APIs. Responses use the standard `{ ok, code, error }` failure shape and never expose another employee's attendance data to an employee.

## `GET /attendance/web-access/me`

Returns only the authenticated employee's effective web-attendance eligibility.

```json
{
  "ok": true,
  "eligible": true,
  "scope": "period",
  "startDate": "2026-09-13",
  "endDate": "2026-09-30"
}
```

A response with `eligible: false` must not reveal administrative notes or unrelated grant data.

## `GET /attendance/web-access/grants`

HR/Super Admin only. Returns a bounded paginated directory of current grant records and their status.

## `POST /attendance/web-access/grants`

HR/Super Admin only. Creates or replaces the selected employee's grant.

```json
{
  "employeeId": "firebase-uid",
  "scope": "period",
  "startDate": "2026-09-13",
  "endDate": "2026-09-30",
  "note": "عمل عن بُعد معتمد",
  "operationId": "uuid"
}
```

For `permanent`, `endDate` is omitted. The server validates actor authority, active employee status, date bounds, operation idempotency, and writes the grant plus audit event transactionally.

## `POST /attendance/web-access/grants/{employeeId}/revoke`

HR/Super Admin only. Requires `operationId` and optional note. It marks the current grant revoked and writes an audit event transactionally.

## Attendance-event extension

The existing `/attendance/events` request carries a trusted application-origin marker for web UI calls. The gateway verifies the caller's current grant only when that marker indicates web attendance. The marker does not grant access by itself: the Firebase identity and current Firestore grant are always checked server-side.

All existing attendance validation and response semantics remain unchanged.
