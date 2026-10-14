# Data Model: 7DHUB Multi-Company Platform

## Ownership classes

Every persisted entity is classified before migration:

| Class | Examples | Ownership rule |
|---|---|---|
| Platform-global | company registry, platform grants, entitlements | No employee business data; platform capability required |
| Company-owned | employees, attendance, requests, payroll, chat, files | Exactly one immutable `companyId` |
| Person-private and company-indexed | company picker, notification routing, device preference | One person, entries separated by company |
| Migration-only | inventory findings, batch items, parity reports | Explicit source and target company plus retention policy |

Missing ownership is never interpreted as a valid new-company record after the
migration compatibility window.

## Company

| Field | Rule |
|---|---|
| `id` | Immutable opaque platform ID |
| `code` | Required normalized code; globally unique across active and archived companies |
| `legalName` / `displayName` | Required; display name may be localized |
| `status` | `draft`, `active`, `suspended`, or `archived` |
| `timezone` | Required IANA timezone |
| `currency` | Required supported currency code |
| `locale` | Required default language/format locale |
| `workweek` | Versioned operating-day defaults |
| `contact` | Approved company contact details |
| `brandingProfileId` | Published branding version or null for 7DHUB fallback |
| `policySetId` | Current effective policy-set version |
| `version` | Optimistic concurrency revision |
| audit fields | creator/updater and server timestamps |

### State transitions

```text
draft -> active -> suspended -> active
  |         |          |
  +-------> archived <-+
```

Activation requires complete leadership and configuration. Archive is logical;
permanent deletion is outside this phase.

## Company Branding Profile

| Field | Rule |
|---|---|
| `id`, `companyId`, `version` | Stable version identity and immutable company ownership |
| `displayName` | Safe company-facing name |
| `logoDescriptors` | Opaque authorized light/dark/compact media variants |
| `primaryColor`, `accentColor` | Validated color values |
| `contrastAssessment` | Pass/fail plus safe corrected alternatives when needed |
| `status` | `draft`, `published`, `superseded`, `rejected` |
| `contentHash` | Detects asset/version reuse and corruption |
| audit fields | actor, review/publish time, reason |

Only one version is published for a company. Missing or failed media resolves to
the bundled 7DHUB profile.

## Person Identity

| Field | Rule |
|---|---|
| `uid` | Authentication identity; immutable |
| `primaryEmail` | Normalized sign-in/recovery identity |
| `displayName` | Platform-safe display value; company profiles may add local values |
| `state` | `active`, `disabled`, `recovery_required` |
| `accessRevision` | Changes whenever platform/company access changes |
| audit fields | creation/update evidence |

Person identity contains no single authoritative company role, department,
manager, salary, or employee code.

## Company Membership

| Field | Rule |
|---|---|
| `id` | Deterministic or stable identity for `(companyId, uid, membership sequence)` |
| `companyId`, `uid` | Immutable relationship endpoints |
| `employeeCode` | Unique among active memberships within the company |
| `rolePolicyId` | Managed company-role/capability policy |
| `employmentState` | `invited`, `active`, `suspended`, `terminated`, `expired` |
| `effectiveFrom`, `effectiveTo` | Effective-dated authorization boundary |
| `organizationMembershipIds` | Company-owned organization placements |
| `primaryOrganizationMembershipId` | Deterministic routing placement |
| `profile` | Company-specific title, display name overrides, and work metadata |
| `version` | Conflict token |
| audit fields | inviter, activator, updater, timestamps |

Overlapping active memberships for the same person/company are rejected unless
a later approved design introduces multiple employment contracts. A person may
hold memberships in different companies concurrently.

## Platform Role Grant

| Field | Rule |
|---|---|
| `id`, `uid` | Stable grant identity and recipient |
| `role` | `platform_super_admin`, `general_hr`, or later managed platform role |
| `capabilities` | Explicit allowed actions; no implicit company-role inheritance |
| `companyScope` | All companies or an explicit bounded set |
| `sensitiveScopes` | Separate payroll/salary, security, billing, lifecycle grants |
| `effectiveFrom`, `expiresAt`, `revokedAt` | Effective authorization window |
| `reason`, `approvedBy` | Required governance evidence |
| `version` | Conflict token |

