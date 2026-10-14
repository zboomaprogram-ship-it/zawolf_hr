# Contract: 7DHUB Platform Management API

These are internal authenticated Hostinger operations. The authenticated token
identifies the person; submitted UIDs, role labels, or company IDs never grant
authority. Every list is bounded and every mutation uses `operationId` and
`expectedVersion` where applicable.

## Common response envelopes

Successful mutation:

```json
{
  "ok": true,
  "operationId": "stable-client-id",
  "status": "saved",
  "resourceId": "stable-id",
  "version": 2
}
```

Safe failure:

```json
{
  "ok": false,
  "safeCode": "access_denied",
  "retryable": false,
  "status": "denied",
  "diagnosticRef": "safe-correlation-id"
}
```

Supported outcome families include `invalid_input`, `access_denied`,
`company_inactive`, `membership_inactive`, `leadership_required`, `conflict`,
`already_applied`, `temporary_unavailable`, and `status_check_required`. Raw
provider errors, paths, tokens, stack traces, and protected record data are
never returned.

## Current person's company access

### `GET /platform/v1/me/companies?cursor=&limit=`

Returns the authenticated person's bounded safe company-access projection and
global-management availability.

```json
{
  "ok": true,
  "items": [{
    "companyId": "company-id",
    "displayName": "Company",
    "logo": {"descriptor": "opaque-thumb", "version": 3},
    "primaryColor": "#123456",
    "membershipState": "active",
    "roleLabel": "HR",
    "lastUsedAt": "server-time"
  }],
  "globalManagement": {"available": true},
  "nextCursor": null
}
```

### `POST /platform/v1/me/company-context`

Request:

```json
{"companyId":"company-id","operationId":"stable-id"}
```

Returns a presentation-safe context summary and capability keys. It does not
return salary access, membership lists, or provider credentials.

## Company registry

- `GET /platform/v1/companies?status=&query=&cursor=&limit=`
- `GET /platform/v1/companies/{companyId}`
- `POST /platform/v1/companies/preview`
- `POST /platform/v1/companies`
- `PATCH /platform/v1/companies/{companyId}`
- `POST /platform/v1/companies/{companyId}/activate`
- `POST /platform/v1/companies/{companyId}/suspend`
- `POST /platform/v1/companies/{companyId}/restore`
- `POST /platform/v1/companies/{companyId}/archive`
- `GET /platform/v1/companies/{companyId}/health`

Lifecycle operations require Platform Super Admin company-lifecycle capability,
reason, expected company version, impact preview token, and operation ID.
Activation returns missing/invalid setup requirements without partially
activating the company.

## Leadership and membership bootstrap

- `GET /platform/v1/companies/{companyId}/leadership?cursor=&limit=`
- `POST /platform/v1/companies/{companyId}/leadership/preview`
- `POST /platform/v1/companies/{companyId}/leadership/apply`
- `POST /platform/v1/companies/{companyId}/invitations`
- `GET /platform/v1/companies/{companyId}/invitations/{invitationId}`
- `POST /platform/v1/invitations/{invitationId}/accept`

The server attaches an invitation to an existing person identity when verified
identity matches. It rejects duplicate active membership and any operation that
would leave an active company without mandatory leadership.

## Platform grants

- `GET /platform/v1/grants?uid=&role=&state=&cursor=&limit=`
- `POST /platform/v1/grants/preview`
- `POST /platform/v1/grants`
- `PATCH /platform/v1/grants/{grantId}`
- `POST /platform/v1/grants/{grantId}/revoke`

The server validates grantor authority, company scope, sensitive scopes,
expiry, reason, and separation from company roles. General HR does not receive
salary/payroll, security, billing, lifecycle, or developer scopes unless they
are explicit in the approved grant.

The grant collection supports multiple concurrent General HR recipients. Each
grant is versioned and revoked independently; role names are never treated as a
singleton slot.

## Cross-company manager delegations

