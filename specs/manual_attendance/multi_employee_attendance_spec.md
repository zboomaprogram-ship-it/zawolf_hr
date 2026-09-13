# Multi-employee manual attendance

## Goal

Extend the existing HR manual-attendance screen so HR can select multiple employees using checkboxes and apply one valid current-day action to all selected employees.

## Behavior

- HR can search/filter the existing employee list and select one or more employees.
- HR selects one action, an effective current-day time, and one required reason for the batch.
- The server treats each employee as an independent manual-attendance operation using a deterministic per-employee operation ID derived from the batch operation ID.
- The result reports successful employees and rejected employees with their own Arabic reason. A failure for one employee must not prevent valid selected employees from being recorded.
- Each recorded employee retains the existing deterministic attendance ID, manual-event audit data, receipt, and employee notification.
- Existing single-employee submission remains supported during the migration, while the UI uses the batch operation.

## Safety

- The same batch retry must not duplicate an attendance event, audit row, receipt, or notification for any employee.
- Existing restrictions remain: HR authorization, today-only/current-or-earlier time, workday, company-day-off, approved leave, check-in/check-out ordering, and closed-payroll protections.
- The batch is capped at 50 selected employees per request to keep server work bounded.

## Acceptance criteria

- Checkboxes work in Arabic RTL on mobile and desktop web.
- The selection count and clear-selection action are visible.
- Loading, partial-success, full-failure, and retry messages explain the result without losing the selection.
- Existing single-employee API tests continue to pass and new batch tests cover duplicate retry and a mixed valid/invalid selection.
