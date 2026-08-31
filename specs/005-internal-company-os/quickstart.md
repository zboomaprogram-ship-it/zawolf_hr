# Quickstart: Internal Company OS Acceptance

## Purpose

Prove each disabled-by-default Company OS slice in a non-production Firebase
project and Hostinger-compatible test runtime. Do not enable a production flag,
change Firestore rules, or migrate historical data through this guide.

## Prerequisites

- Test identities: Employee, IT Support, IT Manager, Finance, Manager, Admin,
  Super Admin, inactive employee, and out-of-scope employee.
- A managed Company Owner policy resolving an active test owner; production's
  initial policy will resolve employee code `ceo-100` only at controlled setup.
- Non-production API base URL and Firebase ID tokens.
- Feature flags disabled for users outside the pilot allowlist.

## Required checks

```bash
flutter analyze
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test
(cd scripts && npm test)
```

## Flow A: Employee portal and ticket

1. Enable `company_os_portal_v1` for one employee.
2. Open the portal and verify only the employee's own assets, access, finance
   history, tickets, and published knowledge are visible.
3. Submit a ticket, interrupt connectivity after submit, and retry with the same
   operation ID.
4. Verify one ticket and one audit event exist and the UI shows saved, pending,
   or status-check guidance in Arabic without raw provider text.
5. Verify an out-of-scope employee cannot read the ticket.

## Flow B: IT ticket privacy and lifecycle

1. Assign the ticket as IT Manager to an eligible IT Support user.
2. Add one public comment and one private IT note.
3. Progress through assigned, in progress, waiting, resolved, and closed.
4. Verify the requester sees the public comment and resolution but no private
   note in details, notification, search, export, diagnostics, or API payload.
5. Retry each transition and verify no duplicate history.

## Flow C: Asset and license integrity

1. Create an available test asset and assign it to an employee.
2. Retry the assignment and attempt a concurrent assignment to another user.
3. Verify one active assignment, retained handover evidence, and a safe conflict.
4. Return it, open maintenance, and verify the full history remains.
5. Fill a test license to capacity and verify an additional seat is rejected
   without changing usage or audit counts.

## Flow D: Unified access and cost approval

1. Submit a no-cost access request from the existing request center and verify
   manager -> IT -> provisioned stages in the same request history.
2. Submit each cost category: advance, reimbursement, custody, payment, asset,
   repair, license, and other operational expense.
3. Verify the server-created chain includes manager, relevant specialist,
   Finance, Company Owner, and payment/closure in order.
4. Verify Finance or owner cannot be omitted, skipped, or approved twice.
5. Approve in a later reporting/payroll period and verify the request keeps its
   execution/effective date and does not mutate payroll.

## Flow E: Scoped operations and audit

1. Test every role against dashboard, search, lists, exports, and audit.
2. Verify filters, counts, and pagination agree for 10/25/50/100 pages.
3. Search a ticket ID, asset serial, employee, and software name.
4. Verify unauthorized records are absent rather than client-filtered.
5. Verify every mutation has actor, Cairo time, target, action, and safe change
   summary, with no secrets or private-note text.

## Rollback evidence

For each slice record: flag/audience, build identifier, API version, parity test
result, read/write budget, safe-error counts, pilot accounts, rollback owner,
and the verified legacy route. Default switching is a separate explicit owner
approval after this evidence is complete.

## Slice rollout register

| Slice | Server flag | Initial audience | Legacy fallback | Primary metrics | Rollback owner |
|---|---|---|---|---|---|
| Employee portal | `company_os_portal_v1` | Explicit employee pilot IDs only | Existing employee dashboard and request routes | submit latency, safe-error rate, duplicate operations | Product owner + engineering |
| IT operations | `company_os_it_v1` | Explicit IT Support/IT Manager pilot IDs only | Existing administrative/request tools | ticket SLA, conflicts, assignment retries | Product owner + IT Manager |
| Unified requests | `company_os_requests_v1` | Explicit cross-role pilot IDs only | Existing ZaWolf request center | missing requests, stage latency, notification dedupe | Product owner + Finance + HR |
| Operations | `company_os_operations_v1` | Explicit authorized management pilot IDs only | Existing management dashboards/reports | query reads, response latency, denied-scope attempts | Product owner + engineering |
| Organization structure | `company_os_organization_v1` | Explicit HR/Admin/Super Admin pilot IDs, with read-only active staff | Existing departments and organization-map screen | hierarchy reads, conflicts, vacant managers, routing parity | Product owner + HR + engineering |

For every pilot capture the build ID, API version, actor IDs, start/end time,
authorization matrix result, idempotency result, private-field redaction result,
read/write budget, Arabic safe-error counts, legacy route verification, rollback
test time, incident links, reviewer, and explicit owner decision. Missing or
invalid configuration keeps every flag disabled.

## Scheduler and manual recovery ownership

