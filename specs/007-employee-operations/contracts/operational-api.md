# Operational API Contract

Existing Hostinger authenticated runtime routes require a Firebase ID token. The
actor comes from the token, never a submitted user ID. Every error follows the
safe envelope in `diagnostics-and-conversations.md`.

## `GET /operations/employee-timeline`

Parameters: `employeeId`, `startDate`, `endDate`, optional `includeHidden`.
HR/admin may request authorized employees; managers are team-scoped; employees
only self. Cairo dates are capped to 93 days per query and longer history uses a
cursor. Returns ordered attendance, leave, permissions, corrections, requests,
and deduction explanation references by effective date.

## `PUT /operations/account-visibility/{employeeId}`

Body: `{ "mode": "included" | "hidden_from_default_operational_views", "reason": "...", "operationId": "uuid" }`.
HR/admin only. Idempotent and audited. Does not change active, payroll, or
attendance state.

## `POST /operations/notification-read-all`

Body: `{ "operationId": "uuid" }`. Marks the actor's items read in bounded
pages and updates canonical unread count per page. Repeating the ID is safe.

## `POST /operations/resolve-notification`

Body: `{ "notificationId": "..." }`. Returns authorized
`{path, focusId?, fallbackPath}`. Approvers get management context, employees
their own context, and revoked/unavailable targets fall back to a safe list.

## `POST /operations/diagnostics`

Accepts sanitized diagnostic fields only, rate limits, and aggregates by safe
fingerprint/release.

## `PUT /operations/developer-tools/{employeeId}`

Body: `{ "enabled": true, "expiresAt": "...", "scopes": ["diagnostics"], "reason": "...", "operationId": "uuid" }`.
HR/admin only; every change is audited and expiry is mandatory. The route only
controls an in-app developer menu. It has no security-bypass field and cannot
affect USB debugging, mock-location detection, device binding, geofence,
attendance, payroll, or approval behavior.
