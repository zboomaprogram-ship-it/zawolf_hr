# Quickstart: Multiple Attendance Locations

1. Keep `attendance_multi_location_v1` disabled.
2. Run current single-location characterization tests.
3. Run migration dry run; verify each legacy location produces one assignment.
4. Apply in non-production and assign a pilot employee two locations.
5. Test manual check-in at each site and outside both sites.
6. Test offline retry, duplicate submission, manual/automatic race, expired assignment,
   mock location, device mismatch, company day off, leave, and checkout-disabled mode.
7. Disable the flag and verify legacy check-in still works.
8. Run all repository checks before owner-reviewed deployment.

