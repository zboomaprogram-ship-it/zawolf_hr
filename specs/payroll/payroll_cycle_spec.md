# Payroll Cycle — Current Behavior Specification

**Status:** Phase 0 characterization; owner review required before adjacent
payroll/attendance changes.  
**Verified against:** `scripts/payroll-cycle.js`, `scripts/monthly-tasks.js`,
`.github/workflows/monthly-tasks.yml`, `scripts/test/payroll-cycle.test.js`, and
the Dart permission-cycle helpers as present on 2026-08-20.

## Purpose and source of truth

The payroll cycle is named by the calendar month in which it ends. It opens on
day 26 of the previous month and closes on day 25 of the named month, using
`Africa/Cairo` for deciding the current day.

Examples:

| Execution date | Cycle key | Cycle range |
|---|---|---|
| 2026-07-25 | `2026-07` | 2026-06-26 through 2026-07-25 |
| 2026-07-26 | `2026-08` | 2026-07-26 through 2026-08-25 |
| 2026-12-26 | `2027-01` | 2026-12-26 through 2027-01-25 |

The permission execution/request date—not its submission or approval time—is
the intended accounting date. New permission records set `monthKey` from
`requestDate`. Historical records with a wrong `monthKey` are not repaired by
the monthly job.

## Invocation

- GitHub Actions invokes the job at 21:05 and 22:05 UTC each day to cover Cairo
  standard/daylight time.
- Without force, the script returns unless the Cairo calendar day is 26.
- On day 26 it closes the cycle containing the previous day (day 25).
- A manual run may set `PROCESS_CYCLE_KEY=YYYY-MM`; either that value or
  `FORCE_MONTHLY_CLOSE=true` permits running outside the normal date gate.
- Invalid cycle keys are rejected.

## Idempotency contract

The idempotency key is `payrollCycles/{cycleKey}`. If that document exists with
`status == finalized`, the job exits without recalculating payroll runs or
resetting balances.

Writes are committed in batches of 400. Payroll runs use deterministic IDs
`{userId}_{cycleKey}` and merge on rerun. The final cycle document is appended
as the last operation. Therefore a failure before finalization can leave
partial merged payroll runs, but a rerun is intended to converge. The close is
not one all-or-nothing transaction.

## Inputs

The close reads in parallel:

- active `users`;
- `attendance` with `date` inside the cycle range;
- `permissions` whose stored `monthKey` equals the closing cycle;
- all `leaves` (used only to count approved overlaps);
- `warningsRewards` for the cycle;
- `advances` for the cycle;
- `companies/zawolf` for attendance/payroll workday policy.

`payrollWorkDaysPerMonth` comes from `attendancePolicy`, then the company root,
then defaults to 26.

## Per-employee calculation

All active users have their permission balance reset for the newly opened cycle
when `permissionBalance.lastResetMonth` differs. The reset sets used count and
used hours to zero and stores the opening cycle key.

`super_admin` users are excluded from payroll-run calculation, but their active
profile can still receive the balance reset.

For each other active user:

1. Base salary is `baseMonthlySalary`, defaulting to zero.
2. Attendance deductions include cycle attendance rows where
   `salaryDeductionApprovalStatus == approved` and amount is positive.
3. Deductible permissions include cycle permission rows where request status is
   `approved`, `isDeductible == true`, deduction approval is `approved`, and the
   fraction is positive.
4. Permission deduction amount is recomputed as
   `baseSalary / payrollWorkDaysPerMonth * fraction`; the stored permission
   amount is not summed.
5. Bonuses include `reward` or `bonus_recommendation` records with status
   `issued` or `acknowledged` and a positive amount.
6. Advances include approved records and sum their amounts.
7. Net salary is clamped at zero:
   `max(0, base - attendance deductions - permission deductions + bonuses - advances)`.

The `payrollRuns.attendanceDeductions` field currently stores attendance **plus
permission** deductions. This name is misleading but is current behavior and
must not be renamed without a migration/compatibility plan.

## Outputs

Each `payrollRuns/{userId}_{cycleKey}` is merged with employee snapshot fields,
currency, amounts, counts, `status: draft`, and calculation metadata.

`payrollCycles/{cycleKey}` is written as `finalized` with the range, next cycle,
record counts, pending-review counts, approved overlapping leave count, and
aggregate monetary totals.

## Late approvals and closed cycles

- A permission approved in a later cycle still belongs to its execution-date
  cycle if its stored `monthKey` was created correctly.
- The active UI balance changes only when the execution-date cycle equals the
  user's active balance cycle.
- Once a cycle is finalized, this job does not reopen or recalculate it.
- Consequently, an attendance deduction or permission approved after its cycle
  finalized is not picked up automatically. The product owner must define an
  adjustment/reopen policy before this behavior changes.

## Required characterization before refactor

- Boundaries on days 25/26 and December/January.
- Forced and normal close behavior.
- Rerun before and after finalization.
- Partial batch failure and convergence.
- Permission execution date versus approval date.
- Exclusion of pending/rejected deductions.
- Zero salary and zero net clamping.
- Late approval into a finalized cycle.

This specification documents behavior; it does not authorize a production
backfill, a reopened payroll cycle, or a Firestore-rule change.
