# US3 — Dashboards Phase Report

**Scope**: T032–T039 (`specs/ui_redesign/tasks.md` Phase 5)
**Status**: Complete except T036/T037 (employee decomposition) and the
manual RTL/desktop verification pass.

## What changed

- **Team Leader** (`team_leader_dashboard.dart`): rebuilt to the common
  anatomy — header with `DsAvatar`, `PriorityStrip` fed by the role-aware
  `PendingRequestsService` singleton (already started by the navigation
  shell), 2×2 metrics row (attendance today, late today, pending requests,
  open tasks), attendance insights section, actions section.
- **Manager** (`manager_dashboard.dart`): strip now uses the same
  `PendingRequestsService` source (removed duplicate local count queries);
  metrics row is team-present-now / pending approvals / tasks due this week.
- **HR** (`hr_dashboard.dart`): metrics row is today attendance % (from the
  already-loaded summary future), headcount, pending approvals, active
  locations.
- **Tests** (`test/design_system/components_test.dart`): StatCard tap +
  inert rendering, SectionHeader `عرض الكل` action visibility/behavior.
  PriorityStrip zero-item hiding was already covered.

## Count-source notes (no new Firestore queries)

| Metric | Source |
|---|---|
| Pending approvals (all reviewer roles) | `PendingRequestsService.instance.pendingCount` |
| Team attendance summary | `DashboardAttendanceSummaryService.loadForReviewer` |
| Open / due-this-week tasks | existing `TaskService.watchManagedTasks` stream, client-side filter |

## Gaps recorded (per spec: no silent additions)

1. **HR "open payroll-cycle state" metric** — no existing dashboard code path
   exposes payroll-cycle state; `PayrollCycle` is date math only. Not added;
   needs a spec addendum if wanted on the HR dashboard.
2. **Employee role metrics** — blocked behind T036/T037. The employee's own
   pending-request count can be derived client-side from
   `EmployeeRequestHistorySection`'s existing three queries when that screen
   is decomposed. No new query required.
3. **Manual verification pass** — RTL + desktop-web 1024/1440 screenshots for
   all four dashboards still pending (requires a device/build session).

## Employee dashboard (T036/T037) — complete

- Attendance check-in/out gate decision logic extracted verbatim into
  `lib/screens/employee/widgets/checkin_action_state.dart`
  (`CheckInGateInputs` / `computeCheckInAction`) and pinned by 9
  characterization tests in `test/screens/employee/employee_dashboard_gate_test.dart`.
- `EmployeeDashboardHeader` (greeting + geofence chip) and `MyStatusCard`
  extracted to focused widgets; my-status card now renders first after the
  header per the anatomy spec.
- Policy-gate loading extracted into `EmployeeAttendanceGateCubit`
  (50 lines, one responsibility, fails closed with the same defaults as the
  previous inline catch block).
- Screen reduced 1060 → 780 lines; behavior-preserving (pilot/policy
  source-pin tests updated to follow moved code, same assertions).
- Phase 5 (US3) fully checked off except the manual RTL/desktop screenshot
  pass recorded as gap #3.

## Update — employee strip note

The employee dashboard has no reviewer-pending provider; its own
pending-request count does not exist as a standalone source today, so no
PriorityStrip was added for employees (gap #2 stands).
