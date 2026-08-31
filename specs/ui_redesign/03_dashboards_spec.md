# Phase 2 — Role Dashboards

**Status:** Draft for owner review.
**Depends on:** Phases 0 and 1.

## Purpose

Replace flat count-card grids with dashboards that surface prioritized work
first. Dashboards are read-only compositions of existing data sources; no new
Firestore queries are introduced in this phase unless a spec addendum is
reviewed.

## Common dashboard anatomy (all roles)

Ordered top to bottom:

1. **Header**: greeting + date + role-appropriate identity (`Avatar`).
2. **PriorityStrip**: up to three tappable alerts derived from existing
   pending-state providers, e.g. "٣ طلبات بانتظار موافقتك", "تأخير اليوم: X".
   Each item deep-links to a filtered child route. Hidden when zero items.
3. **Metrics row**: maximum four `StatCard`s; per-role metric sets defined
   below.
4. **Sections**: two to three sections max, each with `SectionHeader` and an
   "عرض الكل" action.

## Per-role metrics

| Role | Metrics |
|---|---|
| HR | today attendance %, pending approvals count, active headcount, open payroll-cycle state |
| Manager | team present now, pending approvals, tasks due this week |
| Team Leader | team attendance summary, pending requests, team tasks |
| Employee | my status today (in/out/pending), pending requests, tasks due |

Employee "my status today" uses the same source as the current check-in state;
this phase only changes presentation.

## Screen decomposition

- `hr_dashboard.dart` split into header/strip/metrics/actions widgets composed
  by the screen; no monolithic build methods.
- `employee_dashboard.dart` (currently ~1437 lines) decomposed into focused
  widgets: `_DashboardHeader`, radar/status widget, quick actions, recent
  activity. Any state extracted follows the Cubit rules (one responsibility,
  <300 lines).
- `manager_dashboard.dart` and the Team Leader dashboard adopt the same parts.

## Requirements

- All counts shown must already exist in current code paths; if a count does
  not exist, it is listed as an explicit gap in the phase report rather than
  added silently.
- Loading uses skeletons per section; errors render `ErrorState` per section,
  not a full-screen failure.
- PriorityStrip items are idempotent taps: navigating twice does not duplicate
  anything and back returns to the dashboard.

## Acceptance criteria

- [ ] Every role's dashboard matches the anatomy above at mobile width and
      web >=980 width.
- [ ] RTL verified for all four dashboards; desktop-web verified at 1024/1440.
- [ ] No Cubit exceeds 300 lines; architecture guard passes.
- [ ] Widget tests cover PriorityStrip visibility rules (zero-item hidden)
      and StatCard tap navigation.
- [ ] Required checks pass.
