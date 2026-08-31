# Contract: Authenticated Company OS Operations API

Base path: `/company-os`. Every request requires a valid Firebase ID token.
Server authorization is derived from the authenticated UID, active employee
record, operational grants, manager relationship, and requested resource scope.

## Common envelopes

Successful mutation:

```json
{
  "ok": true,
  "operationId": "client-stable-id",
  "status": "saved",
  "resourceId": "stable-id",
  "version": 2
}
```

Safe failure:

```json
{
  "ok": false,
  "safeCode": "conflict",
  "retryable": false,
  "status": "conflict"
}
```

Allowed safe codes include `access_denied`, `invalid_input`, `conflict`,
`capacity_reached`, `temporary_unavailable`, and `status_check_required`. Raw
Firebase, Google, HTTP, stack, token, or internal exception text is forbidden.

List response:

```json
{
  "ok": true,
  "items": [],
  "nextCursor": null,
  "appliedScope": "self",
  "appliedFilters": {}
}
```

`limit` must be 10, 25, 50, or 100. Unsupported filters fail safely rather
than being silently ignored.

## Portal and identity

- `GET /company-os/me`
- `GET /company-os/me/summary`
- `GET /company-os/employees/{uid}/operations` (authorized scope only)

## Tickets

- `GET /company-os/tickets?scope=&status=&departmentId=&cursor=&limit=`
- `POST /company-os/tickets` (operation ID required)
- `GET /company-os/tickets/{id}` (employee DTO excludes private notes)
- `POST /company-os/tickets/{id}/assign`
- `POST /company-os/tickets/{id}/transition`
- `POST /company-os/tickets/{id}/comments`
- `POST /company-os/tickets/{id}/private-notes` (IT only)

Every mutation includes `operationId` and `expectedVersion`. Transition payloads
must match the domain lifecycle.

## Assets and software

- `GET|POST /company-os/assets`
- `GET|PATCH /company-os/assets/{id}`
- `POST /company-os/assets/{id}/assign`
- `POST /company-os/assets/{id}/return`
- `POST /company-os/assets/{id}/maintenance`
- `GET|POST /company-os/licenses`
- `GET|PATCH /company-os/licenses/{id}`
- `POST /company-os/licenses/{id}/assign-seat`
- `POST /company-os/licenses/{id}/revoke-seat`

Assignment, return, maintenance, and seat operations are transactional and
idempotent. A capacity or active-assignment conflict changes no state.

## Unified requests, Finance, and owner approval

- `POST /company-os/requests` creates a request in the existing ZaWolf request
  history and materializes the server-selected approval plan.
- `GET /company-os/requests?scope=&type=&status=&cursor=&limit=`
- `GET /company-os/requests/{id}` returns the same canonical request and audit
  journey used by the existing request center.
- `POST /company-os/requests/{id}/decision`
- `POST /company-os/requests/{id}/payment-status`
- `GET /company-os/finance/ledger?employeeUid=&from=&to=&cursor=&limit=`
- `GET /company-os/finance/payslips?employeeUid=&from=&to=`

The server, not the client, determines `costBearing`. Every cost-bearing plan
contains Finance and Company Owner stages. The initial managed owner policy
resolves the active employee with code `ceo-100`; responses expose UID and
display name, not the policy lookup implementation.

## Knowledge, dashboards, search, and audit

- `GET /company-os/knowledge?query=&category=&cursor=&limit=`
- `GET /company-os/dashboard?scope=&from=&to=`
- `GET /company-os/search?query=&types=&cursor=&limit=`
- `GET /company-os/reports/{type}?scope=&from=&to=&cursor=&limit=`
- `GET /company-os/audit?targetType=&targetId=&from=&to=&cursor=&limit=`

All responses are role-scoped before serialization. Search/export/audit never
contain private IT notes or fields outside the caller's scope.

## Organization structure

- `GET /company-os/organization/units?type=&parentId=&active=&cursor=&limit=`
- `GET /company-os/organization/tree?cursor=&limit=`
- `GET /company-os/organization/employees?query=&departmentId=&cursor=&limit=`
- `POST /company-os/organization/changes/preview`
- `POST /company-os/organization/units`
- `PATCH /company-os/organization/units/{id}`
- `POST /company-os/organization/units/{id}/reorder`
- `POST /company-os/organization/units/{id}/archive`
- `POST /company-os/organization/units/{id}/restore`
- `POST /company-os/organization/units/{id}/manager`
- `DELETE /company-os/organization/units/{id}/manager`
- `POST /company-os/organization/memberships/bulk`
- `GET /company-os/organization/changes/{operationId}`

All mutations require `organization_structure_manage`, `operationId`, expected
versions, and a matching unexpired impact-preview hash for destructive or bulk
changes. Unit IDs are server-issued and immutable. `DELETE` closes the current
manager assignment; it does not delete history.

The bulk membership payload accepts at most 100 employee UIDs and one action:
`add`, `remove`, or `transfer`. It returns one receipt for the whole operation;
partial success is forbidden. Employee search and hierarchy reads are bounded
and scoped before serialization.

Safe organization codes additionally include `duplicate_unit`,
`unit_has_dependencies`, `manager_inactive`, `manager_required`,
`orphan_membership`, `preview_expired`, and `hierarchy_changed`. Raw employee
records, tokens, provider errors, and unrestricted manager scope are forbidden.

## Idempotency and audit invariants

1. An operation ID maps to one actor, operation type, and payload hash.
2. Repeating the same operation returns the original receipt.
3. Reusing it for a different payload returns `conflict`.
4. State mutation and one append-only audit event commit atomically.
5. Network ambiguity returns `status_check_required`; clients reconcile before
   resubmitting with a new operation ID.
