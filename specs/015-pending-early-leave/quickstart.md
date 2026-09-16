# Validation Quickstart: Pending Early-Leave Checkout

## Prerequisites

- Use a non-production Firebase project or emulator with the Hostinger Node
  runtime pointed at it.
- Create an active employee with a 09:00–17:00 schedule and a base salary.
- Enable the normal checkout policy and feature flag
  `pending_early_leave_checkout_v1` for that test user.
- Create a same-day two-hour `early_leave` request and a checked-in attendance
  row. Keep unrelated attendance deductions available for conflict tests.

Do not deploy Firestore rules, run a production backfill, or reopen a finalized
payroll cycle as part of this validation.

## Automated checks

```bash
flutter analyze
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test
(cd scripts && npm test)
```

Expected: all checks pass; the new Cubit is below 300 lines; presentation has no
Firebase/data imports; Node tests prove gateway and projector idempotency.

## Scenario 1: Pending request exposes checkout and warning

1. Keep the two-hour request in `pending_manager` or `pending_hr`.
2. Open the dashboard before 15:00; checkout remains unavailable.
3. Advance the test clock to 15:00 without reopening the screen.
4. Confirm checkout appears within five seconds.
5. Open confirmation and verify Arabic RTL text says the request is pending and
   rejection may cause a 0.50-day deduction.
6. Cancel. Verify no attendance checkout or consequence was written.

## Scenario 2: Checkout first, rejection second

1. Confirm checkout at 15:00.
2. Verify the attendance row records the exact permission, original event time,
   requested duration, and 0.50 potential fraction.
3. Reject the request with a reason.
4. Verify one `rejectionConsequence` appears with `pending_hr`, execution date
   equal to the request date, and the reviewer reason.
5. Replay checkout and reconciliation ten times. Verify the attendance event and
   consequence remain single and unchanged.

## Scenario 3: Rejection first, checkout second

1. Reject a valid two-hour request before 15:00.
2. At 15:00, verify checkout is still offered with a definite 0.50-day warning.
3. Confirm checkout.
4. Verify evidence and the pending-HR consequence are written atomically.

## Scenario 4: Approval creates no consequence

1. Use early checkout while the request is pending.
2. Approve the request.
3. Verify attendance is authorized and no rejection consequence affects HR
   queue, discipline, or payroll.
4. Add an unrelated late-arrival deduction and repeat; verify approval does not
   clear or modify that deduction.

## Scenario 5: HR review and payroll

1. Open HR deduction review and verify the rejected early leave shows employee,
   date, requested hours, actual checkout, rejection reason, fraction, and
   estimated amount.
2. Before HR approval, calculate discipline/payroll and verify zero impact from
   this consequence.
3. Approve it and recalculate an open cycle; verify exactly 0.50 day is included.
4. Reject/reverse it and verify it is excluded.
5. Repeat against a finalized cycle; verify no automatic reopening occurs.

## Scenario 6: Security and failure behavior

- Send another employee's permission ID: expect `early_leave_not_owned`.
- Send a different date/type or altered duration: expect
  `invalid_early_leave_request`.
- Send before requested time: expect `early_checkout_too_early`.
- Disable global checkout: expect `checkout_policy_disabled`.
- Make request validation unavailable: client retains normal scheduled checkout
  and shows a recoverable explanation.
- Replay an offline event: original event time and request identity are retained;
  stale events still follow the existing 24-hour gateway rule.

## Rollout and rollback

1. Deploy server code with the feature flag disabled.
2. Enable only for test users and inspect safe audit counts for accepted,
   rejected, repaired, and duplicate operations.
3. Enable broadly after mobile/server parity is verified.
4. To roll back, disable `pending_early_leave_checkout_v1` and the recovery
   worker. Existing approved-permission and scheduled checkout behavior resumes;
   retained evidence remains available for audit.
