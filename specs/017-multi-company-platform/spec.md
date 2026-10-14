# Feature Specification: 7DHUB Multi-Company Platform

**Feature Branch**: `017-multi-company-platform`

**Created**: 2026-10-10

**Status**: Approved by owner for task generation on 2026-10-10; implementation requires task-list approval

**Input**: Rebrand the product as 7DHUB HR and allow globally authorized management to create and operate multiple isolated companies. Each company has its own identity, branding, leadership, HR administrators, employees, organization, configuration, and business records while remaining governed through a global platform layer.

## User Scenarios & Testing

### User Story 1 - Create and activate a company (Priority: P1)

A Platform Super Admin creates a company, enters its identity and operating
settings, uploads approved branding, selects enabled features, and assigns at
least one company CEO and HR administrator. The company remains a draft until
all mandatory setup checks pass and the administrator explicitly activates it.

**Why this priority**: A safe company lifecycle and bootstrap process are the
foundation for every other multi-company capability.

**Independent Test**: Create a draft company with a unique code, logo, colors,
timezone, currency, workweek, CEO, and two HR administrators; resolve all setup
warnings, activate it, and verify that its users can enter only that company.

**Acceptance Scenarios**:

1. **Given** a Platform Super Admin, **When** they create a company with a
   unique code and required identity fields, **Then** the company is saved as a
   draft and no employee can use it until activation.
2. **Given** an incomplete company without an active CEO or HR administrator,
   **When** activation is requested, **Then** activation is denied with a list
   of missing requirements.
3. **Given** a complete draft company, **When** the Platform Super Admin reviews
   the setup summary and activates it, **Then** assigned administrators can
   enter its dashboard and all actions are company-scoped.
4. **Given** an active company with historical records, **When** suspension or
   archive is requested, **Then** the system displays impact, requires a reason,
   blocks ordinary company access as configured, and preserves history.

---

### User Story 2 - Govern all companies globally (Priority: P1)

Platform Super Admins and authorized General HR users use a global management
area to find companies, review operational status, manage permitted company
settings and assignments, and enter an explicit company context. Global access
is capability-based, visible, and audited.

**Why this priority**: The product must remain centrally governed without
allowing company-level roles to escape their own company boundary.

**Independent Test**: Sign in as Platform Super Admin, General HR, and Company
HR; verify that the first two receive their different global capabilities while
Company HR can access only their company and cannot enumerate other companies.

**Acceptance Scenarios**:

1. **Given** a Platform Super Admin, **When** they open global management,
   **Then** they can view all companies, lifecycle states, assigned leadership,
   feature availability, and safe operational health summaries.
2. **Given** a General HR user, **When** they open global management, **Then**
   they can see complete HR operations for every company in their global scope,
   including employee records, attendance, requests, approvals, salary,
   payroll, deductions, performance, tasks, reports, and HR files; mutation,
   platform security, billing, developer, and company-lifecycle controls remain
   separately authorized.
3. **Given** two or more General HR users, **When** their grants overlap or
   differ by company and capability, **Then** each user receives only their own
   effective scope and changing one grant does not change another user's access.
4. **Given** a global administrator enters a company, **When** they perform an
   action, **Then** the active company and global authority are displayed and
   recorded in the audit history.
5. **Given** a company CEO, HR administrator, manager, or employee without an
   effective membership or delegation, **When** they attempt to list or access
   another company, **Then** access is denied without revealing that company's
   protected data.
6. **Given** a manager is explicitly assigned employees in more than one
   company, **When** they open their managed-company or decision inbox, **Then**
   they see only those assigned employees and permitted work, every item shows
   its company, and any action is authorized inside that item's company scope.
7. **Given** a global administrator needs support access, **When** they enter a
   company context, **Then** they act as themselves with their granted global
   capability; the platform does not silently impersonate a company user.
8. **Given** a Platform Super Admin configures a Global Accounting, Global HR,
   Legal, or other shared-services department, **When** eligible people are
   assigned to it, **Then** the department is available as a clearly labelled
   global approval target only for permitted companies and request types.
