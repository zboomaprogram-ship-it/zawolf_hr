# Research: Multiple Attendance Locations

## Decisions

### Managed assignments, not employee-created geofences

Self-authorized attendance locations would defeat location controls. Employees use
multiple locations assigned by an HR/Admin capability; requests for new locations
can be a later approval workflow.

### Nearest deterministic match

The client evaluates its bounded assigned set and selects the closest passing
geofence. Stable-ID tie breaking keeps retries consistent. The server recalculates
distance and checks the assignment, so the client result is only evidence.

### Compatibility projection

Keep `users.locationId` as the default/legacy site while the new assignment list is
introduced. This protects existing mobile releases and provides instant rollback.

### Platform region registration is bounded

iOS and Android impose background-region constraints. Register assigned locations
by configured priority and proximity within a safe cap; show manual check-in fallback.

### Preserve canonical attendance idempotency

Location is evidence, never part of attendance identity. Manual, automatic, and
offline submissions still race against the same deterministic daily record.

## Rejected Alternatives

- Query all locations during check-in: unbounded, slower, and leaks company sites.
- Trust a client-selected location ID: vulnerable to forged assignments.
- One attendance row per location/day: creates duplicates and payroll ambiguity.
- Replace the legacy field immediately: breaks old clients and rollback.

