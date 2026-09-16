# Implementation Plan: Pending Early-Leave Checkout

**Branch**: `main` | **Date**: 2026-09-16 | **Spec**: [spec.md](spec.md)

**Input**: Approved feature specification from `specs/015-pending-early-leave/spec.md`

## Summary

Allow a checked-in employee to check out at the requested early-leave time while
the request is pending or rejected, with a clear Arabic warning showing the exact
possible deduction. The mobile client will watch a focused early-leave read model,
but the Hostinger attendance gateway will re-read the request and schedule before
accepting checkout. The gateway records immutable request evidence on the
attendance row. If the request is rejected and the early checkout was used, an
idempotent reconciliation writes one nested `rejectionConsequence` on the
permission for HR review. Payroll and discipline include that consequence only
after HR approval. A bounded recovery worker repairs a missed decision callback.

## Technical Context

**Language/Version**: Dart 3 / Flutter; Node.js 22 on Hostinger

**Primary Dependencies**: Flutter BLoC, Cloud Firestore, Firebase Auth/Admin, existing Hostinger HTTP runtime

**Storage**: Firestore (`permissions`, `attendance`, `notifications`); existing local attendance outbox for offline replay

**Testing**: `flutter_test`, architecture/query guards, Node `node:test`, Firebase emulator/fakes where already available

**Target Platform**: Android and iOS Flutter clients; Flutter web remains compatible; Hostinger Linux Node runtime

**Project Type**: Cross-platform Flutter application plus Node integration API and scheduled worker

**Performance Goals**: Checkout availability and decision-state changes visible within 5 seconds; one bounded same-day permission listener per open employee dashboard; no unbounded worker scans

**Constraints**: Africa/Cairo execution date; 26–25 payroll cycle; one-to-four whole request hours; checkout policy remains authoritative; offline replay preserves original event time; finalized cycles are not reopened; no production rule deployment or backfill in this increment

**Scale/Scope**: Current company tenant and active employees; at most a few same-day permission documents per employee; one attendance row per user/date; existing HR deduction-review audience

## Constitution Check

*GATE: Passed before research and re-checked after design.*

- **Strangler Fig**: PASS. A focused feature slice and gateway helper are added
  beside legacy services. Existing approved-permission and scheduled-end flows
  remain the default outside this exact case.
- **Layer boundaries**: PASS. New domain policy is framework-free; presentation
  imports domain contracts only; Firestore and HTTP implementations stay in data
  and integration layers.
- **Focused Cubit**: PASS. One Cubit owns the early-leave hint/eligibility view
  state and performs no persistence. It must remain under 300 lines.
- **Attendance/payroll safety**: PASS. The existing specifications were reviewed.
  The design preserves execution-date attribution, deterministic identity,
  pending-HR governance, checkout policy, and closed-cycle behavior.
- **Test-first delivery**: PASS. Characterization tests precede service changes;
  owner approved the specification. This plan stops for owner review before task
  generation or implementation.
- **Offline/conflict state**: PASS. The client remains advisory; the server
  revalidates request and event time. Retries converge using the permission ID,
  attendance ID, and checkout event identity.
- **Scheduled ownership/read budget**: PASS. Hostinger remains the single live
  reconciliation owner. The recovery query is bounded by explicit pending marker
  and recent update time; GitHub is recovery only.
- **Arabic RTL/mobile/web**: PASS. The confirmation and deduction details require
  Arabic RTL states; web consumes the same read model but attendance access rules
  are unchanged.
- **Irreversible operations**: PASS. No destructive migration, cycle reopening,
  or rule deployment is included. New fields are additive and ignored by old
  clients. Rollback disables the feature flag and worker, preserving evidence.

## Project Structure

### Documentation (this feature)

```text
specs/015-pending-early-leave/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── early-leave-checkout-api.md
└── tasks.md             # created only after plan approval
```

### Source Code (repository root)

```text
lib/features/pending_early_leave/
├── data/
│   ├── early_leave_checkout_repository_impl.dart
│   └── early_leave_checkout_wire_model.dart
├── domain/
│   ├── early_leave_checkout_eligibility.dart
│   ├── early_leave_checkout_repository.dart
│   └── early_leave_deduction_policy.dart
└── presentation/
    ├── early_leave_checkout_cubit.dart
    ├── early_leave_checkout_state.dart
    └── early_leave_checkout_hint.dart

lib/screens/employee/
├── employee_dashboard.dart                 # integration seam only
└── checkin_confirm_modal.dart               # renders the new warning

scripts/
├── attendance-gateway.js                   # authoritative validation/evidence
├── early-leave-reconciliation.js           # idempotent consequence projector
├── notification-web.js                     # endpoint and bounded worker wiring
├── monthly-tasks.js                         # approved consequence payroll input
└── test/
    ├── attendance-gateway.test.js
    ├── early-leave-reconciliation.test.js
    └── monthly-tasks.test.js

test/features/pending_early_leave/
├── early_leave_deduction_policy_test.dart
├── early_leave_checkout_cubit_test.dart
└── early_leave_checkout_repository_test.dart

test/screens/employee/
└── employee_dashboard_gate_test.dart
```

**Structure Decision**: Use a new feature-first vertical slice for the read
model, domain calculation, and UI state. Integrate it through the existing
employee dashboard without moving unrelated legacy code. Put server authority
in focused CommonJS modules used by the current Hostinger entry point. Keep
payroll compatibility changes narrow and additive.

## Implementation Phases

1. **Characterize current behavior**: Lock down scheduled checkout, approved
   early leave, rejected requests, existing attendance deductions, offline
   replay, payroll filtering, and HR review behavior with failing tests for the
   new pending/rejected cases.
2. **Add the read slice behind a feature flag**: Resolve the exact same-day
   request and expose its state, requested time, and warning fraction without
   changing checkout authority.
3. **Make checkout authoritative**: Extend the attendance action contract with
   a request ID, re-read the request/schedule in the gateway, and atomically
   store evidence with checkout. Reject altered, cross-user, cross-date, or
   too-early events.
4. **Project rejection consequences**: Reconcile both orderings—checkout before
   rejection and rejection before checkout—into one nested consequence. Mark a
   bounded repair request if the immediate callback fails.
5. **Integrate HR review and payroll**: Show this consequence in the existing HR
   deduction queue and employee details. Only an HR-approved consequence enters
   discipline and both Dart and Node payroll calculations.
6. **Observe and switch**: Ship disabled, deploy backend, enable for test users,
   verify audit logs and replay tests, then enable broadly. Roll back by turning
   the flag off; evidence and review records remain auditable.

## Complexity Tracking

No constitution violations require an exception.