Grant revocation increments the person's access revision so cached company
contexts become stale.

More than one active `general_hr` grant may exist. Grants are independent:
revoking or changing one grant never changes another recipient's grant. A
person with several grants receives the union of only their currently effective
capabilities within the intersection of each grant's company and sensitive-data
scope.

## Cross-Company Manager Delegation

This platform-governed relationship permits one person to supervise selected
company memberships without joining company organization trees together.

| Field | Rule |
|---|---|
| `id`, `managerUid` | Stable delegation identity and authenticated manager |
| `companyId` | Exactly one target company per delegation row |
| `managerMembershipId` | Active membership in the target company when company policy requires it |
| `employeeMembershipIds`, `organizationUnitIds` | Explicit bounded target scope; server-expanded projections remain bounded |
| `capabilities` | Managed actions such as team view, request decision, task review, or attendance review |
| `sensitiveScopes` | Salary/payroll access remains absent unless separately granted |
| `effectiveFrom`, `expiresAt`, `revokedAt` | Effective authorization window |
| `reason`, `approvedBy`, `version` | Governance, audit, and conflict evidence |

The same manager can hold rows for several companies. Consolidated manager
views use safe company-labelled projections; opening or mutating an item
resolves its single `companyId` and revalidates the corresponding row.

## Global Department

A platform-owned shared-services group. It is not inserted into any company's
organization tree and does not itself own company employee records.

| Field | Rule |
|---|---|
| `id`, `code`, `displayName` | Stable identity; code unique among active and archived global departments |
| `kind` | Managed shared-service category such as `accounting`, `hr`, `legal`, `it`, or `custom` |
| `state` | `draft`, `active`, `suspended`, or `archived` |
| `companyScope` | All companies or explicit permitted company IDs |
| `requestTypeScope` | Explicit permitted request categories/types; no implicit all-request access |
| `decisionPolicy` | `first_valid_decision`; later policies require a reviewed model revision |
| `version` | Optimistic conflict token |
| audit fields | creator, updater, reason, timestamps |

An active department must have at least one effective member with the required
decision capability before it can be published into an approval chain.

## Global Department Membership

| Field | Rule |
|---|---|
| `id`, `globalDepartmentId`, `uid` | Stable membership identity |
| `capabilities` | Explicit abilities such as `request_view_summary` and `request_decide` |
| `companyScope`, `requestTypeScope` | May narrow but never broaden the department scope |
| `effectiveFrom`, `expiresAt`, `revokedAt` | Effective authorization window |
| `reason`, `approvedBy`, `version` | Governance and conflict evidence |

Membership does not grant general company browsing, employee management,
salary, payroll, or document access. A request projection returns only fields
needed for the permitted decision.

## Materialized Approval Step

| Field | Rule |
|---|---|
| `id`, `companyId`, `requestId`, `sequence` | Stable company-owned step identity |
| `targetType`, `targetId` | Named actor, company pool, manager delegation, or global department pool |
| `policyVersion`, `targetVersion` | Immutable request-time routing evidence |
| `eligibleActorUids` | Bounded immutable snapshot produced at submission |
| `state` | `waiting`, `actionable`, `approved`, `rejected`, `blocked`, or `cancelled` |
| `decisionActorUid`, `decisionAuthority` | Actual person and membership/grant used |
| `decisionAt`, `decisionReason` | Server-time outcome evidence |
| `operationReceiptId`, `version` | Idempotency and atomic concurrency control |

For `global_department_pool`, all eligible members can see the company-labelled
decision item. The first valid decision atomically moves the single step and
request workflow. Later attempts return the committed outcome. Eligibility is
snapshotted for audit and revalidated for active state/capability at decision
time; it is never recomputed to silently add new approvers to an in-flight
request.

## Company Leadership Assignment

| Field | Rule |
|---|---|
| `id`, `companyId`, `uid` | Stable company-scoped assignment |
| `kind` | `ceo` or `company_hr` |
| `effectiveFrom`, `effectiveTo`, `state` | Active responsibility window |
| `membershipId` | Must resolve to an eligible company membership |
| audit fields | appointing actor, reason, timestamps |