- `GET /platform/v1/manager-delegations?managerUid=&companyId=&state=&cursor=&limit=`
- `POST /platform/v1/manager-delegations/preview`
- `POST /platform/v1/manager-delegations`
- `PATCH /platform/v1/manager-delegations/{delegationId}`
- `POST /platform/v1/manager-delegations/{delegationId}/revoke`
- `GET /platform/v1/me/managed-companies?cursor=&limit=`
- `GET /platform/v1/me/managed-work?companyId=&kind=&cursor=&limit=`

Delegations identify one target company per row, an explicit employee/team
scope, permitted management capabilities, effective dates, reason, and
granting authority. Consolidated managed-work results are safe projections and
always include company origin. The client must use the returned company when
opening an item; the item's normal company-scoped endpoint revalidates the
delegation before returning data or accepting a decision.

## Global shared-services departments

- `GET /platform/v1/global-departments?state=&query=&cursor=&limit=`
- `POST /platform/v1/global-departments/preview`
- `POST /platform/v1/global-departments`
- `PATCH /platform/v1/global-departments/{departmentId}`
- `POST /platform/v1/global-departments/{departmentId}/activate`
- `POST /platform/v1/global-departments/{departmentId}/suspend`
- `GET /platform/v1/global-departments/{departmentId}/members?cursor=&limit=`
- `POST /platform/v1/global-departments/{departmentId}/members/preview`
- `POST /platform/v1/global-departments/{departmentId}/members`
- `PATCH /platform/v1/global-departments/{departmentId}/members/{membershipId}`
- `POST /platform/v1/global-departments/{departmentId}/members/{membershipId}/revoke`
- `GET /platform/v1/me/global-department-work?companyId=&requestType=&cursor=&limit=`

Department administration requires explicit platform capabilities. A
department and each member have independent company/request scopes and
effective dates. Membership grants only the safe request summary and decision
actions configured for that pool; it does not grant general tenant navigation,
salary, payroll, or employee data access.

Company approval-chain APIs accept a target descriptor such as:

```json
{
  "targetType": "global_department_pool",
  "targetId": "global-accounting",
  "decisionPolicy": "first_valid_decision"
}
```

Publishing validates target lifecycle, scope, and eligible coverage. Request
submission stores the target/policy versions and bounded eligible UID snapshot.
The ordinary company request-decision endpoint performs the decision in a
transaction: the first valid approve/reject wins, records the actual actor, and
advances or rejects once; concurrent and repeated calls return
`already_decided` with the safe committed outcome.

## Global operations and company drill-down

- `GET /platform/v1/operations/summary?companyId=&from=&to=&cursor=&limit=`
- `GET /platform/v1/operations/alerts?companyId=&kind=&status=&cursor=&limit=`
- `GET /platform/v1/operations/companies/{companyId}/attendance?status=&from=&to=&cursor=&limit=`
- `GET /platform/v1/operations/companies/{companyId}/requests?type=&status=&cursor=&limit=`
- `GET /platform/v1/operations/companies/{companyId}/payroll?cycle=&status=&cursor=&limit=`
- `GET /platform/v1/operations/companies/{companyId}/performance?department=&status=&cursor=&limit=`
- `GET /platform/v1/operations/companies/{companyId}/employees?query=&department=&state=&cursor=&limit=`
- `GET /platform/v1/operations/companies/{companyId}/reports?kind=&from=&to=&cursor=&limit=`

Platform Super Admin receives complete cross-company summary and detail access.
Global HR receives complete HR detail—including salary, payroll, deductions,
attendance, requests, employees, performance, tasks, reports, and HR files—for
every company in the grant scope. Results always label company origin and use
bounded server-side queries. Summary values carry source watermarks and must
reconcile with canonical company data. Read access does not grant mutation;
create/update/decision/export/delete actions require their own capabilities.

Private direct-message content, platform credentials, developer configuration,
security administration, billing, and company-lifecycle controls use separate
capabilities and are never included merely because Global HR can see complete
HR operations.

## Federated organization, jobs, and global search

