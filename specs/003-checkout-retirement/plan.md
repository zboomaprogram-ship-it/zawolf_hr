# Implementation Plan: Check-out Policy Control

**Feature**: `003-checkout-retirement`
**Spec**: [spec.md](spec.md)
**Status**: Ready for owner review
**Date**: 2026-08-20

## Technical Context

| Area | Current implementation |
|---|---|
| Client | Flutter/Dart web and mobile application |
| Attendance authority | Node.js Hostinger notification service plus Firebase Admin SDK |
| Data | Cloud Firestore (`attendance`, `users`, `publicConfig`, requests, deductions) |
| Existing policy document | `publicConfig/appSecurity` is already read by mobile, web, and server attendance paths |
| Background paths | automatic attendance, attendance reminders, notification dispatch, and daily payroll processing |
| Time zone | `Africa/Cairo` |

## Design Decisions

### 1. One server-authoritative check-out policy

Store the current policy and immutable history under a dedicated configuration
area. The default when the document is missing, unreadable, or malformed is
**disabled**. The client may use a cached value only for presentation; the
attendance gateway and scheduled jobs are the authority that decides whether a
write or consequence is allowed.

The policy shall contain a monotonic revision and server timestamp. An
authorized HR change uses one server transaction that reads the current
revision, confirms role, writes the next value, and appends exactly one
immutable audit event. This prevents two HR users from creating ambiguous state.

### 2. Explicit policy evaluation point

Every check-out-only decision stores the policy revision and effective value it
used. A manual, automatic, or queued check-out is evaluated at the server's
receipt time. A reminder is evaluated immediately before it is enqueued. A
daily deduction/reconciliation is evaluated against the policy state at the
decision's documented attendance cutoff, not against a later current value.

This prevents later enablement from creating deductions for disabled periods and
prevents later disablement from rewriting approved payroll evidence.

### 3. Permissions stay independent

Official leave, late-arrival, and early-leave requests retain the existing
approval chain in every policy state. When check-out is disabled, approving an
early-leave permission authorizes departure only. It must not create a
check-out record, a reminder, a review, or a deduction.

### 4. Disabled is a safe no-op for check-out

The employee UI hides all check-out UI when disabled. Stale clients and queued
requests still reach the gateway, which returns a stable Arabic
`checkout_disabled` result without changing attendance, deductions, payroll,
approvals, or notifications. Background workers mark obsolete queue work as
suppressed/ignored with the policy snapshot; they do not retry it.

### 5. No raw Firebase error to employees

The client maps gateway/network failures to existing safe Arabic attendance
states. The policy-disabled outcome is a normal business state, not an error.
Technical details remain only in structured logs for authorized support staff.

## Implementation Phases

### Phase A — Contract and shared policy service

1. Add a versioned, default-off `CheckoutPolicy` model and repository in the
   attendance domain.
2. Define roles using existing role normalization; do not hard-code an employee
   code. Allow normal HR and existing super-admin oversight only.
3. Add server handlers to read and change policy, with ID-token authentication,
   transactional revision control, optional reason, and audit event creation.
4. Extend the attendance gateway response contract with typed
   `checkout_disabled` and an applied policy snapshot.

### Phase B — HR control and employee experience

1. Add an HR-dashboard card showing enabled/disabled, effective time, last
   authorized change, and a confirmation flow for enable/disable.
2. Render check-in-only attendance when off. Remove check-out timing hints,
   buttons, pending labels, and confirmation paths; leave requests untouched.
3. Keep early-leave selectable in `employee_requests.dart` regardless of policy
   and show an Arabic explanation that it authorizes leaving without check-out
   when the policy is off.
4. Ensure employees see saved/pending-safe/request-status messages rather than
   Firestore or transport exception text.

### Phase C — Enforce all server and background paths

1. Enforce policy in `scripts/attendance-gateway.js` before device binding or
   attendance mutation for `checkOut` actions.
2. Make the Flutter offline queue request the gateway and mark a disabled
   check-out as terminal, without a local direct Firestore fallback.
