# Validation Guide: Web Attendance Access Grants

## Preconditions

- Run against a non-production Firebase project or a designated test employee.
- Use an HR/Super Admin test account, a granted employee account, and an ungranted employee account.
- Configure a valid workday, location, and attendance window for the test date.

## Scenarios

1. Create a dated grant for today through tomorrow. Confirm the employee’s web attendance screen identifies the expiry date and a valid check-in succeeds once.
2. Attempt the same action as an ungranted employee. Confirm the mobile-only message remains and a direct gateway request is denied without a new attendance document.
3. Confirm a granted employee on approved leave, company day off, outside geofence, or outside the time window remains denied by the existing policy.
4. Revoke an active grant while the employee's web screen remains open. Submit a new action and confirm it is denied by the gateway.
5. Create a permanent grant, confirm it has no expiry text, then revoke it and inspect the audit history for actor, timestamps, scope, and revision.
6. Repeat a successful attendance action. Confirm canonical attendance-id idempotency returns the existing receipt rather than creating a duplicate record.

## Required checks

```bash
flutter analyze
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test
(cd scripts && npm test)
```
