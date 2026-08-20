# Research: Check-out Policy Control

## Server is authoritative

**Decision**: The attendance gateway and scheduled Node workers enforce the
policy; Flutter only reflects it in the UI.

**Why**: Existing check-out mutations are possible through manual actions,
offline queue replay, automatic attendance, reminders, and daily jobs. A UI-only
toggle cannot prevent stale clients or workers from creating deductions.

## Default to off on uncertainty

**Decision**: Missing or invalid policy evaluates to disabled for check-out-only
work.

**Why**: The owner requires check-out off by default and a failed configuration
lookup must not create a payroll consequence. This does not block check-in,
leave, late-arrival, or early-leave requests.

## Snapshot decisions; never recalculate history

**Decision**: New check-out-only actions and consequences store the policy
revision/effective state used. Historic records are not recomputed from the
current toggle.

**Why**: A late approval or later policy change must not move a deduction to a
different payroll period or alter approved evidence.

## Early leave is independent

**Decision**: Early-leave permission remains requestable and approvable. When
check-out is off it authorizes leaving; it is not a synthetic checkout.

**Why**: This honors the business policy and avoids false missing-check-out or
early-check-out deductions.

## No direct-write bypass

**Decision**: Audit client and worker paths and gate each new check-out write at
a shared authority.

**Why**: `attendance-gateway.js`, the offline queue, automatic attendance,
reminders, and daily tasks all contain check-out behavior.

## Current check-out path inventory (2026-08-20)

This inventory is a characterization boundary, not a statement that these paths
are correct. Each producer or consumer below must use the shared policy before
the feature is activated.

| Path | Current behavior | Required policy boundary |
|---|---|---|
| `lib/screens/employee/employee_dashboard.dart` | Shows check-out action, time gate, confirmation, and historical display | Hide future-action UI while disabled; retain history |
| `lib/services/attendance_service.dart` | Selects check-in/check-out, derives checkout deductions, and invokes queue work | Do not initiate new check-out-only work while disabled |
| `lib/services/attendance_gateway_service.dart` | Sends employee attendance actions to the Node gateway | Map `checkout_disabled` to safe Arabic state |
| `lib/services/offline_attendance_queue_service.dart` | Replays queued check-in/check-out work and contains legacy write fields | Treat disabled check-out as terminal; no direct-write bypass |
| `scripts/attendance-gateway.js` | Validates, binds device, and writes check-out fields | Evaluate before device binding and attendance mutation |
| `scripts/auto-attendance.js` | Converts eligible signals into automatic check-out records | Suppress/resolve signals without attendance mutation |
| `scripts/attendance-reminders.js` | Plans and queues check-out reminders | Do not plan or enqueue check-out reminders |
| `scripts/dispatch-notifications.js` | Revalidates/dispatches queued check-out reminders | Suppress stale queued reminders before delivery |
| `scripts/daily-tasks.js` | Creates missed-/early-checkout deductions and HR review notifications | Evaluate policy at documented attendance cutoff; do not create new consequences while disabled |
| `lib/services/attendance_reconciliation_service.dart` | Clears approved early-leave deductions when a checkout exists | Early leave stays approvable but creates no checkout-only reconciliation while disabled |
| `lib/services/dashboard_attendance_summary_service.dart` and HR/manager views | Present attendance/check-out information | Display disabled periods as not applicable rather than missing checkout |
| `lib/services/sheets_export_service.dart` | Exports attendance and permission information | Include policy context and avoid false missing-checkout labels |

## HR control without hard-coded employees

**Decision**: Existing normal HR can operate the toggle; super-admin users keep
oversight. Employee codes are never authority criteria.
