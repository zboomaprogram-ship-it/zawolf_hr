# Attendance and Absence — Current Behavior Specification

**Status:** Phase 0 characterization; owner review required before adjacent
attendance/payroll changes.  
**Verified against:** `scripts/daily-tasks.js`, `attendance-reminders.js`,
`auto-attendance.js`, `attendance-gateway.js`, `dispatch-notifications.js`,
`notification-web.js`, their workflows, and current Node tests on 2026-08-20.

## Attendance identity and authority

The canonical attendance document ID is `{userId}_{YYYY-MM-DD}`. Dates and
scheduled decisions use `Africa/Cairo`. Legacy generated-ID attendance rows are
still read by the reminder worker as a fallback, but new server paths write the
deterministic ID.

The authenticated attendance gateway accepts only the actor's own deterministic
ID. Event time must be within 24 hours of server time; location and device values
are validated. Device bindings are stored in `attendanceDevices` and on the user
profile. A verified binding conflict requires HR reset; missing/wrong legacy
bindings can be repaired by the transaction.

## Manual/offline attendance gateway

- Check-in creates the deterministic row only if absent; a repeat returns
  `already_recorded`.
- Check-out requires an existing check-in and does nothing if already recorded.
- Events delayed more than two minutes are stored with pending security review.
- The gateway copies calculated salary/deduction fields supplied by the
  validated client action; these remain subject to HR review where applicable.

## Automatic geofence attendance

The Hostinger worker reads at most 100 pending `autoAttendanceSignals`.
Automatic attendance must be enabled in `publicConfig/appSecurity`.

A signal is rejected or ignored when it is stale (older than 15 minutes), from
an unsupported source, mock-located, inaccurate beyond 25 metres, outside the
configured location radius, for an inactive/mismatched employee/location/device,
on a non-workday/company day off/approved leave, or outside allowed check-in or
check-out timing. Supported sources are `android_geofence` and `ios_region`.

Approved same-day late-arrival and early-leave permissions shift effective
start/end times. An active field assignment can suppress checkout. Check-in
calculates lateness and a proposed salary deduction from policy and salary;
positive deductions are `pending_hr` and notify HR/super-admin reviewers.
Signals are resolved with a terminal status, making the pending-signal queue
idempotent. Attendance IDs also prevent duplicate check-in/out.

## Reminder behavior

The live Hostinger scheduler normally scans every five minutes. GitHub's
attendance workflow is manual backup only.

- Default scan window is 06:00–20:00 Cairo and is policy-configurable.
- Friday is skipped globally; a user work schedule can define other workdays.
- Company days off and approved leave suppress reminders.
- Approved same-day permissions shift reminder times.
- Reminders are generated before start, at start, after the late-warning delay,
  shortly before full-day absence, and at checkout.
- Cold-start catch-up sends only the newest relevant morning reminder, with a
  default 90-minute catch-up; checkout has a 10-minute window.
- Attendance is read only for users who have a reminder due.
- A completed check-in suppresses check-in reminders; checkout is suppressed
  after checkout or when there was no check-in.

Each reminder has deterministic run ID
`{date}_{userId}_{kind}_{plannedMinute}` in `attendanceReminderRuns`. The run
document, notification creation, and unread-count increment occur in one
transaction. Overlapping schedulers therefore do not create the same reminder
twice. A process-local attempted-ID cache also avoids repeated reads during one
Hostinger process lifetime.

## Nightly absence and deduction processing

GitHub Actions calls `daily-tasks.js` at two DST-safe UTC hours; scheduled runs
continue only at 08:00 Cairo. The default target is the completed previous day.
Manual `PROCESS_DATE` can select another day.

Before attendance work, the script reconciles leave entitlement metadata. For
the target attendance day it then:

1. skips an active company day off;
2. loads approved leave overlapping the day;
3. loads approved permissions whose `requestDate` equals the day;
4. loads active users and HR/super-admin reviewers;
5. respects each user's workdays, defaulting Friday to off;
6. reads deterministic attendance for every in-scope active user.

If no attendance row exists:

- an approved leave produces `status: on-leave`;
- unpaid/full-deduction leave proposes a full-day `pending_hr` deduction;
- paid leave uses a rejected zero-value compatibility sentinel so older clients
  do not mistake it for missed checkout;
- otherwise a full-day `absent` row with `pending_hr` deduction is created.

If attendance exists:

- late arrival is recalculated using an approved late-arrival permission;
- a missing checkout proposes at least a quarter-day deduction and records
  `salaryDeductionDetectedAt` so it is not detected/notified repeatedly;
- an approved early-leave permission can clear the matching early-checkout
  deduction.

The job batches writes below Firestore's limit, notifies reviewers, and changes
overdue tasks from `new`/`in_progress` to `late`. The deterministic attendance
row and detection timestamp provide practical rerun idempotency, but the whole
daily job is not a single transaction.

Administratively configured amnesty dates skip attendance processing. Current
code defaults this list to 2026-07-18 and 2026-07-19 unless overridden.

## Approval reconciliation

Final approval of a late-arrival or early-leave permission reconciles the
attendance row for the permission's execution date. Approved leave clears
deduction fields for each covered attendance row and marks no-check-in rows as
`on-leave`. These writes are best-effort across multiple documents rather than
one cross-day transaction.

## Notification delivery

Workers write to `notifications/{recipientId}/items/{notificationId}` with
`pushSent: false`. The Hostinger listener/dispatcher claims pending items and
sends OneSignal pushes. Attendance reminders are revalidated against attendance
immediately before push so stale reminders can be skipped. GitHub dispatch is a
manual recovery path to avoid two live five-minute dispatchers.

## Known edge conditions to preserve and review

- A user without an explicit work schedule defaults to Friday off.
- Paid leave rows carry a non-zero compatibility fraction but a zero amount and
  rejected approval; payroll filters on approved positive amounts.
- Nightly processing reads one attendance document per active in-scope user.
- Automatic attendance currently reads all of a user's leave, permission, and
  field-assignment rows per pending signal, then filters locally.
- Reviewer notifications in daily and automatic jobs use generated IDs; their
  surrounding attendance/detection state is what prevents normal rerun
  duplication.
- A failure between chunk commits can leave a partial daily run that converges
  on rerun but is not atomic.

## Required characterization before refactor

- Cairo date/DST and workday boundaries.
- Company day off, paid/unpaid leave, and field assignment behavior.
- Deterministic versus legacy attendance IDs.
- Device binding, delayed/offline action and repeat action behavior.
- Late/early permission reconciliation by execution date.
- Absence, missed checkout and HR deduction-review transitions.
- Reminder idempotency under overlapping schedulers and cold starts.
- Partial batch failure/retry and notification deduplication.

This specification does not authorize changing production Firestore rules,
deleting legacy attendance rows, or altering deduction policy.
