# Implementation Plan: Controlled Google Workspace

**Branch**: `006-google-workspace-control` | **Date**: 2026-08-20 | **Spec**: [spec.md](spec.md)

## Summary

Migrate the current Company Workspace into a controlled Google Drive and spreadsheet vertical slice. The replacement preserves the live workspace as a fallback while it adds a role-scoped Drive navigator, a full-page spreadsheet editor, managed access grants, append-only action auditing, and governed workspace/HR reports. Every employee action is authorized and recorded by ZaWolf before it reaches the Google integration; direct Google activity remains separately labelled external rather than being falsely attributed.

## Technical Context

**Language/Version**: Dart/Flutter, Node.js integration runtime, current Firebase SDK stack.

**Primary Dependencies**: Flutter BLoC/Cubit, Drift for the local outbox/read model, Firebase Authentication for current identity, a server-side Google Workspace connector, and the existing HTTP integration boundary.

**Storage**: Firestore remains the current authoritative access/audit metadata store; Google Drive/Sheets remain document storage; Drift is the UI-facing outbox/cache for migrated pending operations. Hostinger is an integration adapter, never a second source of HR truth.

**Testing**: Flutter unit/widget/architecture/query-guard tests; Node unit and read-budget/idempotency tests; non-production manual acceptance validation.

**Target Platform**: Flutter web and mobile web first, with responsive Arabic RTL and desktop behavior.

**Project Type**: Existing Flutter client plus the existing Node integration runtime.

**Performance Goals**: Folder/file/Sheet open reaches content, an empty state, or actionable retry guidance within 10 seconds for 95% of normal-network acceptance attempts. Common editor mutations batch and acknowledge within 5 seconds where the upstream service is available.

**Constraints**: No client-side Google credentials, root IDs, or unrestricted Google URLs; every write is idempotent and auditable; no raw infrastructure error reaches employees; bounded Drive discovery and sheet reads; no unrelated HR/payroll/attendance business-rule rewrite.

**Scale/Scope**: Company root, department, HR, employee, and reports folders; hundreds of employees/resources; a sheet viewport rather than an unbounded whole-workbook browser response; reports generated daily, weekly, monthly, and for an authorized chosen period.

## Constitution Check

| Gate | Result | Plan response |
|---|---|---|
| Strangler Fig delivery | Pass | New `features/company_workspace` slice and route/feature switch are added beside the existing screens/services; legacy remains until parity and rollback acceptance. |
| Enforced layer boundaries | Pass | Presentation depends only on domain contracts/Cubits; concrete Firebase/HTTP/Google code is confined to data/integration adapters. |
| Focused Cubits | Pass | Separate cubits own resource browsing, spreadsheet editing, access administration, report discovery/generation, and operation sync state. |
| Offline/conflict safety | Pass | Outbox operation IDs, retry classification, acknowledgement reconciliation, and explicit conflict states are designed before UI migration. |
| Critical attendance/payroll safety | Pass with boundary | This phase reads attendance/request/deduction records for reports only. Existing critical specs and behavior are untouched; any change to their calculation is a separate approved feature. |
| Scheduler/integration ownership | Pass | Reporting and external-activity reconciliation will identify one live scheduler owner and have manual recovery commands only. |
| Firestore read budget | Pass | Listeners/queries are scoped, paginated, reusable, and receive read-budget/idempotency tests. |

## Delivery Stages

1. **Foundation and safety boundary** — characterize the current workspace, define contracts, add feature switch, migration read compatibility, safe errors, outbox primitives, and operation/idempotency tests.
2. **Controlled Drive navigator** — migrate resource discovery, hierarchy, folder/file operations, progressive loading, permission checks, and audit events through the new vertical slice.
3. **Spreadsheet editor parity** — replace the limited editor with a full-page grid workflow: direct cells, range selection, clipboard, navigation, formula/input bar, structure, tabs, validation, labels, formatting, and accessibility. Unsupported content is protected rather than damaged.
4. **Access administration and audit** — introduce dynamic IT-manager/super-admin policy controls, grants, revocations, report visibility, audit search, and external-activity reconciliation labels.
5. **Reporting** — create idempotent workspace activity reports and HR attendance/request/deduction reports to protected report destinations, with period selection and discovery inside ZaWolf.
6. **Migration, acceptance, and switch** — run parity checks on a test root, backfill only non-destructively, validate role/security/offline cases, enable a controlled pilot, and retain the legacy route as rollback until approved retirement.

## Project Structure

### Documentation

```text
specs/006-google-workspace-control/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── workspace-contracts.md
└── tasks.md                 # Created only after plan approval
```

### Source Code

```text
lib/
├── core/
│   ├── errors/
│   ├── sync/
│   └── feature_flags/
├── features/company_workspace/
│   ├── domain/
│   ├── data/
│   └── presentation/
├── services/                # Existing legacy adapters remain during migration
└── screens/                 # Existing legacy screens remain during migration

scripts/
├── notification-web.js      # Existing transport/router adapter, slimmed only where migrated
├── google-sheets-integration.js
├── workspace/
│   ├── authorization.js
│   ├── audit.js
│   ├── reports.js
│   └── activity-reconciliation.js
└── test/

test/
├── features/company_workspace/
├── architecture_guard_test.dart
└── firestore_query_guard_test.dart
```

**Structure Decision**: Use one feature-first clean-architecture module for the Flutter replacement. The existing Node files remain live integration entry points during the Strangler Fig migration, while workspace concerns are split into small server-side modules instead of growing the router further.

## Post-Design Constitution Check

The design passes all gates. The primary risk is claiming Google-native parity or audit coverage that cannot be guaranteed. The plan avoids that risk by making ZaWolf the mandatory employee interaction surface, recording all ZaWolf-originated operations, and explicitly classifying direct Google activity as external/unattributed. No production Firestore-rule change, destructive Drive restructuring, or automatic removal of employee direct shares is included without a separately approved rollout and rollback plan.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Two runtime layers (Flutter and Node integration) | The existing app and server-side controlled Google identity must both participate. | Direct client access would expose Google IDs/links, bypass controlled access, and make reliable auditing impossible. |
| Local outbox plus server audit | Network interruptions and retries must not duplicate mutations or lose activity evidence. | Direct immediate writes cannot provide reliable pending/conflict state or retry-safe idempotency. |