9. **Given** an authorized global user, **When** they search, filter, or sort by
   company, employee name/code, department, job title, request status, actor, or
   date, **Then** results are bounded, company-labelled, stable across pages,
   and contain no unauthorized result, count, facet, or action.
10. **Given** a Global HR user can view a request but has no decision grant,
    **When** they open or attempt to approve it, **Then** the interface shows a
    read-only state and the trusted endpoint denies the decision with an audit
    outcome.
11. **Given** the platform and two companies have global units, branches,
    departments, teams, positions, and reporting lines, **When** an authorized
    administrator opens the organization view, **Then** one federated tree is
    rendered with clear ownership while each company's structure stays isolated.
12. **Given** a live module is enabled for a second company, **When** readiness
    is evaluated, **Then** activation is blocked unless ownership, permissions,
    search, notifications, audit, cache, reports, retention, and automated
    isolation/parity evidence are complete for that module.

---

### User Story 3 - Join and switch company context (Priority: P1)

A person keeps one sign-in identity and receives one or more company
memberships. After authentication, the person enters their only company
automatically or selects among permitted companies. Every screen, query,
notification, upload, report, and action uses exactly one explicit company
context unless it is a declared global-management operation.

**Why this priority**: Deterministic company context prevents accidental data
mixing and supports executives or global staff who legitimately work across
companies.

**Independent Test**: Give one account memberships in two companies, switch
between them, and verify that branding, role, navigation, data, notifications,
and cached content change together without exposing records from the prior
company.

**Acceptance Scenarios**:

1. **Given** a person with one active membership, **When** they sign in, **Then**
   that company is selected and its allowed experience is loaded.
2. **Given** a person with multiple active memberships, **When** they sign in,
   **Then** they select a company or resume a still-valid prior selection.
3. **Given** an active company context, **When** the person switches companies,
   **Then** all company-scoped data, permissions, navigation, branding, local
   cache, pending operations, and notification routing switch consistently.
4. **Given** a membership that was suspended or revoked, **When** the person
   attempts to resume it from a saved session or link, **Then** access is denied
   and another valid context can be selected.
5. **Given** the same email address is invited by another company, **When** the
   invitation is accepted, **Then** a new membership is attached to the same
   person rather than creating a conflicting identity.

---

### User Story 4 - Experience company branding inside 7DHUB HR (Priority: P2)

After company selection, users see the company's approved name, logo, colors,
and relevant contact identity throughout the application, web dashboard,
reports, exports, and company communications. The distributable application
retains the 7DHUB HR store identity and safe fallback branding.

**Why this priority**: Company identity should feel native to each workforce
without requiring a new mobile release whenever a company is created.

**Independent Test**: Update a pilot company's approved branding and verify it
appears consistently after refresh on mobile and web, while another company's
branding and the installed 7DHUB HR identity remain unchanged.

**Acceptance Scenarios**:

1. **Given** valid company branding, **When** a member enters that company,
   **Then** the in-app/web logo, company name, theme colors, reports, exports,
   and company-authored communications use that branding.
2. **Given** missing, invalid, inaccessible, or unapproved branding, **When**
   the company experience loads, **Then** accessible 7DHUB HR fallback branding
   appears and the user can continue safely.
3. **Given** a branding update, **When** it is published, **Then** active users
   receive it within a bounded refresh period without mixing it into another
   company or requiring a mobile-store release.
4. **Given** the application is installed, **When** the user has not signed in
   or changes company, **Then** the store listing and default installed identity
   remain 7DHUB HR. Any optional Home Screen icon is limited to an icon included
   in an approved application release and is not required for tenant branding.
5. **Given** a color selection with insufficient readability, **When** branding
   is reviewed, **Then** publication is blocked or corrected to an accessible
   equivalent with an explanation.

---

### User Story 5 - Operate HR independently within each company (Priority: P1)

Company administrators configure their organization, employees, work policies,
locations, request types, approval chains, attendance, payroll, chat, tasks,
reports, files, and notifications without affecting another company. Existing
organization trees belong to one company and cannot span company boundaries.