- Company OS owns no scheduled job; its operations and reports are request-driven.
- The existing notification dispatcher remains the only delivery scheduler.
- The Super Admin owns rollback; engineering owns diagnosis and safe restart.
- Recovery disables only the affected slice, retains the legacy route, reuses
  operation IDs for uncertain writes, and may regenerate read-only reports.

## Non-production acceptance evidence template

Do not place tokens, emails, or production UIDs in this table.

| Build/API | Slice | Test actor | Scope | Auth | Idempotency | Redaction | Max reads | Arabic/RTL | Parity | Rollback seconds | Reviewer/result |
|---|---|---|---|---|---|---|---:|---|---|---:|---|
| _pending_ | _pending_ | _pending_ | _pending_ | _pending_ | _pending_ | _pending_ | _pending_ | _pending_ | _pending_ | _pending_ | _pending_ |

Attach request count, p95 latency, safe-error rate, denied-scope attempts,
Firestore reads, duplicate-operation count, incidents, flag audience, and the
verified fallback route. Use `test/fixtures/company_os_parity_fixtures.dart`.

## Automated non-production acceptance runner

The runner at `scripts/company-os-acceptance.js` exercises the deployed API
without changing production or printing tokens, emails, employee IDs, UIDs, or
raw provider diagnostics. It rejects the known production hosts and any URL
whose hostname does not explicitly contain `test`, `staging`, `nonprod`, `dev`,
or `emulator` (localhost is also accepted).

Create nine non-production Firebase identities and place their current ID
tokens in a local JSON object keyed only by these aliases:

```json
{
  "employee": "ID_TOKEN",
  "it_support": "ID_TOKEN",
  "it_manager": "ID_TOKEN",
  "finance": "ID_TOKEN",
  "manager": "ID_TOKEN",
  "admin": "ID_TOKEN",
  "super_admin": "ID_TOKEN",
  "inactive": "ID_TOKEN",
  "out_of_scope": "ID_TOKEN"
}
```

For the role-matrix run, allowlist every active alias except `out_of_scope` for
all five Company OS flags. The inactive identity must reference an inactive
employee record. The out-of-scope identity must remain outside every flag
audience. Keep the JSON outside the repository and remove it after the run.

Load it without printing the content, then run the read-only matrix:

```bash
cd scripts
export COMPANY_OS_ACCEPTANCE_BASE_URL="https://notification-staging.example.com"
export COMPANY_OS_ACCEPTANCE_BUILD_ID="nonprod-build-id"
export COMPANY_OS_ACCEPTANCE_API_VERSION="005-v1"
export COMPANY_OS_ACCEPTANCE_TOKENS_JSON="$(< /absolute/private/path/company-os-tokens.json)"
COMPANY_OS_ACCEPTANCE_MODE=preflight npm run accept-company-os \
  > /tmp/company-os-005-preflight-evidence.json
```

The preflight validates active/inactive identity resolution, all five flag
audiences, allowed and denied role routes, out-of-scope fallback, recursive
private/provider-field exclusion, and bounded `limit=10` lists. The server-side
read ceiling remains 100 documents per bounded query.

Only after preflight passes, run the idempotency pilot. This creates one clearly
labelled non-production IT ticket, sends it twice with the same stable operation
ID, requires exactly one matching audit event, and verifies all five configured
legacy fallback URLs. Copy `scripts/company-os-acceptance.env.example`, keep the
real file outside the repository, and set `COMPANY_OS_ACCEPTANCE_LEGACY_URLS_JSON`
to the non-production Employee, IT, Requests, Operations, and Organization
legacy routes.

```bash
COMPANY_OS_ACCEPTANCE_MODE=pilot \
COMPANY_OS_ACCEPTANCE_ALLOW_WRITES=true \
npm run accept-company-os > /tmp/company-os-005-pilot-evidence.json
```

After the pilot reviewer finishes, disable the five non-production flag
audiences in the runtime configuration, restart that non-production runtime,
and verify rollback. The runner does not change remote flags itself:

```bash
COMPANY_OS_ACCEPTANCE_MODE=rollback npm run accept-company-os \
  > /tmp/company-os-005-rollback-evidence.json
```

Record only the redacted evidence and metrics in this document. Do not commit
the token JSON or raw runtime logs. T082 is complete only after the real
preflight, pilot write/replay, query metrics, and rollback verification pass in
the non-production project. T083 additionally requires owner review. T084
remains a separate production default-switch approval.

## Release gates

- Local automated evidence: passed on 2026-08-24 (T081); details below.
- Real non-production role-matrix acceptance (T082): not yet conducted.
- Owner-reviewed limited pilot (T083): not yet conducted.
- Default switch (T084): requires a separate explicit owner approval after
  successful T082 and T083 evidence. All flags remain disabled by default.

## Organization customization scope approval — 2026-08-24

The owner approved adding the fully customizable organization structure to the
Phase 005 task list and instructed implementation of all Phase 005 tasks. The
approved design baseline for T088 is:

