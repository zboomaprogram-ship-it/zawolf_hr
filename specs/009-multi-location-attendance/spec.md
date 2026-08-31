# Feature Specification: Multiple Attendance Locations

**Feature Branch**: `009-multi-location-attendance`  
**Created**: 2026-08-24  
**Status**: Draft — owner review required before implementation  
**Input**: Allow an employee to sign attendance from two or more approved locations instead of one.

## Clarifications

### Session 2026-08-25

- Q: متى يجب أن يسجل النظام الانصراف التلقائي؟ → A: فور خروج الموظف من نطاق موقع مُسند، مع استثناء نافذة الإذن الزمني المعتمد وفترة راحة الشركة.
- Q: ماذا يحدث إذا انتهى الإذن أو الاستراحة والموظف ما زال خارج النطاق؟ → A: يبدأ النظام مهلة عودة قابلة للضبط، ثم يسجل الانصراف تلقائياً مرة واحدة إذا لم يعد الموظف قبل انتهائها.

## User Scenarios & Testing

### User Story 1 - Assign multiple approved locations (Priority: P1)

HR/Admin assigns two or more active company attendance locations to an employee,
with effective dates and one optional default display location.

**Why this priority**: Location authority must be explicit and managed before the
check-in path can safely accept more than one geofence.

**Independent Test**: Assign two branches to one employee, reload their profile,
and verify both active assignments and the unchanged legacy default location.

**Acceptance Scenarios**:

1. **Given** two active company locations, **When** HR assigns both to an active
   employee, **Then** both become eligible without duplicating the employee.
2. **Given** an employee without an assignment, **When** they attempt check-in,
   **Then** it fails safely with Arabic guidance and no raw provider error.
3. **Given** an employee, **When** they attempt to self-create or self-approve a
   location, **Then** the server denies the mutation and exposes no protected data.

---

### User Story 2 - Check in from any assigned location (Priority: P1)

An employee inside any assigned active geofence completes manual check-in. The
system validates all eligible locations, deterministically selects the nearest
matching location, and records that location and distance evidence.

**Why this priority**: This is the requested employee outcome and must remain as
reliable and idempotent as the current single-location check-in.

**Independent Test**: Check in on separate days from two assigned locations and
verify exactly one deterministic attendance row per Cairo day with the matched ID.

**Acceptance Scenarios**:

1. **Given** two assigned locations, **When** the employee is inside the second,
   **Then** check-in succeeds and stores the second location's identity.
2. **Given** overlapping geofences, **When** more than one location matches,
   **Then** the nearest match wins, with stable ID tie-breaking.
3. **Given** a duplicate or retried submission, **When** the canonical attendance
   row already exists, **Then** the result is `already recorded`, not an error.

---

### User Story 3 - Automatic entry and exit from multiple locations (Priority: P2)

When automatic attendance is enabled, Android/iOS register the employee's bounded
set of assigned regions and a valid enter signal for any of them can create the
same canonical check-in record. A valid exit signal can create automatic checkout
when the HR checkout policy is enabled, except during an active approved time
permission or configured company-break window.

**Independent Test**: Send valid signed/geofence entry signals for two assigned
locations and verify the first valid event records attendance and later events
converge without duplicate writes or notifications.

**Acceptance Scenarios**:

1. **Given** automatic attendance and multiple assigned sites, **When** the device
   enters an assigned active site, **Then** the worker validates the assignment
   server-side before creating attendance.
2. **Given** an old/unassigned/disabled location signal, **When** it is processed,
   **Then** it reaches a terminal ignored/rejected outcome without attendance.
3. **Given** platform region limits, **When** assignments exceed the supported
   active region count, **Then** deterministic priority and manual-check-in fallback
   are shown rather than silently dropping all locations.
4. **Given** an employee checked in at an assigned site, **When** a valid exit
   signal is accepted outside an authorized exception window, **Then** exactly one
   checkout is recorded without requiring the employee to reopen the app.
5. **Given** an employee exits during an approved return-required permission or
   company break, **When** the exception ends and they remain outside through the
   configured return-grace window, **Then** one automatic checkout is recorded;
   re-entry before the deadline cancels that pending checkout.

---

### User Story 4 - Manage assignments and history (Priority: P2)

HR/Admin searches employees, bulk assigns or removes locations, previews impact,
and reviews assignment and attendance evidence without rewriting history.

**Independent Test**: Remove one location effective tomorrow and verify today's
historical check-in remains linked while tomorrow's check-in is denied there.

### Edge Cases

- Two locations overlap or have identical coordinates/radii.
- Assignment starts/ends near midnight or across Cairo DST changes.
- A location is archived while assigned to employees.
- The client is offline and syncs after assignment expiry or policy change.
- Manual and automatic events race from different assigned locations.
- One assigned location cannot be loaded but another valid cached assignment exists.
- iOS/Android region registration capacity is smaller than the assignment count.
- Checkout is disabled while check-in and leave-permission behavior remain available.
- The employee exits during an approved time permission or the configured company break.
- The return-grace worker is delayed or runs twice after an exception ends.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST support many effective-dated attendance-location
  assignments per employee and MUST retain one optional legacy/default location projection.