**Why this priority**: Visual company separation has no value unless all
business behavior and records are isolated.

**Independent Test**: Create equivalent departments, employee codes, request
types, and payroll periods in two companies and verify that they operate
independently with no collisions or cross-company search results.

**Acceptance Scenarios**:

1. **Given** two active companies, **When** each uses the same employee code,
   department name, location name, or request label, **Then** both are valid and
   remain distinguishable by company.
2. **Given** a company HR administrator, **When** they manage employees or
   policies, **Then** every read, write, search, export, and aggregate is limited
   to that company.
3. **Given** a request, attendance event, deduction, payroll item, chat message,
   task, file, or notification, **When** it is created or processed, **Then** it
   retains immutable company ownership through its lifecycle.
4. **Given** an approval chain, scheduled job, reminder, or reconciliation,
   **When** it runs, **Then** it resolves company-specific policies, time,
   recipients, and idempotency without crossing company boundaries.
5. **Given** a company membership transfer or termination, **When** it becomes
   effective, **Then** that company's history remains intact and memberships in
   other companies are unaffected.

---

### User Story 6 - Migrate the current organization safely (Priority: P1)

The existing ZaWolf organization becomes the first company in 7DHUB HR without
losing account access, history, approvals, payroll, attendance, chats, files,
or scheduled behavior. Migration is previewed, reversible during rollout, and
does not silently assign records with uncertain ownership.

**Why this priority**: The platform cannot launch safely if existing production
data is mixed with new companies or current workflows are disrupted.

**Independent Test**: Run a complete non-production migration preview and
apply it to a representative copy; reconcile counts and relationships across
all business areas, test rollback routing, and verify unchanged current-company
results before adding a second pilot company.

**Acceptance Scenarios**:

1. **Given** current production-shaped data, **When** a migration preview runs,
   **Then** it reports assignable, already assigned, ambiguous, invalid, and
   blocked records by business area without changing data.
2. **Given** unresolved ambiguous ownership, **When** migration apply is
   requested, **Then** affected records remain blocked for resolution rather
   than being assigned by guesswork.
3. **Given** an approved migration batch, **When** it is retried, **Then** it
   produces the same company ownership and audit result without duplicates.
4. **Given** migration is active but the new route is disabled, **When** users
   continue normal work, **Then** the existing single-company behavior remains
   available until parity and acceptance are approved.

### Edge Cases

- A company code, legal identifier, domain, or display name conflicts with an
  existing active or archived company.
- The final CEO or HR administrator is deactivated, removed, or transferred.
- One person is a company employee, a CEO elsewhere, and a General HR user at
  platform level.
- More than one person holds General HR grants with different company,
  capability, effective-date, or sensitive-data scopes.
- A manager supervises selected employees in several companies, loses one
  assignment while an approval is open, or has different management
  capabilities in each company.
- A company approval chain targets a global shared-services department whose
  members work in different companies, one member is also the requester, or
  two eligible members try to decide the same step simultaneously.
- A global approval department has no eligible active decision maker when a
  chain is published or when a request reaches its step.
- A global role is revoked while its holder has a company screen open or an
  operation pending.
- A deep link, push notification, browser tab, or cached route refers to a
  company different from the active context.
- A local offline operation is queued for company A and the user switches to
  company B before synchronization.
- A scheduled job starts while a company is suspended or its policy version is
  changing.
- A company changes timezone, currency, workweek, or payroll-cycle policy after
  historical records exist.
- Company branding is oversized, transparent, animated, unreadable, malicious,
  or deleted while cached on a device.
- A person is invited with an email that already belongs to an inactive account
  or an account controlled by another company membership.
- A company is suspended while employees are checked in, uploads are active,
  approvals are pending, or payroll is open.
- The current company contains records without a resolvable employee, manager,
  department, or company owner.
- Arabic and English searches contain spelling variants, diacritics, whitespace,
  or duplicate employee names and codes across different companies.
- A global user can view a request or employee but has no authority to manage,
  approve, export, or view its sensitive fields.
