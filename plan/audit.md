# Zawolf HR / ERP — Phase 0 Architecture Audit

**Audit date:** 2026-08-20  
**Branch / baseline:** `main` at `5270abb`  
**Scope:** inspection and guardrails only; no Phase 1 migration and no production
Firestore-rule change.

## Executive summary

The application is a live, legacy-first Flutter/Firebase system. It does not yet
use Feature-First Clean Architecture or BLoC/Cubit. The current presentation
layer mixes UI state, approval orchestration, Firestore queries, and writes. The
largest screens are 3,000–4,000 lines, which makes request-management and
employee-management changes particularly risky.

The safest migration is a Strangler Fig: introduce `lib/core/` and one
`lib/features/<feature>/{data,domain,presentation}` vertical slice at a time,
switch routing only after parity, and retain untouched legacy files. Attendance
must be migrated before payroll because payroll closes from attendance and
permission records.

The repository description was partly stale. Current source shows:

- daily HR processing and monthly payroll close are scheduled by GitHub Actions;
- attendance reminders, automatic attendance, manager-leave bypass, and push
  dispatch are normally run by the Hostinger Node process or an external cron;
- their GitHub workflows are manual recovery paths;
- Sales KPI synchronization can also run from the Hostinger process.

## Repository snapshot

| Area | Current count / observation |
|---|---:|
| Dart files under `lib/` | 164 |
| Screens | 51 |
| Services | 56 |
| Models | 32 |
| `setState` calls in screens | 361 |
| Firestore snapshot calls | 66 |
| UI/component files with direct Firebase/Dio access | 18 |
| GitHub workflows | 15 |

The worktree was already heavily modified and contained many untracked files
before this Phase 0 audit. Those unrelated changes were preserved. Phase 0 did
not revert or reinterpret them.

## Current folder structure

```text
lib/
  components/       shared and screen-specific widgets
  models/           Firestore-shaped mutable application models
  navigation/       GoRouter and role navigation shell
  screens/          employee, manager, HR, team leader, shared screens
  services/         Firebase, policy, orchestration, reporting, notifications
  theme/            current theme definitions
  utils/            helpers, including payroll-cycle calculations
scripts/             Firebase Admin jobs and Hostinger server
.github/workflows/   scheduled and manual operations
test/                Flutter unit/widget/static regression tests
scripts/test/        Node unit and static budget tests
```

There is no existing `lib/core/` or `lib/features/` architecture. Phase 0 does
not create empty architecture folders; the first reviewed vertical slice will
create only the structure it needs.

## State management and routing

- `provider` is the active app-wide state package.
- `AuthService` is a `ChangeNotifier` registered with `ChangeNotifierProvider`.
- Most screens own state directly through `StatefulWidget` and `setState`.
- There are no application Cubits or Blocs in the audited tree.
- `go_router` controls routes and redirects; the navigation wrapper also makes
  role-dependent decisions.
- Several screens construct Firestore streams during widget work, coupling
  subscription lifetime and rebuild behavior to presentation code.

This is a baseline, not a request to convert every screen at once. New migrated
features must use BLoC/Cubit; legacy Provider/setState remains until replaced.

## Direct infrastructure access from presentation

The following 18 files import or invoke Firebase/Auth/Firestore directly:

```text
lib/components/employee_request_history_section.dart
lib/components/request_approval_timeline.dart
lib/screens/employee/employee_dashboard.dart
lib/screens/employee/employee_requests.dart
lib/screens/hr/announcements.dart
lib/screens/hr/attendance_policy_settings_screen.dart
lib/screens/hr/department_performance_screen.dart
lib/screens/hr/employee_mgmt.dart
lib/screens/hr/field_assignments_screen.dart
lib/screens/hr/hr_dashboard.dart
lib/screens/hr/location_mgmt.dart
lib/screens/manager/manager_dashboard.dart
lib/screens/manager/requests_mgmt.dart
lib/screens/manager/team_attendance.dart
lib/screens/manager/team_members_screen.dart
lib/screens/shared/employee_insights_screen.dart
lib/screens/shared/notifications_screen.dart
lib/screens/shared/polls_screen.dart
```

The highest-risk examples are `requests_mgmt.dart` and `employee_mgmt.dart`,
where display, search/filter state, authorization decisions, approval writes,
and error handling share one file. The Phase 0 guard records this as a legacy
allowlist and prevents new UI files from adding direct infrastructure access.

