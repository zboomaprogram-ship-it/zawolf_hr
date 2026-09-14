# HR Period Reports

## Goal

Give HR and Super Admin a professional, in-app report for one employee or all employees over a selected period, with detailed attendance, lateness, absence, leave, permission, and deduction data. The same verified report can be exported to a Google Sheet.

## Scope

- HR and Super Admin may choose **all employees** or one active employee.
- Default range is the most recent 30 days. The picker supports 7 days, 30 days, and a custom inclusive range of up to 31 days.
- Managers and team leaders may use the same report only for their assigned people. Employees cannot open it.
- The report shows: total scheduled days, present, late, absence/no check-in, on leave, approved permissions, approved and pending deductions, attendance rate, and discipline impact.
- Charts: attendance-status distribution, attendance trend by date, and lateness trend. Every chart value has an accessible numerical summary and drill-down.
- Detailed rows use effective attendance date, not request approval date. Rows show check-in/out times, lateness minutes, leave/permission coverage, deduction status/reason, and source.
- HR can export the exact selected scope and period to a Google Sheet. Export tabs use the same report ID and period, rather than mixing unrelated employee data.

## Authorization and data boundaries

- Server/data layer derives the accessible employee scope from the signed-in actor. The browser cannot request another department or unrelated employee.
- HR/Super Admin receive company data; manager/team leader receive only their managed people.
- All reads are bounded to 31 days and selected employees. Aggregate and detail queries are paged/bounded.
- Pending deductions remain visible but are marked as pending and do not reduce discipline percentage.

## UX acceptance

- Arabic RTL is explicit for cards, charts, tables, filters, and navigation chevrons.
- The report opens in the application first. Google Sheet export is a secondary action.
- Loading uses fixed-height skeletons; refresh preserves the last report; empty/error states state whether there was no data or a failed fetch.
- Mobile shows summary cards and expandable daily details; desktop shows charts, filters, and a detailed table.

## Out of scope

- Changing attendance, leave, permission, payroll, or deduction decisions.
- Rewriting prior Sheets or historical records.
- Unbounded company-wide analytics.