- The requester is also a member of the department approval pool, one person is
  selected for two consecutive approval stages, or two incompatible duties are
  granted to the same person.
- A department, position, manager relationship, or company is reorganized while
  a request, meeting, task, attendance correction, or payroll cycle is open.
- An organizational edit introduces a cycle, an orphaned position, multiple
  primary managers, or a membership without one valid primary placement.
- A saved global view contains a company, field, or action whose permission is
  later revoked, or its cursor is reused after filters or sort order change.

## Requirements

### Functional Requirements

- **FR-001**: The product MUST use **7DHUB HR** as its shared platform, mobile
  application, installed default, and store identity.
- **FR-002**: The system MUST represent every company with a stable unique
  identity, lifecycle state, legal/display information, operating locale,
  timezone, currency, workweek, contact information, branding, enabled-feature
  policy, version, and audit metadata.
- **FR-003**: Only a Platform Super Admin with the company-lifecycle capability
  MAY create, activate, suspend, restore, or archive a company.
- **FR-004**: Company activation MUST require a complete setup review including
  unique identity, valid operating settings, at least one active CEO, at least
  one active Company HR administrator, and accepted branding fallback.
- **FR-005**: Company suspension and archive MUST be reversible where legally
  and operationally possible, preserve historical records, require an impact
  preview and reason, and never silently delete business data.
- **FR-006**: The system MUST distinguish platform roles from company roles.
  Platform authority MUST NOT be inferred from a company title, employee code,
  email domain, CEO assignment, or client-provided role label.
- **FR-007**: Platform Super Admin MUST have complete cross-company read and
  management visibility over company configuration, employees, attendance,
  requests, approvals, payroll, salary, deductions, performance, tasks,
  reports, files, operational health, integrations, and audit. Every drill-down
  and mutation MUST retain an explicit target company and actual-actor audit;
  this authority MUST NOT be implemented as silent impersonation.
- **FR-008**: General HR MUST support globally managed HR capabilities across
  permitted companies and MUST support multiple concurrent General HR grant
  holders. Within the grant's company scope, General HR MUST receive complete
  read visibility of HR operations, including employee profiles, organization,
  attendance, leave, permissions, requests, approval history, payroll, salary,
  deductions, performance, tasks, HR reports, and HR files. Write/decision
  powers and access to platform security, billing, company lifecycle, developer
  configuration, credentials, or private direct-message content MUST remain
  separately granted. Each holder's scope, effective dates, and mutation
  capabilities MUST be evaluated independently.
- **FR-009**: Global users MUST act under their own identity and authority. The
  platform MUST NOT provide silent impersonation; any support or delegated
  company access MUST show the active company and record actor, authority,
  reason where required, time, and affected resource.
- **FR-010**: One person MUST have one authentication identity and MAY hold
  multiple effective-dated company memberships and platform role grants.
- **FR-011**: Each company membership MUST define company role, employment
  state, effective dates, employee code within that company, and permitted
  organization placement without changing memberships in another company.
- **FR-012**: Every non-global session and operation MUST have exactly one
  explicit active company context. Missing, inactive, revoked, or mismatched
  company context MUST fail closed.
- **FR-013**: Switching company MUST atomically switch visible authorization,
  branding, navigation, query scope, cache namespace, pending-operation
  namespace, files, notifications, and analytics context.
- **FR-014**: Every company-owned record and derived projection MUST retain
  immutable company ownership. Record IDs, employee codes, names, or client
  filters alone MUST NOT establish company scope.
- **FR-015**: Company-level users MUST read and mutate only data authorized for
  their active company and role. Out-of-company access MUST be denied at every
  trusted boundary and must not disclose protected existence or metadata.
- **FR-016**: Global searches, dashboards, reports, and exports MUST require a
  platform capability, clearly label company origin, support explicit company
  filters, use bounded results, and exclude fields beyond the user's grants.