- `GET /platform/v1/organization/tree?companyId=&rootId=&depth=&asOf=&cursor=&limit=`
- `GET /platform/v1/organization/search?query=&companyId=&nodeType=&jobFamily=&state=&sort=&cursor=&limit=`
- `POST /platform/v1/organization/preview`
- `POST /platform/v1/organization/publish`
- `GET /platform/v1/job-catalog?query=&family=&state=&sort=&cursor=&limit=`
- `GET /platform/v1/search?module=&query=&companyId=&department=&jobTitle=&status=&actor=&from=&to=&sort=&cursor=&limit=`
- `GET /platform/v1/me/saved-views?module=&cursor=&limit=`
- `POST /platform/v1/me/saved-views`
- `PATCH /platform/v1/me/saved-views/{viewId}`
- `DELETE /platform/v1/me/saved-views/{viewId}`

Organization responses retain separate platform/company ownership and return
positions independently from occupants. Publish rejects cycles, orphaned nodes,
cross-owner parents, ambiguous active primary placements, and invalid reporting
relationships. An organization edit does not rewrite a materialized workflow.

Global search normalizes supported Arabic/English variants and applies
authorization before matching, counts, facets, or suggestions. Each result
includes `companyId`, safe company label, module, stable target ID, version, and
server-calculated `allowedActions`. Supported sorts are whitelisted and stable;
the opaque cursor is bound to the actor access revision and complete filter/sort
hash. A changed query, expired access revision, or revoked saved-view field
returns a safe refresh result rather than reusing stale authority.

## Visibility and action contract

Every module evaluates these capability families independently:

- `view`: ordinary fields and safe existence;
- `sensitive_view`: named salary, payroll, medical, private, or security fields;
- `manage`: create/update/configure/archive operations;
- `decide`: approve/reject/resolve a materialized work item;
- `export`: produce or download a bounded export.

A list or detail response can show an item with an empty `allowedActions` array.
The client uses this only to render controls. Mutation and decision endpoints
revalidate identity, target company, current grant/delegation, materialized
approval eligibility, self-approval/incompatible-duty policy, distinct-actor
requirements, expected version, and operation ID. Platform Super Admin and
General HR visibility alone never supplies business approval authority.

## Feature entitlements

- `GET /platform/v1/companies/{companyId}/entitlements`
- `POST /platform/v1/companies/{companyId}/entitlements/preview`
- `POST /platform/v1/companies/{companyId}/entitlements/apply`

Entitlements enable modules but never grant an individual permission.

## Branding

- `GET /platform/v1/companies/{companyId}/branding`
- `POST /platform/v1/companies/{companyId}/branding/uploads`
- `PUT /platform/v1/companies/{companyId}/branding/uploads/{uploadId}`
- `POST /platform/v1/companies/{companyId}/branding/uploads/{uploadId}/finalize`
- `POST /platform/v1/companies/{companyId}/branding/preview`
- `POST /platform/v1/companies/{companyId}/branding/publish`

Upload/finalize follows the governed media contract and returns opaque
descriptors. Publish validates ownership, content type, size, dimensions,
checksum, accessible colors, expected version, and review authority. Clients
always retain bundled 7DHUB fallback assets.

## Global audit and migration

- `GET /platform/v1/audit?companyId=&actorUid=&action=&from=&to=&cursor=&limit=`
- `POST /platform/v1/migrations/initial-company/preview`
- `GET /platform/v1/migrations/{batchId}`
- `GET /platform/v1/migrations/{batchId}/issues?type=&cursor=&limit=`
- `POST /platform/v1/migrations/{batchId}/approve`
- `POST /platform/v1/migrations/{batchId}/apply-page`
- `POST /platform/v1/migrations/{batchId}/reconcile`
- `POST /platform/v1/migrations/{batchId}/pause`

Migration apply is unavailable through ordinary company administration. A dry
run is mandatory. Ambiguous items remain unresolved; an apply retry returns the
existing receipt. Production execution requires an external approved runbook
and rollback authorization beyond this API contract.
