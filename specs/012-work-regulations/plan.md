# Implementation Plan — Work Regulations Enforcement

## Current-state findings

- Late-arrival policy exists but must be characterized against the attendance
  gateway's deterministic `{userId}_{date}` record before adding submission
  guards.
- Advance submission currently writes a pending request without tenure, date,
  or salary-cap checks.
- Casual balance is already seven days, but its per-request two-workday cap is
  absent.
- Leave entitlement currently defaults to 15 days in Dart and the daily job.
- Leave data has an attachment field but no conversion marker; use an optional
  boolean to preserve historical records.

## Design

1. Put pure regulation calculations in existing policy models: date/time
   eligibility, full-year age/service calculation, and leave-type rules.
2. Enforce rules in service methods before a write and recheck balance-sensitive
   conversion in the approval transaction. UI helpers must only mirror these
   rules; they cannot be the source of enforcement.
3. Read today's deterministic attendance record through the existing attendance
   access seam; do not add unbounded attendance history reads.
4. Add optional `convertToAnnual` to leave serialization and reviewer display.
   Default missing data to `false`.
5. Make the Hostinger daily entitlement reconciler use the same documented
   full-year calculation and update only active entitlement balance metadata.
6. Add narrow regression tests for Cairo date boundaries, record-write
   prevention, entitlement tiers, transaction idempotency, and Arabic UI
   states. Run the complete required suites before release.

## Rollout and rollback

- Ship policy enforcement as additive client/server-compatible changes.
- Do not backfill historic leave or reopen payroll cycles.
- If an unexpected policy issue appears, revert the client/server code while
  retaining optional leave conversion data; existing records remain readable.
- HR must confirm the production company policy and test a non-production
  account for all boundary scenarios before broad release.
