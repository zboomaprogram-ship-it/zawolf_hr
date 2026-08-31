# Phase 1 — Navigation and Information Architecture

**Status:** Draft for owner review.
**Depends on:** Phase 0.

## Purpose

Regroup features into six domains so the same mental model works on mobile and
web, without deleting or renaming any route. Old paths keep resolving through
redirects.

## Domain model

All role surfaces are grouped into six domains:

| Domain | Arabic | Contains (existing routes) |
|---|---|---|
| Home | الرئيسية | role dashboard |
| Time & Attendance | الحضور | attendance-summary, team attendance, day-offs, locations, field-assignments, attendance-policy |
| Approvals | الطلبات | requests (role-scoped), suggestions |
| Payroll | الرواتب | payroll, reports/export, deductions views |
| Performance | الأداء | kpi, productivity, departments, warnings-rewards, tasks |
| People | الأشخاص | employees, announcements, workspace, google-workspace |

Shared surfaces (notifications, polls, assistant, profile) stay reachable from
the top bar / profile area on both form factors.

## Web shell (width >= 980, management roles)

Replaces `_DesktopManagementShell` internals in
`lib/navigation/navigation_wrapper.dart`; its public contract is preserved.

- Left sidebar: six domain groups, collapsible; active-route indicator using
  cyan accent; groups expand to show child links with current-route highlight.
- Top bar: global search entry point, notifications bell with `Badge`, profile
  menu (sign out).
- Content area: bounded width containers; tables use `AppDataTable`.
- Sidebar state (collapsed/expanded) persists for the session.

## Mobile navigation

Bottom nav becomes four fixed tabs per role plus a redesigned "More" sheet:

- Employee: الرئيسية / الحضور والطلبات / المهام والأداء / حسابي
- Team Leader & Manager: الرئيسية / الفريق / الموافقات / التقارير
- HR: الرئيسية / الحضور / الطلبات / الرواتب

The More sheet changes from a flat link list to a grouped grid of up to six
domain cards built from `WolfCard`.

## Hub screens

Each domain gets one hub screen per role family that lists grouped sections
with deep links into child routes. Hubs are presentation-layer only; they read
no Firestore data except lightweight counts already exposed by existing
providers/cubits.

## Route compatibility

- No route path changes. Where a hub replaces a direct grid, old paths still
  resolve because routes are unchanged.
- If any path must move later, a redirect entry is added in `router.dart` in
  the same change; removal of redirects is a separate reviewed change.

## Requirements

- One live navigation shell per form factor remains; the mobile bottom nav and
  web sidebar share the same `NavigationItem` source list filtered by role and
  platform.
- `navigation_wrapper.dart` is decomposed so no single file exceeds the 300-
  line Cubit rule where state exists; pure widgets are split by responsibility.
- Back behavior (`PopScope`, guarded back navigation) is preserved exactly on
  mobile.

## Acceptance criteria

- [ ] All existing routes resolve identically before and after (route parity
      test enumerating router paths).
- [ ] Web >=980 shows sidebar + top bar; <980 falls back to bottom nav;
      verified at 1024 and 1440 widths.
- [ ] RTL verified: sidebar on the right in Arabic context or explicitly
      positioned per design decision recorded here after owner input.
- [ ] Active-state highlighting correct for every child route.
- [ ] Required checks pass.
