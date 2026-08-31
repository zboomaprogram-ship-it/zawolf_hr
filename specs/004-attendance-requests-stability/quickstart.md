# Validation Quickstart: Attendance and Requests Stability

## Safety prerequisites

- Use Firebase/non-production accounts, devices, and locations only.
- Keep check-out disabled unless separately testing existing policy behavior.
- Do not deploy, publish rules, reset production devices, modify live locations,
  or repair historical documents during validation.

## Automated checks

```bash
flutter analyze
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test test/features/attendance_checkin
flutter test test/services
flutter test test/screens
flutter test
(cd scripts && npm test)
```

### Recorded focused verification — 2026-08-20

The following non-production checks passed locally after the Phase 004 changes:

```bash
flutter test -r compact \
  test/services/automatic_attendance_service_test.dart \
  test/services/automatic_attendance_checkin_only_test.dart \
  test/services/attendance_service_regression_test.dart \
  test/features/attendance_checkin \
  test/features/request_visibility \
  test/screens/hr/requests_management_screen_test.dart \
  test/services/employee_deduction_service_test.dart \
  test/services/productivity_service_scope_test.dart \
  test/services/productivity_service_test.dart \
  test/services/kpi_service_test.dart \
  test/services/attendance_device_management_test.dart \
  test/screens/company_location_picker_test.dart \
  test/navigation/guarded_back_policy_test.dart \
  test/navigation/guarded_back_navigation_test.dart \
  test/firestore_query_guard_test.dart \
  test/user_facing_error_test.dart
# Result: 67 tests passed

flutter test -r compact \
  test/services/dashboard_attendance_summary_service_test.dart \
  test/screens/company_location_picker_test.dart
# Result: 8 tests passed

flutter analyze lib/core/errors lib/features/attendance_checkin \
  lib/features/request_visibility lib/navigation \
  lib/screens/hr/employee_mgmt.dart lib/screens/hr/location_mgmt.dart \
  lib/services/attendance_gateway_service.dart \
  lib/services/attendance_period_summary_service.dart \
  lib/services/productivity_service.dart lib/utils/user_facing_error.dart
# Result: no issues found

flutter test -r compact
# Result: 223 tests passed

(cd scripts && node --test test/attendance-gateway.test.js test/checkout-policy.test.js)
# Result: 12 tests passed

(cd scripts && npm test)
# Result: 72 tests passed
```

Non-production manual acceptance and a separate production deployment review
remain required before release.

## Finalization reference

The combined 001–004 delivery status, verified command results, and explicit
release gates are recorded in
[phase-001-to-004-finalization.md](../phase-001-to-004-finalization.md).

## Acceptance matrix

| Scenario | Expected result |
|---|---|
| Manual and automatic check-in | Exactly one daily record; saved/pending safe Arabic result. |
| Duplicate/late automatic event | No second attendance or deduction. |
| Service/network interruption | Pending/status-check, never a technical error. |
| Request submission/approval | Eligible approvers see/advance it; no unauthorized action. |
| Historical deduction tabs | Confirmed/late deduction history is visible and searchable. |
| Tab/search/empty/failure | Records, empty, or retry state; never endless loader. |
| Productivity/KPI fixture | Selected-period totals match inputs; unavailable input identified. |
| Device reset | Old test device rejected, replacement binds, audit exists. |
| Map picker/fallback | Reviewed location saves; map failure preserves current location. |
| Mobile back | Nested routes pop in-app and protect pending/dirty work. |

## Release boundary

All checks and this complete non-production matrix must pass before separate
approval of deployment, Firebase changes, live device/location changes, or any
historic repair.
