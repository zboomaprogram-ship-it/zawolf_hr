# Feature Specification: Same-Title Absence and Permission Alert

**Status**: Draft  
**Created**: 2026-09-13

## Goal

Warn the manager who is about to approve a leave or time-permission request when another employee with the same normalized job title already has an approved or pending-for-the-same-manager overlapping request on the same Cairo business date. The warning informs the decision; it does not block approval.

## Requirements

- The comparison uses the employees’ normalized `position` / job-title value, not display names or department names.
- It applies to leave and time-permission requests, including late arrival and early leave, for each request date that overlaps another request date.
- The warning identifies the count and names of the conflicting employees, request type, and overlapping date(s), scoped only to employees the approver is authorized to see.
- It appears immediately before the manager’s final approval confirmation and creates an idempotent notification to that manager when a second overlap is submitted or reaches their approval stage.
- It does not notify an employee, an unrelated manager, or a manager merely because titles match in a different approval scope.
- It does not change routing, approval authority, leave balances, attendance, deductions, or the request outcome. The manager can still approve or reject with the ordinary workflow.
- Repeated reads, retries, and approval taps must not generate duplicate notifications for the same request/date/manager conflict.
- If a job title is missing or blank, no same-title conflict is inferred.

## Acceptance Scenarios

1. Two employees with the same job title submit day-off requests for the same Cairo date to the same manager. The manager sees the conflict before approving the second request and receives one alert.
2. Two employees with the same job title have overlapping late-arrival or early-leave permissions. The manager sees the conflict dates and can make the normal decision.
3. Two employees with different job titles, or employees assigned to different approving managers, do not create an alert.
4. Reopening or retrying the same approval does not create duplicate conflict notifications.

## Assumptions

- “Time permission” means the existing attendance permissions such as late arrival and early leave.
- The alert is advisory, because staffing capacity may legitimately permit both requests.