- **FR-016A**: Platform Super Admin and General HR MUST receive a global
  operations view with all-company totals, exceptions, pending approvals,
  attendance conditions, workforce changes, payroll/deduction status,
  performance/task signals, and alerts. They MUST be able to filter by company,
  department, employee, category, status, and period and drill into the exact
  authorized company record without losing company origin.
- **FR-017**: Company creation MUST support assigning one or more active CEOs
  and Company HR administrators, inviting or attaching existing identities,
  and validating that mandatory leadership remains available.
- **FR-018**: Each company's departments, organization trees, managers,
  locations, schedules, policies, request types, approval chains, attendance,
  payroll, deductions, tasks, chats, files, reports, and notifications MUST be
  independently configurable and company-scoped.
- **FR-019**: An organization tree and its memberships MUST belong to exactly
  one company. A manager MAY supervise employees in multiple companies only
  through effective company memberships or an explicit platform-governed
  cross-company manager delegation that identifies the manager, each target
  company, assigned employee/team scope, permitted management actions, and
  effective dates. Such a delegation MUST NOT merge organization trees or
  imply access to unassigned employees, salary, payroll, security, or company
  administration.
- **FR-019A**: A cross-company manager MAY receive a bounded consolidated inbox
  or summary containing only delegated work with visible company origin. Reads
  and mutations of the underlying employee, request, attendance, task, or
  performance record MUST resolve and audit exactly one company context.
- **FR-020**: Requests and approvals MUST materialize company-scoped approver
  identities and policy versions. Later company, role, or organization changes
  MUST NOT rewrite completed or in-flight approval evidence.
- **FR-020A**: Platform management MUST support global shared-services
  departments, such as Global Accounting, Global HR, Legal, or IT, independently
  from every company's organization tree. Each global department MUST have a
  stable identity, allowed company/request scope, effective-dated members,
  member capabilities, lifecycle state, version, and audit history.
- **FR-020B**: A company request approval chain MAY target a company approver,
  company department pool, named person, cross-company manager delegation, or
  global department pool. The approval-chain editor and request history MUST
  visibly distinguish a global department from a similarly named company
  department.
- **FR-020C**: When a request containing a global department step is submitted,
  the system MUST materialize the department ID, policy version, request
  company, permitted action, and eligible-member snapshot. Only a member in
  that snapshot who remains active and retains the decision capability MAY act;
  requester/self-approval and separation-of-duty rules continue to apply.
- **FR-020D**: A global department pool represents exactly one approval step.
  The first valid approve or reject decision MUST resolve it atomically on
  behalf of the department, record the actual actor and authority, and cause
  concurrent or repeated decisions to return the existing result without a
  duplicate transition. The system MUST notify or clear the remaining eligible
  members appropriately after resolution.
- **FR-020E**: Publishing an approval chain MUST fail with a clear configuration
  error when a referenced global department is inactive, outside the permitted
  company/request scope, or has no eligible decision maker. If eligibility is
  lost after submission, the request MUST enter a visible blocked/escalation
  state rather than silently skipping the step or granting access.
- **FR-021**: Attendance, leave, permission, absence, deduction, and payroll
  behavior MUST use the company's effective policy and timezone while
  preserving established execution-date, approval-date, cycle, idempotency,
  and historical semantics.
- **FR-022**: Scheduled jobs, reminders, notifications, reconciliations,
  imports, exports, attachment handling, and integrations MUST resolve and
  preserve company scope and MUST not use an unscoped global employee scan.
- **FR-023**: A notification or deep link MUST include safe company context,
  verify current membership before opening, and never open a same-ID resource
  belonging to another company.
- **FR-024**: Company branding MUST support approved logo variants, display
  name, primary/accent colors, and accessible fallback behavior across mobile,
  web, reports, exports, and company-authored communications.
- **FR-024A**: The initial bundled platform brand MUST use the owner-approved
  **7DHUB HR** name and assets derived from the official `https://7dhub.co/`
  website. The source asset, checksum, palette, transformation, and approval
  date MUST be recorded; the application MUST bundle reviewed copies rather
  than depend on the live website at runtime.
