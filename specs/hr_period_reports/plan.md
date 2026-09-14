# Plan — HR Period Reports

1. Add `hr_period_reports` domain entities for scope, period, summary, chart points, and daily employee detail, with a focused Cubit for selection/load/export state.
2. Implement a bounded repository that resolves actor scope first, reads only the selected employees and up to 31 effective dates, and merges attendance, approved leave, permissions, and deduction state.
3. Extend the Hostinger HR report generator with a period-and-scope contract that writes an idempotent, named Google Sheet tab for the selected report.
4. Build a responsive RTL report page: employee/all selector, period controls, summary cards, accessible line/status charts, and detailed expandable/table rows.
5. Add safe deep links from attendance and deduction cards into the exact employee/date detail.
6. Add authorization, effective-date, read-budget, pending-deduction, export-idempotency, RTL, and mobile/web tests.

## Rollback

Hide the new report entry point. Existing daily Google Sheet and Workspace audit reports remain unchanged; generated report tabs remain read-only history.
