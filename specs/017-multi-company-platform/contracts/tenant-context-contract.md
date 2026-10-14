# Contract: Tenant Context and Isolation

This contract applies to every 7DHUB HR feature, including existing routes as
they migrate. It is more restrictive than an individual feature's business
contract.

## Request context

An authenticated company operation supplies the requested company using its
company-scoped route and, during compatibility, `X-Company-Id`. If both are
present they must match. The server resolves:

1. authenticated person and active state;
2. requested company and lifecycle;
3. active company membership and platform grants;
4. capabilities and sensitive scopes;
5. target resource's immutable company ownership;
6. current policy, entitlement, and access revisions.

The requested company selects the authorization check; it does not satisfy it.

## Required invariants

- Every ordinary operation has exactly one company.
- A platform-global operation uses a declared global route and capability; it
  cannot omit company context to broaden an ordinary query.
- A resource whose company does not match the effective context returns
  `access_denied` without revealing whether it exists.
- Company suspension blocks ordinary access according to lifecycle policy;
  permitted global recovery operations remain explicit and audited.
- Company ID is immutable after record creation. Transfers create a new
  company-owned relationship and preserve prior history.
- Company and authority are part of operation-receipt identity and audit.

## List and search contract

All company-owned lists require server-applied company scope before additional
filters. Page sizes are restricted to supported bounded values. A missing or
unsupported company query plan fails safely; it never falls back to loading the
global collection and filtering on the client.

Global lists consume authorized control-plane projections and label every
result's company. They do not return raw company business records unless a
separate, field-scoped global capability contract explicitly permits them.

A cross-company manager list is also a bounded projection. It contains only
employees, teams, or actionable items covered by current delegations and labels
each result with its company. Opening or changing a result resolves that one
company's context and delegation again; a consolidated list never authorizes a
cross-company mutation.

A global department inbox follows the same rule. It returns only company-labelled
request summaries from materialized approval steps where the actor is an
eligible snapshotted member. The decision endpoint revalidates active global
department membership, capability, request ownership, step state, and
separation-of-duty rules within the request's company context.

All list/search endpoints use server-side whitelisted filters and stable sorts.
Search normalizes supported Arabic/English forms only after the authorized
company/module projection has been selected. Counts, facets, suggestions, and
empty states must not disclose unauthorized existence. Every item labels its
company and contains presentation-safe allowed actions calculated by the
server; an empty action list is valid for a read-only user.

An opaque cursor is bound to UID, access revision, company scope, module,
filter hash, and sort. Reusing it with changed parameters or revoked access
returns a safe refresh outcome. Saved views contain filters, sort, and column
preferences only; the server revalidates companies, fields, sensitive scopes,
and actions on every open.

## Mutation contract

Every company-owned mutation carries:

```json
{
  "operationId": "client-stable-id",
  "expectedVersion": 4,
  "payload": {}
}
```

The server binds the operation to company, actor, authority source, operation
type, target, and payload hash. The same ID and intent returns the original
receipt. A different company or payload returns `conflict` and changes nothing.

For an approval-pool step, the request step version is also checked inside the
same trusted transaction. Exactly one approve/reject transition commits. Other
eligible members racing or retrying receive the committed outcome rather than
performing another transition.

`view`, `sensitive_view`, `manage`, `decide`, and `export` are distinct checks.
A successful read, global role, organization title, manager relationship, or
client-rendered action never grants a mutation. Decision transactions also
enforce requester/self-approval, incompatible-duty, same-actor stage, and
configured dual-control rules before committing.

## Flutter domain contract

```text
CompanyContextState = uninitialized | selecting | active | switching |
                      offlineCached | membershipRevoked | companySuspended |
                      denied | retryableFailure

ActiveCompanyContext {
  uid, companyId, membershipId?, authorityGrantIds,
  capabilities, accessRevision, policyRevision,
  entitlementRevision, brandingRevision
}
```

`authorityGrantIds` may reference General HR or cross-company manager
delegations. Multiple effective grants are evaluated independently, and a
revoked grant invalidates cached context through `accessRevision`.

Presentation receives domain values and safe failures only. It may not inspect
tokens, Firestore documents, HTTP failures, or provider exceptions.

On switch, the coordinator stops old company streams, persists permitted
outbox state in the old namespace, activates the new namespace, loads safe
cached shell data, revalidates context, then refreshes. Old-company content may
not remain visible underneath the new branding.

## Offline and outbox contract

Each cache/outbox identity includes `uid`, `companyId`, feature, and operation
ID. A pending operation is synchronized only after the same person's current
authorization for the item's company is revalidated. Switching companies does
not delete or submit another company's work. Revoked access quarantines pending
items for status review without revealing them in another context.

## Notification and deep-link contract

Notification identity and payload include company ID and target stable ID.
Before displaying sensitive preview or opening a route, the client/server
revalidates company membership or global capability. If the active company is
different, the user sees a safe company-switch prompt only when they may access
the target. Otherwise the app opens a neutral destination without target data.

## Worker contract

Every scheduled/recovery operation receives an explicit company, job, and
business-period identity. The worker resolves company lifecycle, timezone,
policy, entitlement, lease, and checkpoint before querying business records.
Deterministic output IDs include company ID. A global recovery run expands into
bounded company work items rather than one unscoped employee scan.

## Compatibility contract

While a legacy slice is active:

- new company context is resolved before calling the legacy adapter;
- legacy queries include the first-company ownership filter or use an approved
  server projection;
- missing company ownership is allowed only for inventoried migration records
  under a time-bounded compatibility switch;
- no second production company may use that slice until its isolation tests
  and tenant-native write path pass;
- rollback selects the old adapter but never disables tenant authorization.