- **FR-025**: Branding publication MUST validate asset type and size, readable
  contrast, safe display name, version, and audit details. Invalid or unavailable
  branding MUST fall back to 7DHUB HR without blocking core work.
- **FR-026**: Dynamic tenant branding MUST NOT promise arbitrary post-install
  changes to the iOS application label or to a mobile Home Screen icon that was
  not packaged in an approved release. The product MUST explain this boundary
  wherever launcher branding is configured.
- **FR-027**: The web application MAY reflect the active company in its visible
  title and icon after authentication, while signed-out and shared entry points
  retain 7DHUB HR identity.
- **FR-028**: Every platform or company mutation MUST be authorized, versioned,
  idempotent where retryable, and represented by an append-only audit event with
  actor, authority source, company, operation, target, result, and safe change
  summary.
- **FR-029**: Security-sensitive global access, company lifecycle actions,
  role/capability changes, exports, payroll access, and support access MUST be
  discoverable in global audit and company-visible audit where policy permits.
- **FR-030**: Company lists, memberships, employee lists, audit, reports,
  dashboards, and cross-company views MUST use bounded pages and scoped
  summaries; no client may load every company's raw records to calculate a
  dashboard.
- **FR-031**: Company-scoped offline data and pending operations MUST be
  isolated per authenticated identity and company. Switching or signing out
  MUST not display another company's cached content or submit it under the wrong
  company.
- **FR-032**: Conflicting company configuration, membership, policy, or branding
  updates MUST not silently overwrite one another; users MUST receive a clear
  conflict, refresh, retry, or status-check outcome.
- **FR-033**: The existing organization MUST migrate into one initial company
  through a dry run, reconciliation report, resumable/idempotent apply, pilot
  verification, explicit activation, and documented rollback path.
- **FR-034**: Migration MUST cover every user and company-owned business area,
  including organization, policies, attendance, requests, approvals, payroll,
  deductions, tasks, chats, files, notifications, reports, integrations,
  caches, jobs, and audit references. Ambiguous ownership MUST be resolved or
  quarantined before another company is activated.
- **FR-035**: Existing single-company routes and behavior MUST remain available
  behind an independently controlled rollback path until tenant-isolation,
  migration-parity, policy, scheduler, notification, offline, mobile, and web
  acceptance tests pass and the owner approves the switch.
- **FR-036**: New-company creation MUST remain disabled in production until the
  initial-company migration is reconciled and automated cross-company isolation
  tests demonstrate zero unauthorized reads or writes.
- **FR-037**: All user-facing tenant states MUST support Arabic RTL and
  responsive web/mobile layouts, including loading, empty, invitation, company
  selection, denied, suspended, offline, pending-sync, conflict, and retry.
- **FR-038**: Company export, archive, retention, and deletion policy MUST be
  explicit and reviewable. Permanent company or employee data deletion is out
  of scope for the initial release and requires a separately approved policy.
- **FR-039**: Separate dedicated deployments and per-company store applications
  are outside the initial shared-platform release; the company model MUST not
  prevent these enterprise options from being introduced later.
- **FR-040**: Platform management MUST include a company registry, company
  lifecycle controls, global role/capability management, tenant health summary,
  feature entitlement management, migration status, and cross-company audit.
- **FR-041**: Global management lists MUST provide bounded server-side search,
  filtering, stable sorting, cursor pagination, and access-revalidated saved
  views. Supported search MUST normalize Arabic and English text and match
  authorized company name/code, employee name/code/email, organization unit,
  job family/title, request type, status, approver, and date fields without
  disclosing the existence or count of unauthorized results.
- **FR-042**: Authorization MUST evaluate `view`, `sensitive_view`, `manage`,
  `decide`, and `export` independently for every platform and company module.
  Visibility MUST NOT imply mutation or approval authority. Platform Super
  Admin and General HR MAY make business decisions only when an explicit,
  effective decision grant or materialized approval target permits the action.
- **FR-043**: Approval governance MUST prevent self-approval, incompatible-duty
  conflicts, repeated use of the same actor in stages that require separation,
  duplicate decisions, and decisions outside the actor's company/request scope.
  Configurable dual control MUST require distinct actors. The server MUST return
  the actor's allowed actions with each actionable result, while remaining the
  authority for every decision.