An active company must retain at least one active assignment of each mandatory
kind. Removal operations validate the post-change state atomically.

## User Company Access Projection

A server-owned projection used only for bounded company selection:

| Field | Rule |
|---|---|
| `uid`, `companyId`, `membershipId` | Projection key |
| `companyStatus`, `membershipState` | Safe current access state |
| `displayName`, `logoThumbDescriptor`, `primaryColor` | Safe picker branding |
| `effectiveRoleLabel` | Safe UI label, not an authority source |
| `accessRevision`, `brandingVersion` | Cache invalidation tokens |
| `lastUsedAt` | Person-private preference |

The projection is not accepted as proof of authorization for business actions.
Cross-company manager delegations may add a safe `managedScope` indicator to
this projection, but never raw employee or salary data.

## Company Context Receipt

Short-lived domain value returned after authorization:

- authenticated `uid`;
- `companyId` and company lifecycle state;
- membership ID/revision when access comes from membership;
- platform grant IDs/revisions when access comes from global authority;
- resolved capabilities and sensitive scopes;
- branding, policy, and entitlement revisions;
- issue/expiry time and overall access revision.

The receipt can optimize repeated work but every sensitive mutation revalidates
revocation and target ownership.

## Feature Entitlement

| Field | Rule |
|---|---|
| `companyId`, `featureKey` | Unique company-feature pair |
| `state` | `enabled`, `disabled`, `pilot`, `suspended` |
| `limits` | Bounded feature-specific limits without role authority |
| `effectiveFrom`, `expiresAt` | Availability window |
| `version`, audit fields | Concurrency and governance |

An entitlement permits product availability; company membership capabilities
still decide who may use it.

## Company Policy Set

Versioned references to company-specific attendance, payroll, request,
notification, workweek, location, and retention policies. Historical business
records retain the effective policy version or the evidence needed to reproduce
their decision. Changing the current policy never rewrites closed history.

## Tenant Operation Receipt

| Field | Rule |
|---|---|
| `companyId`, `operationId` | Composite idempotency identity |
| `actorUid`, `authoritySource` | Actual actor and membership/platform grant |
| `operationType`, `targetType`, `targetId` | Stable intent identity |
| `payloadHash` | Same ID with different intent is a conflict |
| `status`, `result` | Confirmed semantic outcome |
| `createdAt` | Server time |

Cross-company replay of an operation ID cannot return or mutate another
company's receipt.

## Tenant Audit Event

Append-only evidence containing company ID (or explicit platform-global scope),
actor UID, authority source, action, target, safe before/after summary, result,
operation ID, server time, and correlation reference. Company-visible and
global indexes contain only fields authorized for those audiences.

## Tenant Health Projection

Safe control-plane summary containing company lifecycle, configuration
completeness, leadership coverage, last successful scheduled runs, migration
state, bounded issue counts, and data freshness. It contains no salary, message
body, attachment content, or raw employee record.

## Global Operations Projection

A versioned, company-labelled control-plane summary that gives Platform Super
Admin and Global HR complete visibility without copying raw company records.

| Field | Rule |
|---|---|
| `companyId`, `periodKey`, `version` | Stable company/period identity and freshness token |
| `workforce` | Active/inactive totals and organization-change signals |
| `attendance` | Present, late, absent, permission, leave, mission, no-check-in totals and trends |
| `requests` | Pending/resolved counts, aging, categories, and responsible-stage summaries |
| `payroll` | Cycle state plus authorized salary/deduction totals and exception counts |
| `performance` | Performance, productivity, task state, and overdue signals |
| `operations` | Failed jobs, integrations, notifications, configuration, and migration alerts |
| `sourceWatermarks` | Canonical source revisions/timestamps used for reconciliation |

Fields are returned according to the actor's global role. Platform Super Admin
can access every projection and canonical drill-down. Global HR can access all
HR fields, including salary/payroll/deductions, for every company in scope.
Private message content, credentials, developer settings, billing, security
administration, and company-lifecycle mutations remain separately authorized.
Canonical details stay company-owned and are queried through a server-resolved
company context.

## Federated Organization Node

Represents one node in either the platform-owned global/shared-services tree or
one company's independent organization tree.

