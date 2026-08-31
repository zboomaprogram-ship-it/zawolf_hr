# Contract: Multiple Attendance Locations

## Assignment operations

- `GET /attendance/locations/assignments/me`
- `GET /attendance/locations/assignments?employeeUid&limit&cursor`
- `POST /attendance/locations/assignments/preview`
- `POST /attendance/locations/assignments/apply`
- `GET /attendance/locations/operations/:operationId`

## Check-in action addition

The current attendance action retains its deterministic `attendanceId` and adds:

```json
{
  "locationId": "assigned-location-id",
  "assignmentId": "uid_location-id",
  "assignmentVersion": 3,
  "latitude": 30.0,
  "longitude": 31.0,
  "accuracyMeters": 9,
  "distanceMeters": 14,
  "allowedRadius": 50
}
```

The server loads the assignment and location, checks effective dates and active
states, recalculates distance, then returns the existing semantic outcomes plus
`assignment_changed` when a stale offline assignment requires status checking.

