# Work Regulations Enforcement

**Status:** Proposed for owner review  
**Source:** Owner-supplied company policy, September 2026

## Purpose

Apply the approved company rules consistently when employees submit attendance
permissions, salary advances, and leave requests. The same rules must be
visible to employees before submission and enforced again by the authoritative
workflow so they cannot be bypassed by an older client.

## Scope

This increment covers late-arrival permissions, salary advances, casual leave,
birth leave, exam leave, annual leave entitlement, and an employee-elected
sick-to-annual conversion. It does not change overtime multipliers, employee
suspension, Firestore rules, historic payroll cycles, or existing approved
records.

## User scenarios

### US1 — Submit an attendance permission (P1)

An employee selects a late-arrival permission. The request is refused if it is
submitted after that employee's scheduled start on the requested current day,
or after a recorded check-in. The form explains the reason in Arabic before
submission when the state is already known.

### US2 — Submit a compliant salary advance (P1)

An employee sees whether they have completed three months of service, whether
the calendar date is eligible, and the maximum amount equal to half their
monthly base salary. A request outside any of those limits is not created.

### US3 — Submit regulated leave (P1)

An employee can request casual leave for no more than two chargeable workdays
per request, birth leave for one birth day up to three times during service,
and exam leave only with sufficient notice and evidence. The employee sees the
special limits in Arabic before submitting.

### US4 — Maintain annual entitlement (P2)

At each entitlement renewal, employees receive 15 days in their first service
year, 21 days from their first completed year, and 30 days after ten completed
years or at age 50. The entitlement is calculated from authoritative dates and
does not modify a closed payroll cycle.

### US5 — Convert sick leave to annual leave (P2)

An employee with sufficient annual balance may elect to classify a sick leave
request as annual leave. The choice is retained with the request and, after
approval, deducts the approved chargeable days once from annual leave. A normal
sick leave continues without annual-balance deduction.

## Functional requirements

1. A late-arrival request for today must be rejected after the employee's
   scheduled work-start time, defaulting to 09:00 when no schedule exists.
2. A late-arrival request must be rejected if the employee already has a
   non-null check-in for the requested date.
3. A salary advance requires at least 90 calendar days of service, calendar
   day 15 or later, and an amount no greater than 50% of base monthly salary.
   Missing hiring date or salary fails closed with a clear Arabic message.
4. A casual leave request may contain at most two chargeable workdays. The
   existing seven-day annual casual balance remains a separate rule.
5. Birth leave is one chargeable calendar/work day only, requires a reason,
   does not consume annual or casual balance, and is limited to three requests
   in the employee's service history across pending and approved stages.
6. Exam leave requires a non-empty proof attachment and a requested start date
   at least ten whole calendar days after the Cairo submission date. It does
   not consume annual balance.
7. Annual quota is 15, 21, or 30 days using full service years and full age
   years; missing birth date only removes the age-based route to 30 days.
8. An approved sick leave marked for annual conversion deducts its chargeable
   days once from annual/days-off balance after sufficient balance is confirmed
   in the approval transaction.
9. Existing leave, attendance, advance, notification, and payroll records
   remain readable. New fields are optional and historical records default to
   their prior behavior.
10. Employee and reviewer views show the selected birth leave and conversion
    status in Arabic RTL text.

## Acceptance criteria

- A late-arrival request at or after scheduled start and a request after
  check-in both fail before a record is written.
- Attempts to submit an advance before day 15, before 90 service days, or
  above half salary fail without creating an advance record.
- A three-day casual request, second birth-leave day, fourth birth-leave
  request, exam request with less than ten days' notice, and exam request with
  no attachment all fail without creating a leave record.
- Entitlement examples return 15, 21, and 30 for the three defined tiers in
  both the mobile and scheduled policy calculations.
- Normal sick leave never deducts annual balance; an approved converted sick
  leave deducts it exactly once under retry.

## Assumptions and decisions

- “After 09:00” means after each employee's configured scheduled start. At the
  exact start time, the request is no longer eligible.
- Chargeable days are calculated with the existing work-schedule and company
  day-off logic, rather than raw calendar-day spans.
- The policy applies prospectively. No historical leave or entitlement backfill
  is part of this increment.
- The attached policy is treated as the company instruction. Legal citations
  require HR/legal confirmation before they are presented as legal advice in
  the product.

## Success criteria

- Every ineligible submission is rejected before it creates a request record.
- Employees receive an Arabic explanation for every rejected policy condition.
- Retrying an approved sick-to-annual conversion never deducts annual balance
  more than once.
- Scheduled entitlement reconciliation produces the same quota as the client
  calculation for all boundary-date examples.
