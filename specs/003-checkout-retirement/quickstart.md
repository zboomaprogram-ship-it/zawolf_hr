# Acceptance Quickstart: Check-out Policy Control

Use test users and non-production data. Do not enable or migrate production
policy as part of this checklist.

## Characterization baseline

Recorded on 2026-08-20 before check-out policy implementation:

```bash
flutter test test/attendance_policy_config_test.dart
cd scripts && npm test -- --test-name-pattern="legacy|attendance reminders|automatic attendance"
```

Results: Flutter focused suite passed (6 tests). The Node test command passed
(61 tests); the Node test runner executed the complete existing suite in this
repository. These tests characterize the existing checkout boundary, gateway,
reminder, automatic-attendance, and daily missed-checkout producer behavior.

## Latest implementation verification

Recorded on 2026-08-20 after the policy gateway, HR control, worker guards,
and payroll-history safeguards were added:

```bash
flutter analyze lib/screens/hr/hr_dashboard.dart lib/services/attendance_service.dart lib/features/checkout_policy
flutter test test/checkout_policy_inventory_test.dart test/permission_cycle_accounting_test.dart test/features/checkout_policy/domain/checkout_policy_test.dart test/features/attendance_checkin/presentation/attendance_outcome_mapper_test.dart test/architecture_guard_test.dart
(cd scripts && npm test)
```

Results: static analysis passed; the focused Flutter suite passed; the Node
suite passed (69 tests). This is non-production evidence only.

Additional US1/US3 verification recorded on 2026-08-20:

```bash
flutter analyze lib/services/permission_service.dart lib/services/hr_direct_request_service.dart lib/services/offline_attendance_queue_service.dart
flutter test test/leave_request_policy_test.dart test/request_approval_policy_test.dart test/permission_cycle_accounting_test.dart test/services/attendance_reconciliation_service_test.dart test/services/offline_attendance_queue_service_checkout_policy_test.dart
```

Results: static analysis passed; 23 focused Flutter tests passed. This confirms
that permissions remain independent of check-out policy, a late approval stays
in the request-date payroll cycle, and a queued disabled check-out is terminal
with no device-side Firestore fallback.

Additional HR policy/reporting verification recorded on 2026-08-20:

```bash
flutter analyze lib/services/attendance_gateway_service.dart lib/models/attendance_model.dart lib/services/dashboard_attendance_summary_service.dart lib/screens/hr/attendance_summary_details_screen.dart lib/services/sheets_export_service.dart lib/screens/manager/team_attendance.dart lib/screens/manager/requests_mgmt.dart
flutter test test/screens/hr/hr_dashboard_checkout_policy_test.dart test/screens/employee/employee_dashboard_checkout_policy_test.dart test/features/checkout_policy/data/checkout_policy_controller_test.dart test/features/attendance_checkin/presentation/attendance_outcome_mapper_test.dart test/services/dashboard_attendance_summary_service_test.dart test/services/sheets_export_service_checkout_policy_test.dart
```

Results: static analysis passed. The dashboard/controller/reporting test suite
passed after correcting the employee dashboard assertion to the actual
check-in-only state label (`تم تسجيل الحضور`). Disabled records now retain a
policy snapshot in the authorized attendance export and render as
`لا ينطبق تسجيل الانصراف (سياسة HR)` instead of a missing checkout.

The complete Node worker suite was also run on 2026-08-20 with `cd scripts &&
npm test`: **70 tests passed**. No deployment, worker upload, policy toggle,
Firebase rules publication, or data migration was performed.

The complete Flutter suite was also run on 2026-08-20 with
`flutter test --reporter compact`: **178 tests passed**. This remains
non-production verification; run the acceptance flow below with dedicated test
accounts before any production release.

1. As normal HR, open the HR dashboard; confirm check-out is **disabled**.
2. As an employee, confirm check-in is available and no check-out action,
   timing prompt, or reminder is shown.
3. Submit official leave, late-arrival, and early-leave requests; confirm all
   use the ordinary approval chain.
4. Approve early leave while disabled and process the day; confirm no check-out
   record, missed-check-out review, reminder, or deduction exists.
5. Send a stale/queued `checkOut` after disablement; confirm concise Arabic
   guidance and no mutation.
6. Enable check-out as HR with a reason; confirm one audit event and prospective
   employee check-out availability after refresh.
7. Disable it while an employee is checked in; confirm future actions and
   scheduled work are suppressed and historic data stays unchanged.
8. In HR/payroll history, confirm disabled periods say check-out does not apply,
   not “missing check-out”.
