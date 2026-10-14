# Validation Quickstart: 7DHUB Multi-Company Platform

This guide validates the designed behavior after implementation. It does not
authorize production migration, Firestore-rule deployment, company activation,
or store release.

## Prerequisites

- Local Firebase/Auth/Firestore emulators and Hostinger-compatible Node test runtime.
- Flutter toolchain matching the repository lockfiles.
- No production credentials or production data.
- Fixture identities:
  - Platform Super Admin;
  - General HR without sensitive scopes;
  - General HR with explicit payroll scope;
  - Company A CEO, HR, manager, and employee;
  - Company B CEO, HR, manager, and employee;
  - one person with active memberships in both companies;
  - inactive, revoked, suspended-company, and out-of-scope identities.
- Company A uses Cairo/Egypt settings; Company B uses a different timezone,
  workweek, branding, and request/attendance policy.

## 1. Baseline current behavior

Before tenant changes, run the existing attendance, payroll, approval, chat,
notification, architecture, and query characterization tests. Record current
critical-flow results for the existing company.

Expected: the baseline is green or any pre-existing failure is documented and
not attributed to this feature.

## 2. Company lifecycle and global management

1. Create Company A as a draft through the platform API.
2. Attempt activation without leadership.
3. Add an active CEO and two Company HR assignments.
4. Publish valid branding and required operating settings.
5. Activate Company A with the preview token and expected revision.
6. Repeat the activation operation ID.
7. Open the registry as Platform Super Admin, General HR, and Company A HR.

Expected:

- incomplete activation is rejected with safe missing requirements;
- complete activation creates one result and one logical audit outcome;
- retry returns that result without duplicate leadership/audit;
- Platform Super Admin sees lifecycle controls;
- General HR sees only granted global HR controls;
- Company HR cannot enumerate Company B or global registry data.

## 3. Global shared-services approval pool

1. Create Global Accounting with access to Companies A and B and a selected set
   of financial request types.
2. Add two effective members with request-summary and decision capabilities.
3. Add Global Accounting between the manager and HR stages of a Company A
   approval chain and submit a request.
4. Attempt simultaneous approve/reject decisions from the two accountants and
   retry both operation IDs.
5. Revoke all eligible members while another request is waiting at that step.

Expected:

- the chain editor distinguishes Global Accounting from Company A Accounting;
- both members receive one company-labelled actionable item and only the safe
  request fields needed for a decision;
- exactly one department decision and downstream transition commits, and the
  actual actor appears in request/audit history;
- retries return the committed outcome without duplicate notifications or
  approvals;
- an out-of-scope person/request/company is denied;
- the request with no remaining eligible actor becomes visibly blocked for
  governed escalation and is not silently approved, rejected, or skipped.

## 4. Company isolation matrix

For every role, test get/list/create/update/delete/search/export/download/deep
link against own-company, other-company, unknown-company, and global targets.
Include direct Firestore emulator attempts and Hostinger API attempts.

Expected: every unauthorized cross-company result is denied without protected
existence, count, name, salary, message, file, or audit leakage. Query guards
reject any company-owned repository query without enforced company scope.

## 5. Identity and company switching

1. Sign in as the dual-company person.
2. Load Company A cached dashboard and queue an offline Company A operation.
3. Switch to Company B while offline, then reconnect.
4. Revoke Company A membership and try its saved deep link.

Expected:

- switch changes branding, permissions, navigation, streams, cache, and routes;
- no Company A content is visible in Company B;
- Company A outbox stays in Company A and never submits under Company B;
- revocation blocks Company A access and does not affect Company B membership.

## 6. Branding and 7DHUB fallback

Publish different valid logos/colors for A and B. Test missing media, corrupt
checksum, inaccessible media, invalid type/size, unreadable colors, offline
cache, version update, signed-out state, reports, exports, and web title/icon.

Expected: approved branding remains company-scoped and accessible. Every
failure uses bundled 7DHUB HR fallback without blocking core work. The mobile
installed name/default icon remain 7DHUB HR unless a packaged alternate icon is
part of the tested native release.

## 7. Critical business parity

Run equivalent Company A and Company B journeys for:

- attendance check-in/out, day off, leave, permissions, absence, reminders;
- locations/branches, schedules, device/web attendance, and corrections;
- request submission, request management, and materialized approval chain;
- meetings, room approval, history, and reminders;
- pending/approved deduction, rewards/warnings, and payroll-cycle close;
- employee management, organization placement, hiring, and resignation;
- task creation/execution, productivity, and sales/KPI mapping;
- direct/group chat, media, attachment authorization, notification/deep link;
- records/files/workspace and Company Services and Support;
- period reports, global/company drill-downs, and exports.

Expected: each journey uses its company's timezone, policies, leadership,
members, and identifiers. Company A preserves current payroll/attendance
semantics. Same employee codes and labels in B do not collide.

## 8. Worker and notification isolation

Run two worker instances over both companies with overlapping schedules, then
retry each job and suspend Company B mid-run. Dispatch notifications to a dual-
company person and attempt stale/cross-company routes.

Expected: per-company leases and deterministic IDs prevent duplicates;
checkpoints converge; suspension follows policy; notifications open only an
authorized company target and do not expose a forbidden preview.

## 9. Initial-company migration rehearsal

1. Run inventory and dry-run against a production-shaped fixture.
2. Verify counts per collection/business area and inspect ambiguous items.
3. Resolve fixture ambiguity and approve the batch.
4. Interrupt apply after at least one page, rerun, then reconcile.
5. Compare critical screens, reports, history, and aggregate counts with baseline.
6. Disable tenant routes and verify legacy route rollback.

Expected: every record is assigned, intentionally global, or quarantined;
retry creates no duplicates; parity differences are zero or explicitly blocked;
legacy route works for Company A; ownership and audit remain after route rollback.

## 10. Performance and bounded-read acceptance

Use fixtures with at least 100 companies and 10,000 memberships. Load registry,
company picker, global HR summary, company dashboard, audit, and reports while
capturing read counts and response time.

Expected: lists are paginated, summaries use projections, no raw global
business scan occurs, company switching is usable within 5 seconds, and bounded
views reach a useful state within 10 seconds in the acceptance environment.

## 11. Organization, search, and authority acceptance

1. Build the global/shared-services tree and two independent company trees with
   branches, departments, teams, vacant/occupied positions, job catalog titles,
   and primary plus functional managers.
2. Attempt a cycle, cross-owner parent, orphan, and second primary placement.
3. Submit an approval, reorganize its department/manager, then decide it.
4. Search using Arabic/English name variants, partial names, employee codes,
   emails, departments, job titles, statuses, dates, and duplicate labels across
   companies. Change filter/sort while reusing an old cursor.
5. Save a view, revoke one company and one sensitive field, then reopen it.
6. Give one Global HR actor complete read visibility but no decision authority;
   make that actor, the requester, an incompatible-duty holder, and two racing
   pool members attempt decisions.

Expected: the published tree is cycle-free and retains separate ownership;
open approval routing keeps its submitted snapshot; search is bounded, stable,
company-labelled, and reveals no unauthorized existence/count/facet; stale
cursors refresh safely; saved views lose revoked data/actions; read-only users
see no usable approval control and trusted endpoints deny them; conflict and
concurrency rules produce one deterministic transition and actual-actor audit.

Review the generated module governance matrix and confirm every enabled module
defines ownership, visibility, actions/approval, search/filter/sort,
notifications/deep links, audit, cache/offline, reports/exports, retention, and
passing isolation/parity evidence.

## 12. Required repository checks

```bash
flutter analyze
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test
(cd scripts && npm test)
```

Also run the tenant Firestore emulator matrix, migration fixture suite, and
mobile/web company-switch acceptance tests introduced by this feature.

## Production gates

Do not enable new-company creation until all of the following are approved:

- complete ownership inventory and initial-company reconciliation;
- complete federated organization validation and module governance matrix;
- verified separation of view, sensitive-view, manage, decide, and export;
- authorized global search/filter/sort/saved-view security and read budgets;
- zero cross-company leakage in rules/API role matrix;
- payroll and attendance parity;
- scheduled-job ownership/read-budget evidence;
- offline/cache/outbox isolation;
- branding fallback and mobile/web acceptance;
- production Firestore rules and indexes with rollback plan;
- production migration runbook and verified backup/restore path;
- owner approval for pilot company and each default-route switch.
