# Implementation Plan: Internal Company OS Foundation

**Branch**: `005-internal-company-os` | **Date**: 2026-08-23 | **Spec**: [spec.md](spec.md)

## Summary

Add IT operations, asset and license management, knowledge, and finance-service
workflows to the existing ZaWolf HR application. The implementation extends the
current identity, request history, notification, and approval-chain experience;
it does not introduce a separate IT or Finance application. New vertical slices
are disabled by default, keep legacy HR routes available, and use authenticated
Hostinger operations plus a local Drift outbox for idempotent, recoverable
writes. Google Workspace remains owned by Phase 006 and is not part of this
feature.

## Technical Context

**Language/Version**: Dart 3.9 / Flutter 3.x; Node.js JavaScript on Hostinger

**Primary Dependencies**: Flutter BLoC/Cubit, go_router, Drift, http,
Firebase Authentication, Cloud Firestore, OneSignal

**Storage**: Firestore remains the canonical remote business store; Drift is
the UI-facing local cache/outbox for migrated Company OS operations

**Testing**: flutter_test, architecture/query guards, Node.js built-in test
runner, deterministic fixture and contract tests

**Target Platform**: Flutter Android, iOS, and responsive web; Hostinger Node
integration runtime

**Project Type**: Existing Flutter client plus authenticated Node operation API

**Performance Goals**: Bounded paginated lists return data, empty state, or
retry guidance within 10 seconds; no unbounded Firestore list/listener; an
employee submits a ticket in under 3 minutes

**Constraints**: Arabic RTL; no raw provider errors; all writes idempotent and
audited; private IT notes never leave IT scope; Finance and Company Owner stages
are mandatory for every cost-bearing request; no payroll mutation; no
production rule change or destructive migration in this phase

**Scale/Scope**: One company, hundreds of employees and assets, seven
operational roles, five independently switchable vertical slices, a two-level
sector/department hierarchy, and bounded page sizes of 10/25/50/100

## Constitution Check

### Pre-design gate

- **Strangler Fig**: PASS. New routes and repositories live beside legacy HR
  screens and are selected through disabled-by-default server flags.
- **Layer boundaries**: PASS. Domain owns contracts; data owns Drift/Firestore/
  HTTP; presentation depends on domain and focused Cubits only.
- **Focused Cubits**: PASS. Ticket list/detail, assets, approvals, dashboard,
  and finance ledger each have separate UI-state owners under 300 lines.
- **Payroll and attendance safety**: PASS. This phase reads existing payslip and
  deduction projections but does not calculate payroll, allocate deductions,
  or change attendance behavior.
- **Test-first delivery**: PASS. Contract, authorization, idempotency, privacy,
  and legacy-parity tests precede route switching.
- **Offline/sync**: PASS. Mutations enter a Drift outbox with operation ID,
  expected version, and visible pending/conflict/status-check states.

### Post-design gate

PASS. The data model, API contracts, and quickstart retain these constraints.
No exception to the constitution is required.

## Architecture

```text
Flutter presentation (Arabic RTL, Cubits)
             |
      domain repositories
             |
  data adapters + Drift outbox/cache
             |
 authenticated Hostinger operation API
             |
 Firestore canonical records + append-only audit
```

Read paths are role-scoped and paginated. Mutations use a client-generated
`operationId`; the server transaction validates role, active employment,
transition, capacity, current version, and approval policy before changing the
canonical record and writing one audit event. A repeated operation returns the
original receipt. Hostinger owns integration behavior only; approval and entity
state remain canonical records.

## Feature Slices and Rollout

1. `company_os_portal_v1`: employee portal shell, own tickets/assets/access,
   knowledge, safe sync states.
2. `company_os_it_v1`: IT ticket assignment, private notes, assets, handovers,
   maintenance, software and seat management.
3. `company_os_requests_v1`: existing request center extended with access and
   all cost-bearing request types and their policy-driven approval stages.
4. `company_os_operations_v1`: IT/Finance dashboards, scoped search, reports,
   and audit explorer.
5. `company_os_organization_v1`: dynamic sector/department CRUD, manager
   assignment, employee membership, impact previews, and organization map.

Each slice has server-side audience controls, pilot metrics, a legacy route,
and an independent rollback switch. No slice becomes default without parity,
non-production acceptance, owner approval, and documented rollback evidence.

## Project Structure

```text
lib/features/company_os/
├── data/
│   ├── local/
│   ├── remote/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── use_cases/
└── presentation/
    ├── cubit/
    ├── pages/
    └── widgets/

lib/features/organization_structure/
├── data/
│   ├── local/
│   ├── remote/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── use_cases/
└── presentation/
    ├── cubit/
    ├── pages/
    └── widgets/

lib/core/
├── errors/
├── feature_flags/
└── sync/

scripts/
├── company-os/
└── test/

test/features/company_os/
specs/005-internal-company-os/
```

The existing request, employee, notification, payroll, and navigation code is
adapted only at explicit composition/route seams. Phase 006 Company Workspace
code is consumed only through an attachment contract when enabled; it is not a
dependency for the Phase 005 MVP.

## Data and Query Strategy

- Stable deterministic document IDs are derived from entity ID or operation ID.
- Every mutable aggregate has `version`, `createdAt`, `updatedAt`, and state.
- List endpoints require scope, limit, cursor, and supported filters. Maximum
  page size is 100; no management screen streams an entire collection.
- Dashboard counters use bounded server projections rather than client-wide
  collection scans.
- Private notes are stored separately from public comments and never included
  in employee DTOs, notifications, exports, diagnostics, or search documents.
- Cost-bearing request classification is server-side and fail-closed. Finance
  and the managed owner approver are never optional.
- Owner policy initially resolves active employee code `ceo-100`, then stores
  the resolved UID in a managed versioned policy record.
- Organization units use immutable opaque IDs; renames never rewrite employee,
  request, report, or audit references. Active departments have one sector
  parent, one optional current primary manager, and bounded membership pages.
- Structure mutations execute through a previewed change set with expected
  versions. The transaction updates canonical units/memberships and future
  routing projections together; existing approval plans are immutable.
- Migration defaults to dry-run and never deletes current division, department,
  manager, or employee fields. The new slice reads its own canonical projection
  and falls back to the legacy organization screen when disabled.

## Verification Strategy

- Domain tests for lifecycles, capacity, approval policy, and role scopes.
- Node contract tests for authentication, idempotency, private-field redaction,
  audit atomicity, pagination, and duplicate writes.
- Flutter Cubit/widget tests for Arabic loading, empty, pending, conflict,
  denied, and retry states.
- Query-budget and architecture guards for every repository.
- Non-production role matrix acceptance using Employee, IT Support, IT Manager,
  Finance, Manager, Admin, and Super Admin fixtures.
- Organization acceptance covers managed capability grants, dynamic unit CRUD,
  manager vacancy/replacement, bulk employee transfers, concurrent conflicts,
  migration dry run, old-request immutability, future routing, and rollback.
- Full required checks before handoff; production deployment is a separate
  explicit owner-approved action.

## Complexity Tracking

No constitution violations. The operation gateway and local outbox reuse
patterns already proven by attendance check-in and Company Workspace instead of
introducing another state-management or synchronization mechanism.