- The canonical hierarchy is sector -> department -> employee membership.
- Active HR, Admin, and Super Admin receive the initial managed
  `organization_structure_manage` capability; the server policy remains
  editable and no employee code is hard-coded.
- A sector or department may temporarily be managerless, but the UI shows an
  explicit vacancy and new requests use the approved routing fallback.
- Existing materialized approval plans retain their original assignees and
  evidence. Only requests created after a committed hierarchy change use the
  new manager relationship.
- Every destructive or bulk action requires an impact preview and confirmation;
  migrations default to dry-run and the legacy organization screen remains the
  rollback route.

Organization implementation and local evidence are tracked by T089–T113. Real
non-production acceptance, pilot review, and the default switch remain separate
T114–T116 gates; this approval does not authorize production deployment.

## Organization customization verification procedure

Use non-production identities and data only. Keep
`company_os_organization_v1` disabled outside the explicit test audience and
retain `/hr/departments` as the legacy rollback route throughout the run.

1. Run the organization migration with its default dry-run behavior. Confirm
   that the generated stable IDs are identical on a second run and that no
   remote record is written. Review duplicate-name, unresolved-manager, and
   orphan-employee findings before any separately approved apply run.
2. As Employee and Manager, verify bounded hierarchy reads while every create,
   rename, reorder, manager, membership, archive, and restore operation is
   denied. As HR, Admin, and Super Admin with the managed
   `organization_structure_manage` capability, verify those operations are
   available. Remove the capability from one test actor and repeat the denial.
3. Create one sector and two uniquely named departments. Try a normalized
   duplicate name, an invalid department parent, and a hierarchy cycle; each
   must fail without partial writes. Reorder and rename valid units and confirm
   their stable IDs do not change.
4. Leave one department without a manager and verify the Arabic vacancy
   warning and approved routing fallback. Reject an inactive manager, then
   assign an active manager and confirm one retained manager-history record.
5. Preview a bulk transfer and compare its impact counts, then confirm with one
   operation ID. Retry the same operation and verify replay; reuse the ID with
   a changed payload and verify conflict. Submit concurrent transfers at one
   expected version and verify only one commits.
6. Attempt to archive a unit with an active child, member, or manager and verify
   a safe conflict. Remove dependencies, archive it, confirm the default map
   hides it, restore it, and confirm no historical ID changed.
7. Materialize one approval plan, change the department manager, and verify the
   old plan is unchanged. Create a new request and verify it resolves the new
   manager. Check manager-scope and department-dashboard projections.
8. Verify every successful mutation has exactly one append-only audit event
   with operation ID, actor, target, Cairo timestamp, and safe change summary;
   no token, email, private note, or provider error may appear. Confirm list
   pages and server reads remain at or below their documented ceilings.
9. Disable the organization flag for all non-production identities, restart the
   test runtime, open the legacy route, and verify no canonical unit,
   membership, manager history, receipt, or audit record was deleted.

Record the migration report hash, role-matrix result, operation receipts,
request-routing IDs, bounded-read metrics, audit count, Arabic/RTL screenshots,
rollback time, reviewer, and incidents in the evidence table. Applying a real
migration, starting a pilot, or switching the default remains separately gated.

## Organization slice local release evidence — 2026-08-24

| Check | Result | Evidence |
|---|---|---|
| Static analysis | PASS | `flutter analyze` — no issues found |
| Architecture, bounded-query, and subscription guards | PASS | 21 tests passed |
| Organization Flutter characterization/domain/widget coverage | PASS | 13 tests passed |
| Organization Node authorization/operation/routing/migration coverage | PASS | 6 tests passed |
| Full Flutter suite | PASS | 447 tests passed |
| Full Hostinger/Node suite | PASS | 208 tests passed |
| Patch hygiene | PASS | `git diff --check` produced no errors |

The local organization run covers stable IDs, normalized-name conflicts,
two-level containment, manager vacancy, inactive-manager denial, add/move/remove
membership, canonical member counts, dry-run migration, immutable materialized
approval plans, future-request routing, idempotent retries, stale-version
conflicts, archive/restore constraints, Arabic RTL, keyboard accessibility,
large hierarchy rendering, and legacy fallback. The organization flag remains
disabled by default. No non-production or production data was changed and no
deployment was performed; T114–T116 remain external release gates.

## Local release evidence — 2026-08-24

| Check | Result | Evidence |
|---|---|---|
| Static analysis | PASS | `flutter analyze` — no issues found |
| Architecture and query guards | PASS | 16 tests passed |
| Full Flutter suite | PASS | 427 tests passed |
| Company OS acceptance-runner tests | PASS | 8 tests passed |
| Full Hostinger/Node suite | PASS | 202 tests passed |

The local run covered Company OS authorization, scope isolation, idempotency,
private-note redaction, attachment validation, abuse limits, bounded Firestore
queries, Arabic safe errors, responsive RTL surfaces, legacy route parity, and
audited rollback behavior. No production flag was enabled, no scheduler was
added, and no deployment or production data mutation was performed.
