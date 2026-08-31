# Implementation Plan: Employee Operations and Operational Reliability

**Branch**: `007-employee-operations` | **Date**: 2026-08-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/007-employee-operations/spec.md`

## Summary

Deliver Phase 007 through reversible vertical slices alongside the live legacy
screens: transparent deductions and attendance corrections, reliable
notifications and request visibility, scoped operational controls, deterministic
sales mapping/filtering, safe Arabic diagnostics, and foundations for a governed
assistant and employee-management conversations. Firebase and Hostinger stay
authoritative; Flutter receives neither sales nor Drive credentials.

The assistant and chat foundations remain disabled by default until the owner
approves a provider, retention policy, budget, and data-processing policy. Drive
attachments use the existing controlled workspace server adapter, never a public
Drive URL.

## Technical Context

**Language/Version**: Dart/Flutter, Node.js CommonJS Hostinger runtime, JavaScript GitHub jobs.

**Primary Dependencies**: Flutter, flutter_bloc for migrated state, Firebase Auth/Firestore, `http`; Node Firebase Admin, current sales client and controlled Google Drive integration.

**Storage**: Firestore business authority; local check-in outbox only for retry; Company Drive holds governed attachment binaries; server environment holds third-party secrets.

**Testing**: Flutter analyze/unit/widget/architecture/query guards; Node contract, idempotency and read-budget tests.

**Target Platform**: Flutter web, Android, iOS; Hostinger Node; GitHub Actions.

**Project Type**: Mobile/web app plus server integration runtime.

**Performance Goals**: management timeline p95 <10 seconds, badge state <5 seconds, no unbounded listeners, one persisted sales snapshot per filter version.

**Constraints**: Arabic RTL, normal browser selection/copy, no raw Firebase/provider errors, server-authoritative access, no client secrets, preserve Cairo effective-date payroll semantics, bounded reads, no confidential employee context to external AI by default.

**Scale/Scope**: Existing multi-role workforce system with historical requests/deductions, external sales data, and Workspace Phase 006 integration.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Result |
|---|---|
| Strangler Fig | Pass — new flows have flags, legacy parity, and rollback before retirement. |
| Feature boundaries | Pass — new slices live in dedicated `lib/features/*/{data,domain,presentation}` directories. |
| Presentation isolation | Pass — Cubits use domain contracts only; Firebase/HTTP/Drive stay in data adapters. |
| Payroll/attendance | Pass with characterization — effective-date/cycle behavior is preserved; no reopen, backfill, or rule change. |
| Scheduler/read budget | Pass — paginated bounded queries; no new global recurring scan. |
| Security | Pass — server rechecks actor role/membership; secrets remain server-only. |
| Reversibility | Pass — visibility/mapping are audited and reversible; no deletion/migration. |

## Design Sequence

1. Establish safe Arabic error envelope, diagnostic aggregation, release correlation, rate limiting, and a server-authorized in-app developer-tools entitlement that cannot change attendance security controls.
2. Add deduction explanation plus pre-filled late-arrival correction shortcut behind `employee_operations_v2`.
3. Fix bounded role-scoped request/deduction history, notification unread state, and role-aware deep links.
4. Add reversible account operational visibility, employee date-range timeline, checkout-policy relocation, and security-review navigation gate.
5. Add server-only sales identity registry and one filter-versioned sales snapshot contract; rotate the shared test key before production.
6. Introduce compatibility `WorkOutcome` linking legacy task/KPI history rather than rewriting it.
7. Deliver governed assistant/conversation metadata and Drive attachment authorization behind disabled-by-default flags.
8. Finish forced-update state machine, Arabic copy/arrows, browser interaction, responsive layout, and full regression validation.

## Project Structure

### Documentation (this feature)

```text
specs/007-employee-operations/
├── plan.md              # This file ($speckit-plan command output)
├── research.md          # Phase 0 output ($speckit-plan command)
├── data-model.md        # Phase 1 output ($speckit-plan command)
├── quickstart.md        # Phase 1 output ($speckit-plan command)
├── contracts/           # Phase 1 output ($speckit-plan command)
└── tasks.md             # Phase 2 output ($speckit-tasks command - NOT created by $speckit-plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
lib/features/
├── employee_operations/{data,domain,presentation}/
├── operational_visibility/{data,domain,presentation}/
├── sales_indicators/{data,domain,presentation}/
├── diagnostics/{data,domain,presentation}/
├── assistant/{data,domain,presentation}/
└── conversations/{data,domain,presentation}/
scripts/
├── notification-web.js
├── sync-sales-kpis.js
├── sales-analytics-client.js
└── workspace/
```

**Structure Decision**: legacy screens/services remain live while adapters lead
to new flagged slices. Presentation never imports new data implementations.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Added component | Why needed | Simpler alternative rejected because |
|---|---|---|
| Server diagnostic ingestion | Safe production issue reporting without secrets/raw errors. | Client-only logs vanish and are not trustworthy. |
| Sales identity registry | Prevents wrong employee attribution. | Name matching is unsafe. |
| Chat metadata plus Drive adapter | Enforces access/audit without app binary storage. | Public Drive URLs cannot be revoked/audited per view. |
| Developer-tools entitlement | Allows controlled diagnosis for one employee without a global debug build. | A client-only flag can be forged and a debug build weakens operational safeguards. |
