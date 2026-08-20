# Implementation Plan: Check-in Reliability Pilot

**Branch**: `002-attendance-reliability` | **Date**: 2026-08-20 | **Spec**: [spec.md](spec.md)

**Input**: Approved check-in-only reliability specification from `specs/002-attendance-reliability/spec.md`.

## Summary

Add a new, feature-first employee check-in slice alongside the live attendance
service. The slice returns structured outcomes from the shared error foundation,
retains only valid check-ins in an account-scoped durable outbox, performs
bounded retries only for deterministic check-in identities, checks final status
before allowing a potentially duplicate action, and presents Arabic
saved/pending/check-status messages through a focused Cubit.

The existing check-out implementation, its existing offline queue, and live
attendance route remain unchanged. The employee dashboard uses a deliberate
pilot switch that defaults to the legacy check-in path until parity tests and
owner-approved rollout evidence exist.

## Technical Context

**Language/Version**: Dart/Flutter (SDK constraint from `pubspec.yaml`); Node.js for the existing company attendance gateway.

**Primary Dependencies**: Existing Flutter and Firebase packages; new pilot state uses `flutter_bloc`; the durable outbox uses Drift; existing `connectivity_plus`, location/security services, and HTTP attendance gateway remain behind feature data adapters.

**Storage**: Current server-backed attendance record remains canonical; new account-scoped durable local check-in outbox is UI-facing source of truth for pending actions; existing `SharedPreferences` offline attendance queue remains only for legacy behavior and is not modified.

**Testing**: `flutter_test` unit/widget tests, architecture/query guards, existing Node test runner, and focused server contract tests for attendance status/receipt behavior.

**Target Platform**: Flutter Android, iOS, and web employee dashboard; existing company gateway runtime.

**Project Type**: Flutter client plus existing Node integration service.

**Performance Goals**: Under normal connectivity, show saved or pending check-in status within 10 seconds; bounded retries add no more than two short waits before a final state; no uncontrolled polling.

**Constraints**: Check-in only; preserve deterministic `{userId}_{Cairo-date}` attendance identity; no production security-rule change, destructive migration, payroll change, or check-out change; no raw infrastructure error reaches presentation; local pending actions never cross employee accounts.

**Scale/Scope**: One employee dashboard action and one new feature vertical slice; one gateway status/receipt contract; no automatic geofence, reminder, HR correction, or historic queue migration.

## Constitution Check

*GATE: Passed before design and re-checked after Phase 1 artifacts.*

| Gate | Status | Evidence / plan |
|---|---|---|
| Strangler Fig delivery | PASS | New `features/attendance_checkin` slice sits beside legacy services; a deliberate pilot switch defaults to legacy. No legacy deletion or reorganization. |
| Layer boundaries | PASS (planned) | Presentation imports only feature domain contracts and presentation-safe core errors. Data owns HTTP/Firebase/local-store adapters; domain is framework independent. Architecture guard gains coverage. |
| Focused Cubits | PASS (planned) | One check-in Cubit owns employee-visible action state only; it delegates persistence, retry/status resolution, and conflict handling to use cases/repositories. It remains under 300 lines. |
| Attendance safety | PASS with characterization first | Current deterministic IDs, location/device validation, late-arrival permission behavior, and queue behavior are characterized before refactoring. Check-out is not touched. |
| Durable offline source of truth | PASS (planned) | New pending check-ins use an account-scoped durable outbox through a local-store interface; existing legacy queue is retained unchanged. |
| Idempotency/conflict | PASS (planned) | Deterministic check-in action ID plus receipt/status lookup resolves retry and interruption outcomes; no silent last-write-wins. |
| Firestore read impact | PASS (planned) | New UI uses the gateway status contract; no new client listeners or unbounded Firestore query. Status checks are event-driven and bounded per action. |
| Irreversible operations | PASS | No production rules, data migration, queue deletion, or rollout are included. |

**Pre-implementation condition**: Record failing characterization tests for the
current check-in action before changing it. If the gateway lacks the required
receipt/status behavior, add it only behind authenticated, actor-owned access
and cover it with Node tests. Do not deploy the switch until the owner approves
a separate rollout decision.

## Project Structure

### Documentation (this feature)

```text
specs/002-attendance-reliability/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── checkin-outcome-contract.md
└── tasks.md                 # Created only after plan review
```

### Source Code (repository root)
```text
lib/
├── core/errors/                         # Existing shared safe-error primitives
├── features/attendance_checkin/
│   ├── data/
│   │   ├── local/                        # Durable account-scoped outbox adapter
│   │   ├── remote/                       # Current gateway adapter and receipt/status mapping
│   │   └── attendance_checkin_repository_impl.dart
│   ├── domain/
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── usecases/
│   └── presentation/
│       ├── cubit/
│       └── widgets/
├── screens/employee/employee_dashboard.dart # Legacy host; selection seam only
└── services/                             # Existing legacy attendance services; unchanged except explicit seam

scripts/
└── attendance-gateway.js                 # Existing authenticated writer; receipt/status extension only

test/
├── features/attendance_checkin/
│   ├── domain/
│   ├── data/
│   └── presentation/
├── architecture_guard_test.dart
└── services/                             # Characterization coverage for current behavior
```

**Structure Decision**: Use one Flutter feature-first vertical slice plus a
minimal authenticated gateway extension. `EmployeeDashboardScreen` remains the
legacy host during the pilot; it may import only the new presentation boundary.
The legacy check-out path and its queue retain their current implementation.

## Complexity Tracking

No constitution violations require an exception.
