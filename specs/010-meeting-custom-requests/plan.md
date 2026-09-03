# Implementation Plan: Meeting, Configurable Requests, and HR Manual Attendance

**Branch**: `010-meeting-custom-requests` | **Date**: 2026-09-03 | **Spec**: [spec.md](spec.md)

## Summary

Add three server-authoritative workflow slices alongside the legacy request screens: manager meeting requests, HR-configured request types, and audited HR manual attendance. Extend the established server-owned field-mission route with searchable recipient selection, and add a controlled HR override for auto-approved casual leave. Every new approval transition uses immutable route snapshots, deterministic operation IDs, durable in-app notifications, and the existing push dispatcher. No legacy request flow is replaced in this increment.

## Technical Context

**Language/Version**: Dart/Flutter (current repository SDK); Node.js/CommonJS Hostinger integration runtime

**Primary Dependencies**: Flutter, flutter_bloc for new feature state, Firebase Auth/Firestore, Hostinger operations API, existing notification dispatcher and approval-routing helpers

**Storage**: Firestore canonical business data; Hostinger writes only through authenticated operations endpoints; existing notification infrastructure

**Testing**: `flutter analyze`; Flutter unit/widget tests; architecture/query guards; Node tests under `scripts/test`; attendance and leave characterization tests before behavior changes

**Target Platform**: Flutter iOS/Android/Web and Hostinger Node runtime

**Project Type**: Mobile/web application with hosted operations API

**Performance Goals**: Meeting submission and approval notification available within 30 seconds; field-mission directory filtering responds within 3 seconds at 500 active employees; manual attendance completes in under one minute

**Constraints**: Cairo business date/time; canonical attendance ID `{userId}_{YYYY-MM-DD}`; deterministic/idempotent write operations; no payroll reopen or automatic deduction mutation from manual attendance; Arabic RTL, mobile, desktop, loading, empty, error, offline/pending states; bounded reusable listeners

**Scale/Scope**: Active employee directory, one meeting manager/room per request, request template audience modes (all, departments, named employees), and approval chains of one to four authorised approvers

## Constitution Check

### Before research — passed

- The feature is incremental: new feature-first slices and server endpoints sit beside legacy request and attendance flows.
- New presentation code depends only on domain contracts and presentation-safe adapters; it will not write Firestore directly.
- Existing request-routing operations, operation receipts, and notification outbox patterns are reused rather than introducing client-owned approval state.
- Attendance and casual-leave behavior are safety-critical. The attendance specification has been read; implementation begins with characterization coverage and preserves canonical IDs, Cairo dates, payroll boundaries, idempotency, and correction semantics.
- Production Firestore-rule deployment is deliberately excluded until a separate owner approval and rollback plan exists. The operations API uses Admin SDK authorization and validation.

### After design — passed with explicit controls

- New state is split into focused Cubits: room/type management, employee submission/history, approval queue, and manual-attendance form/result. No Cubit owns persistence or exceeds the 300-line guard.
- New persistent documents have immutable requester/definition/room snapshots; mutable inventory/configuration does not rewrite history.
- Room collision detection and approval transitions occur in a server transaction, never in a client query.
- The manual-attendance endpoint is the sole new write path. It rejects inactive users, company days off, approved leave, invalid order, and closed payroll; it emits an immutable audit receipt and one notification.
- Listener pages are bounded by requester/current approver/status and use pagination where history can grow.

## Delivery Strategy

1. Characterize existing casual-leave and attendance behavior before changing it. Keep the existing correction process as the only path for closed payroll or already executed dates.
2. Add server modules and operation endpoints with idempotent receipts, authorization, transactions, audit records, and notification outbox writes.
3. Add Firestore document contracts and tests first. Do not deploy rules in this feature without a separately approved rollout/rollback plan.
4. Add Flutter feature slices behind intentional routes/dashboard entry points; leave existing request screens in place while the new pages prove parity.
5. Integrate notification deep links and pending counters only after each queue has server and UI tests.
6. Perform a staged non-production acceptance test using employees/managers created for test data; switch production entry points only after owner review.

## Project Structure

### Documentation

```text
specs/010-meeting-custom-requests/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    └── operations-api.md
```

### Source code