- stable node ID, owner type (`platform` or `company`), and company ID when
  company-owned;
- node type: global unit, legal entity, branch, department, team, or position;
- parent ID, display order, lifecycle, effective dates, version, and audit;
- job family/title references for positions and optional audited local label;
- search-safe normalized Arabic/English tokens;
- validation receipt proving the published revision has no cycle, orphan,
  cross-owner parent, or ambiguous active primary placement.

The federated tree is an authorized projection of independently owned nodes.
Changing a displayed parent never transfers record ownership between companies.

## Job Family and Job Title

Platform-owned stable taxonomy for classification, reporting, and routing.
Company overrides may change an approved local display label, grade mapping, or
policy reference, but retain the global identifier, source version, effective
dates, and audit. Search projections index both authorized global and local
labels.

## Reporting Relationship and Placement

- relationship ID, company membership, position, and company;
- type: `primary`, `functional`, `dotted_line`, or `delegated_cross_company`;
- manager person/membership or governed manager scope;
- permitted management/decision capabilities and sensitive fields;
- effective dates, source policy/delegation, version, and audit.

A company membership has at most one active primary placement. Additional
relationships never imply salary, export, approval, or company-administration
authority. Graph validation rejects active reporting cycles. Open workflow
routing stores a materialized organization/policy version and is unaffected by
later edits.

## Module Governance Policy

Versioned policy for one module and scope, with independent capability sets for
`view`, `sensitive_view`, `manage`, `decide`, and `export`. It also identifies:

- allowed companies, organization scopes, request/resource categories, fields,
  and effective dates;
- self-approval and incompatible-duty rules;
- stages that require different actors or dual control;
- retention, audit, notification, offline/cache, and export policy references;
- publication validation and access-revision invalidation metadata.

## Global Search Projection and Saved View

The server-owned search projection contains only authorized, presentation-safe
fields and normalized Arabic/English tokens. Each item includes company origin,
module, stable target ID, freshness/version, and server-calculated allowed
actions. Queries use whitelisted filters, stable sort keys, bounded page size,
and cursors bound to actor access revision plus query/sort hash.

A saved view belongs to one actor and stores module, filters, sort, columns, and
optional default company scope. It stores no authority. Opening it recomputes
accessible companies, fields, totals, facets, and actions; revoked content is
omitted without revealing its existence.

## Module Coverage Registry

One row per live module records:

- ownership class and canonical company/global boundary;
- read, sensitive-read, manage, decide, and export policies;
- search/filter/sort contract and required indexes;
- notification/deep-link and offline/cache namespace behavior;
- reporting/export, retention, audit, migration, and rollback owners;
- isolation, parity, authorization, and read-budget evidence status.

Activation validation fails when an enabled module lacks a complete, reviewed
row or its required evidence.

## Migration Batch and Item

### Migration Batch

- stable ID, source model version, target company, included business areas;
- `previewed`, `approved`, `applying`, `paused`, `reconciling`, `complete`, or
  `rolled_back_route` state;
- counts by assignable/already-owned/ambiguous/invalid/blocked/applied;
- cursor/checkpoint, policy version, actor, timestamps, reconciliation hash.

### Migration Item

- batch, source collection/path hash and record identity;
- proposed company and evidence used;
- classification and blocking reason;
- before ownership, after ownership, operation receipt, and reconciliation result.

Migration items never copy sensitive payloads into reports. Apply is resumable
and idempotent; route rollback does not remove already proven ownership.

## Legacy compatibility mapping

| Current concept | Transitional mapping | Target concept |
|---|---|---|
| `users/{uid}.role` | preserved for legacy reads; derived compatibility projection | Company membership role or platform grant |
| hard-coded `companyId = zawolf` | explicit first-company context | Authorized active company context |
| top-level company-owned collection | immutable indexed `companyId` field | Company-owned aggregate/path |
| global operation receipt ID | compatibility lookup with first company | `(companyId, operationId)` receipt |
| global notification recipient role | company-scoped recipient policy | Company notification routing projection |
| one local cache namespace | read-only during transition | `(uid, companyId)` namespace |

Compatibility ends per slice only after parity, migration reconciliation,
tenant rules, and rollback evidence are accepted.
