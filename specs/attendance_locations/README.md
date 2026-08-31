# attendance_locations

Specification source of truth: [`specs/attendance/attendance_absence_spec.md`](../attendance/attendance_absence_spec.md)
(attendance location assignment/matching is part of the attendance domain
governed by that spec and `.specify/memory/constitution.md`).

This pointer directory exists so the architecture guard
(`test/architecture_guard_test.dart`, "every migrated feature has a
specification directory") can bind `lib/features/attendance_locations` to its
reviewed specification.
