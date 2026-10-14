# Research: 7DHUB Multi-Company Platform

## Decision 1: Shared platform with logical tenant isolation

**Decision**: The first release uses one 7DHUB HR application and a shared
platform control plane, with every company's business data logically isolated
by an authoritative company boundary.

**Rationale**: This preserves one release pipeline, one identity, cross-company
global management, and consistent product updates. It also permits a controlled
migration from the existing application.

**Alternatives considered**: A separate backend/Firebase project for every
company gives stronger physical isolation but fragments authentication,
notifications, reporting, scheduled jobs, support, and deployment. It remains a
future enterprise option. A schema-only theme switch was rejected because it
does not isolate data or authority.

## Decision 2: Separate control plane and company data plane

**Decision**: Company registry, global grants, safe health summaries,
entitlements, migration status, and cross-company audit form the control plane.
Employees' HR records and all operational data stay in the company data plane.

**Rationale**: Global management needs enough information to govern companies
without turning every platform dashboard into a raw cross-company data scan.

**Alternatives considered**: A single undifferentiated global data model was
rejected because company scope becomes optional and difficult to audit.

## Decision 3: One person identity, many company memberships

**Decision**: Authentication identifies a person. Effective-dated memberships
attach that person to one or more companies with company-specific employee
codes, roles, organization placement, and employment state.

**Rationale**: Global HR, executives, consultants, and transferred employees
may legitimately access more than one company. Duplicate authentication
accounts would create identity conflicts and fragmented notification/device
state.

**Alternatives considered**: One login per company was rejected because it
creates duplicate people and poor switching/recovery. One global role field on
the user document was rejected because the same person can hold different roles
in different companies.

## Decision 4: Server-resolved company context

**Decision**: Every company-scoped operation requests one company context. The
trusted server verifies membership/global grant, company lifecycle, resource
ownership, and capability on every request.

**Rationale**: A route parameter, cached selection, custom claim, or submitted
role cannot safely grant company access. Memberships and grants can change
without waiting for a new mobile token or application release.

**Alternatives considered**: Storing all company IDs and roles in identity
token claims was rejected because claims become large/stale and revocation is
not immediate. Client-only filtering was rejected as insecure.

## Decision 5: Capability-scoped global management

**Decision**: Platform Super Admin and General HR are platform grants, separate
from company roles. Platform Super Admin can receive all platform capabilities;
General HR receives managed HR capabilities, while salary/payroll, security,
billing, lifecycle, and developer operations remain separately granted.

**Rationale**: “Global” describes scope, not unlimited access to every sensitive
field. This supports least privilege and auditable responsibility.

**Alternatives considered**: Treating current `super_admin`, CEO, or HR labels
as universal bypasses was rejected because present roles mix company and
platform authority and include hard-coded employee assumptions.

## Decision 6: Hybrid tenant storage during migration

**Decision**: New tenant-native aggregates use company-owned paths. Existing
global collections receive immutable company ownership and mandatory indexed
filters until their vertical slice migrates. Compatibility projections serve
legacy readers temporarily.

**Rationale**: Moving all live attendance, payroll, chat, request, and file data
at once creates unacceptable operational risk. The hybrid model supports
incremental proof and rollback.

**Alternatives considered**: A big-bang path rewrite was rejected. Leaving all
records in global collections permanently was rejected because missing filters
remain too easy and rules/query maintenance becomes fragile.

## Decision 7: 7DHUB is the installed identity; tenant branding is dynamic inside

**Decision**: Store listing, default installed name, and primary launcher icon
become 7DHUB HR. Company branding changes the authenticated mobile/web shell,
reports, exports, and company communications. Optional launcher icons are only
for assets packaged in a reviewed native release.

**Rationale**: Arbitrary tenant logos can be delivered safely as in-app media,
but native launchers do not support arbitrary downloaded identity consistently,
and iOS does not support a dynamically changed app label.

**Alternatives considered**: Separate white-label binaries per company provide
full launcher/store branding but multiply signing, review, notification, and
release work. They remain a later paid option.

## Decision 8: Governed branding media, not Firebase Storage

**Decision**: Branding uses the existing governed, authorized media-provider
pattern with opaque descriptors, validation, checksums, variants, and cache
versions. 7DHUB fallback assets ship with the app.

**Rationale**: This follows the current product constraint against Firebase
Storage and avoids public provider URLs or unreviewed asset replacement.

**Alternatives considered**: Embedding every company logo in the app was
rejected because it requires a store release for each company. Public URLs were
rejected because authorization, deletion, and content validation are weak.

## Decision 9: Company-namespaced offline state