## Size and concentration risks

| File | Lines | Risk |
|---|---:|---|
| `lib/screens/manager/requests_mgmt.dart` | 4,094 | all request types and approval states in one screen |
| `lib/screens/hr/employee_mgmt.dart` | 4,024 | CRUD, import, filters, roles, organization data |
| `lib/screens/employee/employee_requests.dart` | 3,098 | request forms, quotas, streams, writes, validation |
| `lib/screens/hr/department_performance_screen.dart` | 1,977 | aggregation, Firestore, UI and editing |
| `lib/services/attendance_service.dart` | 1,689 | attendance, security review, correction and notification behavior |
| `lib/screens/manager/kpi_mgmt.dart` | 1,673 | KPI templates, scoring and presentation |
| `lib/screens/shared/company_workspace_center_screen.dart` | 1,443 | Drive registry, access and UI |
| `lib/screens/shared/workspace_sheet_editor_screen.dart` | 1,281 | spreadsheet state, editing and layout |

## Duplicate models and widgets

No exact duplicate public model class declaration was found. There is,
however, duplicated business representation across runtimes: payroll-cycle
logic exists in Dart (`lib/utils/payroll_cycle.dart`) and Node
(`scripts/payroll-cycle.js`), and attendance-policy calculations exist in both
Dart services/models and Node jobs. These must be held together with shared
characterization cases before either implementation changes.

Repeated private presentation widgets indicate missing design primitives:

- `_Chip` appears in four task/warning screens.
- `_MetricLine` appears in three payroll/productivity views.
- `_ScoreBar`, `_RankBadge`, `_PeriodSelector`, `_HighlightCard`, and `_Metric`
  each have multiple local implementations.
- Request-summary concepts appear separately in employee history and the
  shared request log.

Private names alone do not prove identical behavior, so Phase 0 does not merge
them. A later design-system slice should compare semantics and visual states
before extracting shared components.

## Scheduled jobs and Firestore impact

### Live schedules

| Owner | Trigger | Entry point | Reads / writes |
|---|---|---|---|
| GitHub Actions | daily at both DST-safe UTC candidates; script accepts only 08:00 Cairo | `scripts/daily-tasks.js` | `users`, `companies`, `companyDayOffs`, `leaves`, `permissions`, `attendance`, `tasks`, `notifications/*/items` |
| GitHub Actions | daily at 21:05 and 22:05 UTC; script acts only on Cairo day 26 | `scripts/monthly-tasks.js` | `users`, `attendance`, `permissions`, `leaves`, `warningsRewards`, `advances`, `companies`; writes `payrollRuns`, `payrollCycles`, user permission balances |
| Hostinger / external cron | normally every five minutes | `notification-web.js` → reminder, automatic-attendance and bypass jobs | see attendance workers below; guarded by `systemRuntimeLocks` |
| Hostinger listener | Firestore collection-group listener plus hourly fallback | `dispatch-notifications.js` | pending `notifications/*/items`, recipient `users`, matching `attendance`; updates delivery claims/results |
| Hostinger | interval when `SALES_API_KEY` is configured | `sync-sales-kpis.js` | sales settings/API plus `users`, `leaves`, `companyDayOffs`, `employeeKpis`, `salesKpiSummaries`, `tasks`, notifications |

### Attendance workers

| Script | Collections touched |
|---|---|
| `attendance-reminders.js` | `users`, `companies`, `companyDayOffs`, `leaves`, `permissions`, `fieldAssignments`, `attendance`, `attendanceReminderRuns`, notifications |
| `auto-attendance.js` | `autoAttendanceSignals`, `publicConfig`, `users`, `locations`, `companies`, `companyDayOffs`, `leaves`, `permissions`, `fieldAssignments`, `attendance`, notifications |
| `manager-leave-permission-bypass.js` | `permissions`, `users`, `leaves`, `attendance`, `companies`, notifications |
| `attendance-gateway.js` | `users`, `attendanceDevices`, `attendance` |

### Manual workflows

Attendance reminder/dispatch recovery, cleanup, diagnosis, device reset,
identity repair, attendance-metric reset, salary-deduction reset, employee
import, email update, manager-first migration, hiring-date update, and OneSignal
test workflows are manual-only. Cleanup and reset workflows can write or delete
data and must remain dry-run-first.

