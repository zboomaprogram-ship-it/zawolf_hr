# ZaWolf HR QA and KPI Integration Review

Date: 2026-08-01

## Scope

- Flutter static analysis and automated tests.
- Node notification/KPI synchronization tests.
- Firestore rules compilation.
- Web production build.
- Attendance, productivity, department, KPI, routing, and persistence code review.
- Live sales analytics API contract validation for an employee-filtered request.

## Live KPI API Findings

The API request succeeded and returned company-level sales and telesales data. The aggregate values are usable, including leads, meetings, closings, paid customers, sales value, conversion rates, and agent KPI ratios.

The employee identity contract is not working yet:

- The request included `idEmp=BD-1201`, but the response returned all sales and telesales agents.
- The filtered response matched the unfiltered company response.
- All 24 agent records returned an empty `id` and no stable `idEmp` or employee code.
- Agent keys such as `S8`, `S4`, and `TSM2` are aliases, not verified ZaWolf employee IDs.

ZaWolf therefore keeps department totals but deliberately does not link those rows to employee accounts. Guessing by name would risk assigning performance, targets, and tasks to the wrong employee.

### Required API Contract

For `idEmp=BD-1201`, the API should:

1. Return only the matching employee row, or clearly mark the selected employee in a stable field.
2. Include a non-empty `idEmp` in every sales and telesales agent row.
3. Return an employee-specific summary when an employee filter is supplied.
4. Keep `idEmp` stable and identical to the ZaWolf `employeeId` value.

## Defects Fixed

- Corrected KPI percentage normalization. API KPI values are ratios, including values above `1.0`; for example, `1.88` is now shown as `188%`, not `1.88%`.
- Removed unsafe employee matching by display name or ambiguous agent alias.
- Added explicit-ID matching through API `idEmp` or the controlled employee `salesAnalyticsAgentKey` field.
- Added API identity diagnostics to synchronized snapshots and Flutter models.
- Added a visible dashboard warning when aggregate data exists but employee IDs are missing.
- Clarified the manager/team-leader empty state instead of displaying a misleading zero-performance dashboard.
- Kept aggregate sales and telesales totals available to authorized HR users.
- Corrected the persisted telesales kind from legacy variants to `tele_sales`.
- Limited KPI summary history reads to reduce Firestore usage.
- Added regression tests for blank IDs, ignored filters, explicit mapping, percentage ratios, over-target KPI values, and legacy summaries.

## Attendance and Productivity Review

- Future days are excluded from attendance calculations.
- The current workday is not marked absent before shift completion unless a real attendance state exists.
- Approved leave, company days off, employee workdays, and hiring date are respected.
- Missing task or KPI data is excluded/reweighted instead of being invented as a perfect or zero performance score.
- A user with no attendance records is displayed as having no data, not fabricated attendance.

## Automated Verification

- Node tests: passed.
- Flutter analysis: passed.
- Flutter tests: passed.
- Firestore rules compilation: passed.
- Node syntax validation: passed.
- Web production build: passed.
- Git whitespace validation: passed.

## Residual Production Checks

Automated checks cannot prove that every physical device, APNs/OneSignal subscription, GPS chipset, biometric sensor, or production Firestore account behaves correctly. Before production rollout, run a device acceptance matrix for Android and iOS covering login persistence, attendance, request approvals, notifications in foreground/background/terminated states, and role-specific access.

The only confirmed blocker for accurate per-employee sales KPI display is the upstream API identity/filter contract described above.