**Decision**: Local caches, media cache, pending operations, subscriptions, and
sync checkpoints use `(authenticated UID, company ID)` as part of their key and
lifecycle. Context switching closes old streams before the new namespace renders.

**Rationale**: Offline data can leak visually or replay mutations into the wrong
company even when remote rules are correct.

**Alternatives considered**: Clearing all cache on every switch is safer than
an unscoped cache but loses offline performance and still fails to model pending
work correctly. A global cache keyed only by resource ID was rejected.

## Decision 10: Tenant-partitioned scheduled work

**Decision**: Live workers enumerate active companies in bounded pages and use
per-company job leases, policy snapshots, deterministic identities, and
checkpoints. Recovery workflows accept explicit tenant scope.

**Rationale**: Current global scans and Cairo-wide defaults cannot support
different company timezones/policies or reliable read budgets.

**Alternatives considered**: One global scan across all employees was rejected
for isolation, cost, and retry reasons. One deployment per tenant was deferred
to the dedicated-environment option.

## Decision 11: Reconcile before activating a second company

**Decision**: The current organization is registered as the first company. All
existing business records are inventoried, dry-run classified, idempotently
assigned, reconciled, and acceptance-tested before production permits a second
company.

**Rationale**: A record without company ownership becomes a data leak or a
business-rule ambiguity as soon as another tenant exists.

**Alternatives considered**: Treating missing `companyId` as the current company
forever was rejected because new mistakes would silently leak into that default.
The fallback may exist only as a time-bounded migration compatibility behavior.

## Decision 12: No silent impersonation

**Decision**: Global administrators enter an explicit company support context
as themselves. Audit records both actor and authority source; sensitive actions
may require a reason.

**Rationale**: Impersonation obscures accountability and can generate messages,
approvals, or payroll actions that appear to belong to another person.

**Alternatives considered**: Full user impersonation was rejected. A later
read-only “view as role” preview may be designed separately but cannot authorize
mutations.

## Decision 13: Multiple General HR users and cross-company managers

**Decision**: The platform supports any governed number of General HR grants.
A manager may supervise employees in several companies through separate
company memberships or explicit, effective-dated cross-company manager
delegations. Company organization trees remain isolated. A consolidated
manager inbox contains bounded company-labelled projections; the underlying
read or mutation always runs within exactly one company context.

**Rationale**: Central HR and matrix management are real platform use cases,
but modelling one global manager field would silently broaden access and could
expose payroll or unrelated employees. Explicit rows make target employees,
allowed actions, effective dates, and revocation auditable.

**Alternatives considered**: A single General HR account was rejected because
it prevents delegation and continuity. Joining organization trees across
companies was rejected because it breaks tenant ownership. Giving every
cross-company manager unrestricted company access was rejected because it
violates least privilege.

## Decision 14: Official 7D HUB website is the baseline brand source

**Decision**: The initial 7DHUB HR bundled identity is prepared from the
owner-approved official website assets at `https://7dhub.co/`. The observed
wordmark uses green and graphite; the website styles use primary greens
`#78AF2B`/`#79B12C`, graphite `#3C4D57`, white `#FFFFFF`, and supporting light
greens `#A3D75B` and `#D4FF99`. Exact app tokens must pass contrast testing and
are captured with source URLs and checksums in `brand-source.md`.

**Rationale**: This gives the shared platform a traceable visual source while
allowing accessible mobile/web tokens. Bundling reviewed assets avoids startup
or branding failure when the marketing website changes or is unavailable.

**Alternatives considered**: Hot-linking website assets at runtime was rejected
because it is unreliable and bypasses release review. Guessing colors from a
screenshot was rejected because the website publishes exact CSS values.

## Decision 15: Global departments are shared-services approval pools

**Decision**: Platform Super Admin can define global departments such as
Accounting, HR, Legal, or IT and assign effective-dated members. A company may
reference an allowed global department in an approval chain. Submission
materializes a bounded eligible-member snapshot; the first valid member
decision atomically approves or rejects the single department step on behalf of
the pool, while recording the actual person and authority.

**Rationale**: Central shared-service teams must approve work across companies
without being copied into every company organization chart or receiving broad
tenant access. A single pool step matches the business meaning of “Accounting
approval” and prevents every accountant from being required to approve.

**Alternatives considered**: Creating a duplicate Accounting department in
each company was rejected because membership and policy drift. Requiring all
department members to approve was rejected because absence or turnover would
block routine work. Recomputing eligible users at decision time was rejected
because it changes an in-flight approval plan without evidence. A client-side
first-writer rule was rejected because concurrent decisions require a trusted
transaction and idempotent receipt.
