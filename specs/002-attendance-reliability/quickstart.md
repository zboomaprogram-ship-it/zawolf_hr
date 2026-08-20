# Validation Quickstart: Check-in Reliability Pilot

## Prerequisites

- Use a non-production test account with valid attendance policy, location,
  and device prerequisites.
- Keep the pilot switch disabled by default until parity verification is
  complete; enable it only for the designated test cohort through the reviewed
  selection mechanism.
- Do not modify production access rules, attendance records, payroll cycles,
  or the legacy check-out flow during validation.

## Automated checks

Run after implementation and after any final change:

```bash
flutter analyze
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test test/features/attendance_checkin
flutter test
(cd scripts && npm test)
```

Latest gateway and safe-outcome regression evidence (2026-08-20): the focused
Flutter architecture/safe-message suite passed and `(cd scripts && npm test)`
passed with 70 Node tests. The default-off pilot seam and its end-to-end
dashboard validation are still required before any employee cohort can use the
new check-in path.

Release-evidence update (2026-08-20): `flutter analyze` completed with no
issues; the architecture/query-guard suite passed; the attendance-check-in
feature suite passed; and the complete `flutter test --reporter compact` suite
passed with **178 tests**. These are automated, non-production checks only.

## Pilot enable, disable, and rollback

The new path is **off unless an explicit build-time Firebase UID is supplied**.
For a non-production test build only:

```bash
flutter run --dart-define=ATTENDANCE_CHECKIN_PILOT_USER_ID=<firebase-user-uid>
```

- Use the Firebase Auth UID, not an email, employee code, or role.
- Only that exact employee's manual **check-in** uses the pilot; every other
  employee and every check-out remains on the legacy path.
- To disable the pilot, rebuild without the define. New check-ins immediately
  return to legacy behavior; no attendance record, payroll data, or pending
  pilot action is deleted.
- Pending pilot actions remain locally scoped to their original authenticated
  account. Re-enable the same non-production UID only when testing explicit
  synchronization/status checking.

## Payload parity

The pilot receives the already validated legacy `OfflineAttendanceAction`.
It preserves the canonical Cairo attendance ID/date and original captured time,
then forwards the same serialized evidence to the existing gateway:

| Evidence preserved | Source in existing check-in flow |
|---|---|
| `attendanceId`, `date`, `eventTime` | canonical Cairo daily record |
| latitude, longitude, distance, accuracy, allowed radius | geofence validation |
| device ID/label and biometric confirmation | device-security validation |
| late minutes, status, deduction fields and currency | existing attendance policy |
| location risk and security-review status | existing risk policy |

The pilot does not compute salary, permission, payroll-cycle, or checkout
rules. Those remain in the existing attendance service and gateway.

## Acceptance scenarios

| Scenario | Setup | Expected result |
|---|---|---|
| Saved check-in | Eligible employee, normal connectivity. | One canonical check-in and Arabic saved state. |
| Duplicate check-in | Submit same daily action twice or replay it. | One attendance record; final state saved/already recorded. |
| Offline before submit | Disable network after valid evidence capture. | Original action persists as pending sync; Arabic pending state; no raw error. |
| Temporary interruption | Fail the delivery path after submission begins. | At most bounded retries; final state is saved, pending sync, or needs status check—never false success. |
| Interrupted submission | Simulate missing confirmation after service receives action. | Status resolution identifies the existing check-in before another submission. |
| Access denied | Return confirmed denied result. | Arabic responsible-team guidance; no retry/outbox item. |
| Session expired | Return invalid-session result. | Arabic sign-in guidance; no retry/outbox item. |
| Invalid validation | Use invalid location/device/time. | Arabic corrective guidance; no retry/outbox item. |
| Account switch | Create pending item, sign out, sign into another employee. | New employee cannot view or submit the first employee’s pending action. |
| Check-out regression | Execute legacy check-out with pilot enabled for check-in. | Existing check-out behavior remains unchanged. |

## Rollout and rollback evidence

1. Capture parity test results for check-in policy and gateway receipts.
2. Enable only the approved pilot cohort; monitor saved/pending/status-check
   counts and support reports without recording raw employee diagnostics.
3. Roll back by disabling the pilot selection seam; this returns new check-ins
   to the legacy path without deleting pending pilot items or historical
   attendance records.
4. Do not make the pilot default or retire legacy code without a new owner
   approval after production verification.