- **FR-044**: The platform MUST provide a federated organizational and job
  structure with the hierarchy `7DHUB platform -> global management/shared
  services -> company -> legal entity/branch -> department -> team -> position
  -> membership`. Global and company trees remain independently owned but MAY
  be rendered together for authorized users. Nodes, positions, reporting lines,
  job families/titles, and primary/functional managers MUST be effective-dated,
  versioned, auditable, cycle-free, and usable by deterministic routing.
- **FR-045**: A person MUST have at most one active primary placement per
  company membership and MAY have additional effective functional or
  cross-company reporting relationships. Positions MAY be vacant. A shared
  global job catalog MAY define job families and titles, while a company MAY
  apply an audited local display name or policy override without changing the
  global identity or another company's structure.
- **FR-046**: Tenant readiness MUST be proven for every live module, including
  notifications, chat and media, requests and approvals, meetings, reports and
  exports, records/files/workspace, Company Services and Support, employee and
  request management, rewards/warnings, leave and permissions, attendance,
  locations/branches, payroll/deductions, tasks/productivity, hiring,
  resignation, and configurable tools. Each module MUST define ownership,
  global/company visibility, allowed actions and approvals, search/filter/sort,
  notifications/deep links, audit, offline/cache behavior, reporting/export,
  retention, and automated isolation/parity evidence before activation.

### Key Entities

- **Company**: The isolated business tenant, its identity, lifecycle, operating
  defaults, leadership requirements, and enabled capabilities.
- **Company Branding Profile**: Versioned approved company name, logo variants,
  colors, accessibility result, publication state, and 7DHUB fallback.
- **Person Identity**: A single sign-in identity that may be linked to multiple
  company memberships and platform grants.
- **Company Membership**: Effective-dated relationship between a person and a
  company, including company-specific employee code, role, status, and
  organization placement.
- **Platform Role Grant**: Effective-dated global capability assignment such as
  Platform Super Admin or General HR, independent of company membership.
- **Global Department**: Platform-owned shared-services group, separate from
  company organization trees, whose eligible members may collectively own a
  bounded approval step for permitted company requests.
- **Global Department Membership**: Effective-dated relationship granting a
  person specific capabilities in one global department without automatically
  exposing all companies or sensitive employee data.
- **Materialized Approval Step**: Immutable request-time approval evidence
  containing target type, target identity, eligible actor snapshot, policy
  version, company origin, resolution, and actual decision actor.
- **Company Leadership Assignment**: Effective-dated CEO or Company HR
  responsibility required for company activation and operation.
- **Company Context**: The one company selected for a company-scoped session,
  route, cached view, operation, notification, or report.
- **Feature Entitlement**: Platform-managed availability of a product module for
  a company, separate from an individual user's permission.
- **Company Policy Set**: Versioned company-specific operating configuration
  used by attendance, requests, payroll, notifications, and scheduled work.
- **Tenant Audit Event**: Append-only evidence of a global or company-scoped
  action, including company origin and authority source.
- **Migration Batch**: Previewed, resumable, idempotent assignment of existing
  records to the initial company with reconciliation and rollback evidence.
- **Federated Organization Node**: Effective-dated global or company-owned
  legal entity, branch, department, team, or position node with parent,
  lifecycle, ordering, and cycle-validation metadata.
- **Job Family and Job Title**: Stable platform taxonomy with audited,
  company-specific presentation or policy overrides.
- **Reporting Relationship**: Effective primary, functional, or delegated
  relationship between a manager scope and a position/membership, with no
  implied authority beyond its capabilities.
- **Module Governance Policy**: Versioned matrix separating view,
  sensitive-view, manage, decide, and export authority for one module and scope.
- **Global Saved View**: An actor-owned filter/sort/column definition whose
  company and field access is revalidated whenever it is opened.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A Platform Super Admin can create a complete draft company,
  assign leadership, publish branding, and activate it in under 15 minutes when
  required information is available.
