# Data Model: Web Attendance Access Grants

## Current grant

**Collection**: `webAttendanceAccessGrants`  
**Document ID**: Firebase user ID of the employee

| Field | Type | Rules |
|---|---|---|
| `employeeId` | string | Must equal document ID. |
| `employeeName` | string | Snapshot for administrative display. |
| `employeeCode` | string | Snapshot for administrative display. |
| `scope` | `period` / `permanent` | Exactly one scope. |
| `startDate` | `YYYY-MM-DD` | Required for period; Cairo date. |
| `endDate` | `YYYY-MM-DD` / null | Required for period; inclusive; null for permanent. |
| `status` | `active` / `revoked` | Derived authorization requires `active`. |
| `revision` | integer | Increases for each replacement/revocation. |
| `grantedById` | string | Authenticated HR/Super Admin actor. |
| `grantedByName` | string | Actor display snapshot. |
| `grantedAt` | server timestamp | Grant write time. |
| `revokedById` | string / null | Set only on revocation. |
| `revokedAt` | server timestamp / null | Set only on revocation. |
| `note` | string / null | Optional, limited administrative note. |
| `updatedAt` | server timestamp | Last mutation time. |

### Validity

A grant is active when its `status` is `active` and either:

- `scope` is `permanent`; or
- `scope` is `period` and `startDate <= cairoToday <= endDate`.

A period is at most 366 calendar days. Inactive employee accounts cannot receive or retain an effective grant.

## Audit event

**Collection**: `webAttendanceAccessGrantAudit`  
**Document ID**: server-generated, with a server-side idempotency key for each management operation.

| Field | Purpose |
|---|---|
| `eventType` | `granted`, `updated`, or `revoked` |
| `employeeId`, `actorId` | Target and authorized actor |
| `before`, `after` | Safe grant snapshots; no credentials or device evidence |
| `operationId` | Deduplicates repeated administrative taps/retries |
| `createdAt` | Server timestamp |

## State transitions

```text
no grant ──grant──> active
active ──replace scope/dates──> active (revision + 1)
active ──revoke──> revoked
period active ──date passes──> expired for authorization (record remains active historically)
```

Expiry is computed at authorization/read time; no scheduler changes grant state merely because time passes.
