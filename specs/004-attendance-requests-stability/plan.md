# Implementation Plan: Attendance and Requests Stability

**Branch**: `004-attendance-requests-stability` | **Date**: 2026-08-20 | **Spec**: [spec.md](spec.md)

## Summary

Stabilize employee check-in and HR/manager/admin request operations before any
Company Workspace work. Extend the existing reliable check-in boundary to
automatic location events; add a bounded role-scoped request visibility model;
make approval/device-reset mutations server-authoritative and auditable; correct
productivity/KPI input selection; harden map fallback; and standardize safe
mobile back navigation. It also normalizes salary-deduction explanations for
employees, including incomplete legacy history, without recalculating payroll.
The completed default-off check-out policy remains in force.

## Technical Context

**Language/Version**: Dart/Flutter and Node.js existing gateway.

**Primary Dependencies**: Firebase Auth/Firestore, `google_maps_flutter`,
`geolocator`, native method channels, local check-in outbox, Node Admin SDK.

**Storage**: Firestore is canonical; the existing account-scoped local check-in
outbox is the UI source of truth for pending check-ins.

**Testing**: `flutter_test`, architecture/query guards, focused service/screen
tests, existing Node test runner.

**Target Platform**: Flutter Android, iOS, web, and Node integration runtime.

**Project Type**: Flutter client plus Node integration service.

**Performance Goals**: Request tabs resolve to records, empty, or retry within
10 seconds under normal connectivity; bounded queries; no new polling/listener
amplification.

**Constraints**: Automatic check-in only; preserve Cairo identity and check-out
snapshots; safe Arabic errors only; no deployment, rules/config change, data
migration, device/location reset, or payroll recalculation.

**Scale/Scope**: Existing attendance/request/productivity/device/location and
navigation screens. Company Workspace/Google Workspace are deferred.

## Constitution Check

*Passed before research and re-checked after design.*

| Gate | Status | Evidence / planned control |
|---|---|---|
| Strangler Fig delivery | PASS | Extend the existing reliable check-in slice; no legacy deletion or bulk move. |
| Layer boundaries | PASS | Presentation uses safe state/contracts; adapters own Firebase/HTTP/storage. |
| Focused Cubits | PASS | Screen state stays limited to tab loading/search or guarded navigation. |
| Attendance/payroll safety | PASS | Characterize Cairo identity, approvals, historic deductions, and check-out snapshot behavior first. |
| Test-first delivery | PASS | Contract and regression tests precede each route/mutation change. |
| Firestore read budget | PASS | Role/date/status-bounded reads, pagination, cached ownership, no polling. |
| Irreversible operations | PASS | Live rule/config/device/location/history changes remain separately authorized. |

## Project Structure

```text
specs/004-attendance-requests-stability/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── attendance-request-read-model.md
│   └── attendance-device-location-contract.md
└── tasks.md                 # created after plan approval

lib/
├── core/errors/
├── features/attendance_checkin/
├── services/                # attendance, request, productivity adapters
├── screens/employee/
├── screens/manager/
├── screens/hr/
└── navigation/

scripts/
├── attendance-gateway.js
├── notification-web.js
└── test/

test/
├── features/attendance_checkin/
├── services/
├── screens/
└── architecture/query guards
```

**Structure Decision**: Keep the current layout. Introduce contracts and
bounded read-model adapters alongside legacy services. A changed screen must
own one stable, bounded source rather than construct new Firestore streams
inside `build`.

## Complexity Tracking

No constitution exception is needed. Historical data is normalized only for
display; no destructive repair or payroll rewrite is included.