3. Suppress check-out automation in `scripts/auto-attendance.js`, check-out
   reminder enqueueing in `scripts/attendance-reminders.js`, and delivery
   revalidation in `scripts/dispatch-notifications.js`.
4. Update `scripts/daily-tasks.js` and client reconciliation so missed-/early-
   check-out deductions, reviews, and notifications are skipped during disabled
   policy intervals. Preserve prior records exactly as written.
5. Apply the same guard to direct/manual HR operations, reports, exports, and
   approval routes that could otherwise create a new check-out-only consequence.

### Phase D — Reporting and audit

1. Display applied policy state and revision for authorized HR/payroll views.
2. Label disabled-period attendance as “لا ينطبق تسجيل الانصراف” rather than
   “missing check-out”.
3. Expose ordered policy-change audit history only to authorized HR/super-admin
   users, without exposing credentials or unrelated employee data.

### Phase E — Characterization and acceptance tests

Before changing legacy attendance/payroll behavior, add characterization tests
for existing deductions and early-leave reconciliation. Then cover default-off,
authorization, toggle races, stale/manual/automatic/queued actions, reminders,
daily reruns, early leave, late arrival, official leave, and history.

## Likely Change Areas

| Area | Primary files to inspect/change |
|---|---|
| Policy/client model | `lib/services/app_security_policy_service.dart` or dedicated checkout-policy service; new domain model/repository if needed |
| HR switch | `lib/screens/hr/hr_dashboard.dart` |
| Employee attendance | `lib/screens/employee/employee_dashboard.dart`, `lib/services/attendance_service.dart`, `lib/services/attendance_gateway_service.dart` |
| Requests | `lib/screens/employee/employee_requests.dart`, permission and approval services |
| Offline/reconciliation | `lib/services/offline_attendance_queue_service.dart`, `lib/services/attendance_reconciliation_service.dart` |
| Server authority | `scripts/attendance-gateway.js`, `scripts/notification-web.js` |
| Workers | `scripts/auto-attendance.js`, `scripts/attendance-reminders.js`, `scripts/dispatch-notifications.js`, `scripts/daily-tasks.js` |
| Views/exports | HR/manager attendance/deduction screens and `lib/services/sheets_export_service.dart` |

## Verification Strategy

- Run current Flutter and Node characterization tests before behavior changes.
- Add focused unit tests for policy resolution, role authorization, policy
  snapshot selection, and Arabic outcome mapping.
- Add HTTP/worker tests with a fake Firestore/Admin boundary proving disabled
  policy produces zero check-out writes and zero deduction/notification jobs.
- Add Flutter widget tests proving check-out controls disappear while official
  leave and both permissions remain available.
- Manually test a policy transition on non-production data before live use.

## Safety Boundaries

- No deletion, recalculation, or automatic repair of historical attendance,
  deductions, approvals, payroll, or notifications.
- No production Firestore-rule changes, data migration, deployment, or policy
  activation is included; each needs a separate owner approval.
- The default remains disabled if policy lookup fails, but check-in and request
  submission continue through their existing safe paths.

## Role and Operations Handoff

- **Normal HR and super-admin**: may view the policy state; only the server
  authorizes a revisioned change and writes the immutable policy event. The
  control is deliberately unavailable to employees and ordinary managers.
- **Employees**: can always check in and submit official leave, late-arrival,
  and early-leave permissions. With policy disabled, the dashboard ends the
  attendance action after check-in; early leave remains an approval request,
  not a check-out action.
- **Managers and HR reviewers**: may see the historical policy snapshot on an
  attendance/deduction record. A `false` snapshot means “لا ينطبق تسجيل
  الانصراف”; it must not be relabelled as a missing checkout or recalculated.
- **Operations before deployment**: run the focused Flutter and Node commands
  in `quickstart.md`, then complete its non-production checklist with a normal
  HR account and a test employee. Keep the policy disabled during this work.
- **Deployment boundary**: publishing the Flutter web build, uploading the
  Hostinger worker, changing Firebase rules, changing environment variables,
  toggling the policy, or migrating historic data each require separate owner
  approval. None is performed by this implementation plan.
