# Data Model: Attendance and Requests Stability

## AttendanceCheckInAttempt

| Field | Meaning | Invariant |
|---|---|---|
| actionId | Idempotency identifier | Stable for manual/automatic retries. |
| employeeScopeId | Authenticated owner | Matches action, pending item, and authority actor. |
| attendanceId | Cairo daily identity | One canonical check-in per employee/date. |
| source | Manual or automatic location | Audit-only. |
| capturedAt | Original event time | Never replaced by retry time. |
| outcome | Saved, pending, status-check, failed | UI exposes safe Arabic state only. |

## RequestVisibilityRecord

| Field | Meaning | Invariant |
|---|---|---|
| stableId | Unified request/deduction identity | Stable across tab/search refresh. |
| sourceType | Leave, permission, correction, deduction, etc. | Classifies display without rewriting source history. |
| employeeId | Subject employee | Required for authorized filtering. |
| approvalStage | Current/terminal chain stage | Derived from present or legacy fields. |
| lifecycleState | Pending, approved, rejected, cancelled, confirmed | Terminal history never disappears due to current filter. |
| occurredAt | Request/execution date | Bounds ordering/history query. |
| sourceReference | Original document reference | Supports audited drill-down. |

Read states: `idle -> loading -> loaded(records|empty) | retryableFailure |
accessDeniedSafe`. Loading is never final.

## EmployeeDeductionExplanation

Read-only display model for one employee-facing salary deduction.

| Field | Meaning |
|---|---|
| sourceLabelAr | Attendance, permission, leave, or administrative source in Arabic |
| reasonLabelAr | Existing policy or administrative reason in Arabic |
| affectedDateOrPeriodAr | Cairo date/period shown to the employee |
| fraction | Deducted day fraction, when recorded |
| amount / currency | Monetary amount, when recorded |
| reviewStatusAr | Pending, approved, rejected, or historical status |
| detailsAvailability | Complete or partial; partial never invents missing history |

## ProductivityInputSnapshot

| Field | Meaning | Invariant |
|---|---|---|
| scope | Selected employee/team | Every source record matches it. |
| period | Cairo start/end range | Every source record falls in range. |
| inputs | Attendance, approved request, task, KPI | Policy effects are explicit. |
| availability | Complete, partial, unavailable | Partial/unavailable is not a complete zero. |

## AttendanceDeviceBinding

| Field | Meaning | Invariant |
|---|---|---|
| employeeScopeId | Bound employee | At most one active binding. |
| activeDeviceId | Trusted device | Replaced only by authorized reset/rebinding. |
| reset audit | Actor, reason, time, event ID | Server-derived and immutable. |

## CompanyAttendanceLocation

| Field | Meaning | Invariant |
|---|---|---|
| locationId | Branch identity | Existing location survives map failure. |
| latitude/longitude/radius | Reviewed geofence | Saved together and policy-valid. |
| editor/time/revision | Change audit | Authorization and conflict-safe update required. |