- **FR-002**: Only server-authorized HR/Admin capabilities may create company
  locations or assign/remove employee locations; employees cannot self-authorize.
- **FR-003**: Manual check-in MUST validate the current position against every
  active assignment effective at the event's Cairo date/time.
- **FR-004**: If multiple geofences match, the system MUST select the smallest
  measured distance and use stable location ID as a deterministic tie-breaker.
- **FR-005**: The authenticated attendance gateway MUST revalidate the submitted
  matched location and assignment; it MUST NOT trust client `locationId` alone.
- **FR-006**: Attendance evidence MUST store matched location ID/name, coordinates,
  accuracy, distance, allowed radius, source, assignment version, and event time.
- **FR-007**: The canonical attendance ID `{uid}_{Cairo YYYY-MM-DD}` and duplicate
  check-in semantics MUST remain unchanged across all locations and retries.
- **FR-008**: Offline submissions MUST retain the candidate/matched location and
  assignment version and be revalidated server-side before final acceptance.
- **FR-009**: Automatic geofence entry and exit MUST accept only assigned active
  locations and preserve current anti-mock, device, workday, leave, and time checks.
  Exit MUST create checkout only while the HR checkout policy is enabled and MUST
  be suppressed during an active approved time permission or configured company break.
- **FR-010**: Region registration MUST be bounded and prioritized deterministically;
  manual check-in must remain available when platform region capacity is exceeded.
- **FR-011**: Assignment changes MUST be versioned, idempotent, audited, previewed,
  effective-dated, and MUST NOT rewrite historical attendance rows.
- **FR-012**: Archiving a location with future/current assignments MUST require an
  impact preview and resolution or a confirmed effective-dated reassignment.
- **FR-013**: Existing users with only `locationId` MUST behave exactly as before
  while the feature flag is off and migrate non-destructively to one assignment.
- **FR-014**: The feature MUST default off under `attendance_multi_location_v1`
  and retain the current single-location validator as rollback.
- **FR-015**: Location and assignment reads MUST be bounded and cached; a check-in
  MUST NOT scan all company locations or establish unbounded listeners.
- **FR-016**: The UI MUST expose Arabic saved, pending-sync, conflict, status-check,
  denied, location-service, outside-range, and retry states with no raw Firebase error.
- **FR-017**: Leave permission and attendance correction request creation MUST
  remain available regardless of the HR-controlled checkout policy.
- **FR-018**: The change MUST NOT alter payroll-cycle allocation, deduction policy,
  leave reconciliation, checkout policy default, or past attendance evidence.
- **FR-019**: When checkout is enabled, an exit during a return-required approved
  time permission or configured company-break window MUST create only a pending
  return evidence record. If no valid re-entry occurs before the HR-configured
  return-grace deadline, a server worker MUST create one idempotent checkout at
  that deadline with an explicit automatic-return-grace reason. Re-entry before
  the deadline MUST resolve the pending record without checkout. The worker MUST
  re-check the checkout policy and exception state at execution time.

### Key Entities

- **Attendance Location**: Approved company geofence and active lifecycle.
- **Employee Location Assignment**: Effective-dated authorization linking an employee and location.
- **Location Match Evidence**: Deterministic result of comparing a captured position to assignments.
- **Attendance Action**: Idempotent manual/offline check-in operation.
- **Automatic Attendance Signal**: Platform region-entry or region-exit event validated server-side.
- **Location Assignment Audit Event**: Append-only assignment/administration history.

## Success Criteria

- **SC-001**: An employee assigned three sites successfully checks in from each on
  separate test days, with the correct matched site and exactly one row per day.
- **SC-002**: Unassigned, expired, inactive, spoofed, and outside-range attempts
  produce zero accepted attendance records in all contract tests.
- **SC-003**: Manual/automatic/offline race and retry tests always converge to one
  canonical check-in without duplicate deductions or notifications.
- **SC-004**: HR assigns or removes multiple locations for one employee in under
  two minutes with a visible impact preview and audit event.
- **SC-005**: Normal check-in resolves to saved, already recorded, pending sync,
  or clear retry guidance within 10 seconds and never shows technical provider text.
- **SC-006**: Single-location users retain parity while the feature is disabled and
  after migration to their one initial assignment.
- **SC-007**: Valid exit signals outside authorized exception windows converge to
  one checkout, while exits during approved permission or break windows create no checkout.
- **SC-008**: Re-entry before a configured return-grace deadline creates zero
  checkout records; a still-outside employee after the deadline creates exactly
  one audited automatic checkout, even if the worker retries.

## Assumptions

- “Employee can add two or more locations” means the employee can be assigned and
  use multiple company-approved locations; employees cannot define their own geofence.
- HR/Admin manages company locations and assignments through a capability, not role text.
- The nearest assigned match is preferable to asking employees to select a branch.
- Existing checkout and leave-permission controls remain independent.