- **SC-002**: In the automated role matrix, company-level users complete zero
  unauthorized reads, writes, searches, exports, attachment downloads, or deep
  links across company boundaries.
- **SC-003**: A multi-company user can switch company context and see correct
  branding, navigation, permissions, and cached dashboard data within 5 seconds
  under normal connectivity, with no prior-company content visible.
- **SC-004**: In 100% of tested business workflows, newly created attendance,
  request, approval, payroll, deduction, task, chat, file, notification, and
  audit records retain the correct company ownership through completion and
  retry.
- **SC-005**: The initial-company migration reconciles 100% of in-scope records
  as assigned, intentionally global, or explicitly quarantined before a second
  company is activated; no record is silently guessed.
- **SC-006**: Repeating any supported company creation, membership, policy,
  migration, or lifecycle operation produces one committed result and one
  logical audit outcome without duplicate business effects.
- **SC-007**: Company branding meets defined readability checks on mobile and
  web, and missing branding falls back to 7DHUB HR without preventing sign-in or
  core HR work in 100% of tested failure cases.
- **SC-008**: Global management can display a bounded company registry and
  health summary for at least 100 companies and 10,000 memberships within 10
  seconds under the agreed acceptance environment.
- **SC-009**: Current-company pilot users complete the existing critical
  attendance, request approval, payroll, chat, and reporting journeys with no
  loss of historical evidence before the multi-company route becomes default.
- **SC-010**: Every tested global access, company lifecycle change, capability
  change, export, and payroll-sensitive access is attributable to the actual
  actor, company, authority, time, and outcome in audit history.
- **SC-011**: In concurrency tests for a global department approval pool, 100%
  of requests produce at most one step decision and one downstream transition,
  while every losing retry receives the committed result and actual actor.
- **SC-012**: Platform Super Admin and Global HR can account for 100% of fixture
  companies in global HR totals and drill-downs, with the same authorized
  company-level results and no missing company caused by client-side limits.
- **SC-013**: Across fixtures containing 100 companies and 10,000 memberships,
  authorized Arabic/English global search, filter, sort, and pagination reaches
  a useful first page within 10 seconds and returns zero unauthorized existence,
  count, field, or action leakage.
- **SC-014**: Every inventoried live module has a completed ownership and
  governance row plus passing company-isolation, notification/deep-link, audit,
  and current-company parity evidence before a second company is activated.
- **SC-015**: In approval conflict tests, 100% of self-approval, incompatible
  duty, same-actor separation, stale grant, and concurrent-decision attempts
  produce one deterministic allowed or denied outcome with no duplicate state
  transition.
- **SC-016**: Organization fixtures contain zero cycles, orphaned active
  positions, ambiguous primary placements, or unresolved routing targets; an
  in-flight workflow retains its materialized route after a later reorganization.

## Assumptions

- The initial release uses one shared 7DHUB HR application and shared platform
  with strict logical company isolation; physically dedicated deployments are
  a later enterprise option.
- The current ZaWolf organization becomes the first company and keeps its
  historical records and current user identities.
- One person may legitimately belong to multiple companies, but ordinary work
  always occurs in one explicit company context at a time.
- Platform Super Admin and General HR are global roles. General HR receives
  complete read visibility of HR, salary, payroll, deduction, attendance,
  request, employee, performance, task, report, and HR-file data across its
  company scope. Mutation authority plus platform security, billing, lifecycle,
  developer configuration, credentials, and private-message content remain
  separately controlled.
- The installed mobile label and default launcher icon remain 7DHUB HR. Company
  logos and names change the authenticated experience; optional launcher icons
  require assets packaged in a reviewed mobile release.
- Company codes and employee codes are unique within their stated scope rather
  than globally, unless an external integration requires a separate global key.
- Permanent tenant deletion, automated billing, custom domains, and separate
  white-label store applications are not included in the first release.
- No production data migration, security-rule deployment, company activation,
  or default-route switch occurs without a separate owner-approved execution
  and rollback plan.