## Firestore read and reliability risks

- `pending_requests_service.dart` maintains three broad session listeners.
- `task_service.dart`, `suggestion_service.dart`, and
  `company_day_off_service.dart` expose broad historical streams.
- `productivity_service.dart` creates per-managed-employee listeners and also
  performs month-wide KPI reads in calculations.
- Direct streams in large screens make listener reuse difficult to verify.
- Hostinger reminder/bypass polling can amplify reads with employee count.
- Monthly close reads all approved leaves and commits in chunks. It is
  idempotent after finalization but not atomic across all chunks.
- A finalized payroll cycle is not automatically recalculated for deductions
  approved later. That is a business decision to specify before changing.

The existing `firestore_query_guard_test.dart` catches a particularly costly
`snapshots().asyncMap(...get())` pattern. The new architecture guard adds
forward-only enforcement for migrated features and direct-infrastructure UI
files.

## Repository hygiene result

- 41 root ZIP/CSV artifacts were moved to the recoverable sibling directory
  `/Users/seg/Shemais/Shemais/zawolf_hr_phase0_artifacts_2026-08-20`.
- 17 of those artifacts were tracked and now appear as intentional deletions.
- Root ZIP/CSV/spreadsheet patterns are ignored going forward.
- Employee import data is no longer expected in Git. The manual import workflow
  now decodes the protected `EMPLOYEE_IMPORT_CSV_BASE64` repository secret into
  the runner's temporary directory.
- `scripts/email_updates.csv` remains because it is an explicit input to a
  manual operational workflow and is not a root export. It still contains
  account mapping data and should be handled in a separate reviewed security
  change if the owner wants all operational PII removed from Git.

Archive scanning found no private keys, service-account JSON, or embedded
OneSignal key values. Matches were environment-variable references only. The
deleted CSVs contain employee/account PII and remain in Git history. No history
rewrite was attempted; that requires an explicit owner decision and coordinated
credential/data handling.

Two tracked one-off scripts, `generate_md.py` and `update_csv.py`, contain
machine-specific absolute paths to a removed CSV. They are now stale. They were
flagged rather than deleted because Phase 0 cleanup authorization named the
artifacts, not arbitrary legacy code.

## Mechanical guardrails added in Phase 0

- Zawolf constitution v1.0.0 under `.specify/memory/constitution.md`.
- `AGENTS.md` rules and PR checklist.
- `test/architecture_guard_test.dart`:
  - migrated presentation cannot import data/Firebase/Dio;
  - legacy UI direct-infrastructure allowlist cannot grow;
  - Cubits over 300 lines fail for manual review;
  - each `lib/features/<feature>` requires `specs/<feature>/`.
- `.github/workflows/architecture-guardrails.yml` runs analyze, the architecture
  guard, the existing Firestore query guard, Flutter tests, and Node tests.

## Phase gate verification

The Phase 0-specific architecture and Firestore query guards pass, and all 56
Node tests pass. The repository-wide gate is intentionally **not green yet**:

- `flutter analyze` reports 20 existing findings: deprecated APIs and async
  context/style findings in legacy files, plus five unused workspace actions.
- `flutter test` passes 112 tests and fails two existing assertions:
  `widget_test.dart` expects a missing-KPI productivity score of 28.5 but the
  implementation returns 95.0; `requests_management_regression_test.dart`
  expects the CEO status filter to contain a specific literal list that the
  current request screen no longer contains.

These failures are outside the Phase 0 documentation/guardrail diff and were
not silently changed. Under the constitution, they block Phase 1 until the
owner reviews their intended behavior and a separate focused fix makes the
full gate green.

## Recommended migration order after owner review

1. Phase 1 shared failure/result types and auth/session boundaries.
2. Auth vertical slice as the first full spec/plan/tasks/implementation cycle.
3. Attendance vertical slice, preserving deterministic IDs, device binding,
   offline events, correction requests, deductions and reminder idempotency.
4. Payroll vertical slice, consuming the characterized attendance contracts.
5. Requests/approvals and notifications.
6. Tasks/KPI/productivity, then reports and Google Workspace.

No Phase 1 work should start until this audit and the two critical behavior
specifications are reviewed.