```text
lib/
├── features/
│   ├── meeting_requests/{domain,data,presentation}/
│   ├── configurable_requests/{domain,data,presentation}/
│   └── manual_attendance/{domain,data,presentation}/
├── screens/hr/field_assignments_screen.dart
├── services/leave_service.dart
├── models/notification_route_policy.dart
└── navigation/router.dart

scripts/
├── notification-web.js
├── request-approval-routing.js
├── meeting-requests.js
├── configurable-requests.js
├── manual-attendance.js
└── test/
    ├── meeting-requests.test.js
    ├── configurable-requests.test.js
    └── manual-attendance.test.js

test/
├── features/meeting_requests/
├── features/configurable_requests/
├── features/manual_attendance/
├── attendance_manual_characterization_test.dart
└── casual_leave_override_characterization_test.dart
```

**Structure Decision**: Keep legacy UI/services intact and introduce three small vertical slices under `lib/features`. Each slice owns a domain repository contract, a data implementation that calls only the authenticated Hostinger operations API, and focused Cubits/pages. Node modules own authorization, transactions, receipts, and notifications.

## Implementation Phases

### Phase 0 — Safety baselines

- Add failing characterization tests for current casual automatic approval, leave-balance writes, approval/execution dates, and attendance correction/deduction safeguards.
- Identify the runtime that owns the deployed operations schedule; preserve the existing dispatcher as the only push scheduler.
- Add endpoint contract tests for authorization, idempotency, audit, and Arabic user-facing errors before implementing UI.

### Phase 1 — Server-authoritative workflow foundations

- Extract/reuse the existing `request-approval-routing` transaction, operation-receipt, `approvalRoute`, `approvalHistory`, and queued-notification primitives without changing deployed legacy behavior.
- Add meeting-room lifecycle and booking validation. Seed the three default rooms only if an initial inventory document is absent; never overwrite an HR edit. A single transaction rejects interval overlap against pending or approved reservations.
- Add custom request definition and submission operations. Validate active audience, active authorised approvers, immutable definition snapshots, and sequential decisions.
- Add a conditional casual-leave override operation. It locks only eligible unexecuted/open-cycle leave, retains the auto-approval event in history, and does not repeat balance deductions.
- Add a manual-attendance operation. It uses the canonical attendance document and operation receipt, validates all attendance policy gates, stores source, actor, reason/effective time, audit, and sends one notification. It does not recalculate salary deductions or reopen payroll.

### Phase 2 — Flutter UI slices

- Meeting request pages: manager/room/date/time/reason selection, availability response, employee history, manager decision queue, and HR room management.
- Configurable request pages: HR type management and preview; employee eligible-type list/form; approver queue/history.
- Manual attendance: HR-dashboard entry, searchable employee picker, action, valid time, mandatory reason, confirmation, receipt, and employee-visible audit status.
- Field mission: add normalized Arabic/local search over the bounded HR active-user directory while preserving selected employee IDs. If real use exceeds the listener cap, replace this bridge with a server directory-search endpoint/index in a later reviewed increment.
- Casual leave: surface only the HR control and result. Employee and approver notifications route to existing request history/queue.

### Phase 3 — Integration and acceptance

- Extend notification route policy, supported deep links, and pending counts for meeting/configurable requests. Route employees to their history and approvers to their own queue; do not expose another user's request by URL.
- Add empty/loading/error/offline/pending-success UI states and Arabic RTL widget tests for mobile and wide web.
- Run a full non-production scenario for each user story, duplicate retry, rejected authorization, room collision, cancelled/changed configuration, and manual-attendance policy block.

## Required Verification

```bash
flutter analyze
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test
(cd scripts && npm test)
```

Additionally, the release checklist must prove: no direct presentation-to-data imports; no unbounded employee query in non-HR screens; exact-once notification IDs for every transition; and a documented, owner-approved rules rollout and rollback plan before any rules deployment.

## Complexity Tracking

| Decision | Why needed | Simpler alternative rejected because |
|---|---|---|
| Three feature slices plus Hostinger modules | Meeting, configurable workflows, and attendance have distinct permissions and failure rules | One giant request page/service would mix attendance policy, configuration, and approval state |
| Server-owned operations | Requires race-free bookings, secure approvals, idempotency, and audited manual attendance | Client Firestore writes cannot safely enforce all cross-document/policy conditions |
| Immutable snapshots and receipts | HR can edit rooms/types/users after a request begins | Reading live configuration would rewrite historical meaning and break retries |
