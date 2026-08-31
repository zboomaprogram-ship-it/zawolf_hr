# Data Model: Multiple Attendance Locations

## AttendanceLocation

- Existing stable `id`, `name`, `latitude`, `longitude`, `geofenceRadiusMeters`
- `isActive`, `timezone`, `version`, audit timestamps

## EmployeeAttendanceLocationAssignment

- `id = employeeUid_locationId`
- `employeeUid`, `locationId`, `status`, `effectiveFrom`, `effectiveTo?`
- `priority`, `isDefault`, `version`, `createdBy`, audit timestamps
- Only one optional active default assignment exists per employee.

## LocationMatchEvidence

- `assignmentId`, `assignmentVersion`, `locationId`, `locationName`
- captured latitude/longitude/accuracy, calculated distance/radius
- event time, source, mocked flag, selection reason

## Invariants

1. An active assignment references an active employee and existing location.
2. Check-in accepts only an assignment effective at the event's Cairo time.
3. Matching chooses nearest distance, then stable location ID.
4. The attendance record identity stays `{uid}_{date}` independent of location.
5. Assignment removal never changes historical attendance evidence.

