# Attendance Device and Location Contract

## Automatic check-in

```text
AutomaticCheckInEvent {
  actionId, attendanceId, employeeScopeId, capturedAt,
  source: automatic_location, validatedLocationEvidence,
  validatedDeviceEvidence
}
```

The authority accepts only an authenticated owner with valid Cairo date,
opt-in/policy, location/device evidence, and no previous check-in. It returns
the same semantic receipt/status as manual check-in.

## Device reset

```text
AttendanceDeviceReset { employeeScopeId, expectedBindingRevision, reason }
```

Authorized HR/IT only. The authority invalidates the active binding atomically,
records immutable audit data, and never changes historical attendance.

## Location update

```text
AttendanceLocationSelection {
  locationId, latitude, longitude, radiusMeters,
  selectionMethod: map | reviewed_coordinates, expectedRevision
}
```

Map failure must not erase the current location; reviewed-coordinate fallback
uses the same authorization and validation.

## Guarded navigation

`BackNavigationState = idle | pendingMutation | pendingSynchronization |
dirtyForm`. Non-root routes return in-app first; protected states request
confirmation before discarding form state and do not interrupt active sync.
