# Implementation Plan: Multiple Attendance Locations

**Branch**: `009-multi-location-attendance` | **Date**: 2026-08-24 | **Spec**: [spec.md](spec.md)

## Summary

Add effective-dated employee-to-location assignments beside the existing
`users.locationId` path. Manual and automatic check-in validate any assigned site,
choose a deterministic nearest match, and submit its evidence to an authenticated
gateway that performs final server-side validation. The rollout remains disabled
by default with single-location fallback and non-destructive migration.

## Technical Context

**Language/Version**: Dart 3.9 / Flutter 3.x; Android Kotlin; iOS Swift; Node.js  
**Dependencies**: Geolocator, Firebase Auth, BLoC/Cubit, Drift/outbox, Admin SDK  
**Storage**: Firestore canonical locations/assignments/attendance; local bounded cache  
**Testing**: flutter_test, Node tests, platform registration tests, query guards  
**Constraints**: Cairo time, deterministic attendance IDs, anti-mock/device checks,
check-in-only automatic attendance, no deduction/payroll behavior change, no rule change

## Constitution Check

- **Strangler Fig**: PASS — `attendance_multi_location_v1` selects the new matcher.
- **Layer boundaries**: PASS — new domain matcher and assignment repository contracts.
- **Focused Cubits**: PASS — HR assignment state is separate from employee check-in state.
- **Attendance safety**: PASS — current behavior is characterized before any change;
  server revalidation, deterministic IDs, and retry semantics are preserved.
- **Test first**: PASS — single-location, offline, auto-entry, and duplicate behavior first.
- **Offline/sync**: PASS — local action retains evidence and server checks current authority.

## Architecture

```text
HR location assignment UI -> authenticated assignment API -> assignments + audit

Employee position -> domain nearest-match policy -> check-in outbox/gateway
                                               -> server assignment/geofence validation
                                               -> canonical attendance record

Platform geofence enter -> auto signal -> server assignment validation -> same record
```

No check-in scans all company sites. The client loads a bounded assigned-location
projection; the server resolves the referenced assignment/location directly. The
legacy `locationId` remains populated for old clients until retirement is reviewed.

## Project Structure

```text
lib/features/attendance_checkin/{data,domain,presentation}/
lib/features/attendance_locations/{data,domain,presentation}/
android/app/src/main/kotlin/.../
ios/Runner/
scripts/attendance-gateway.js
scripts/auto-attendance.js
test/features/attendance_checkin/
test/features/attendance_locations/
scripts/test/
specs/009-multi-location-attendance/
```

## Migration and Rollout

1. Characterize single-location manual, offline, and automatic check-in.
2. Add assignment/matching contracts and server validation.
3. Migrate each legacy `locationId` to one assignment via dry run and confirmed apply.
4. Add HR assignment UI and employee bounded matcher behind the flag.
5. Run non-production location/device/role/race matrix.
6. Pilot employees with two locations; monitor latency, rejection reasons, duplicates, and reads.
7. Owner-approved default switch; legacy retirement remains a separate change.

No constitution exception is required.

