# Phase 4 — Rollout, Parity, and Retirement

**Status:** Draft for owner review.
**Depends on:** Phases 0–3.

## Purpose

Sequence the migration of remaining screens onto the design system with
explicit parity checks, and retire replaced code in separate reviewed changes
only after parity is proven.

## Migration order (remaining screens)

Within each step, screens migrate one at a time; each is a deployable
increment:

1. Requests surfaces: `requests_mgmt`, `employee_requests`, requests log,
   approval timeline views → adopt `FilterBar`, `StatusPill`, state contract.
2. Attendance surfaces: attendance summary details, team attendance,
   check-in flows (presentation only).
3. People: `employee_mgmt`, team members, employee insights, profile.
4. Performance: KPI management/view, productivity ranking, departments,
   warnings-rewards, tasks.
5. Payroll & reports: payroll screen, deductions, sheets export.
6. Company/workspace: workspace center, folder browser, sheet editor,
   announcements, polls, notifications, assistant.
7. Auth-adjacent: login, splash, account-disabled, privacy/terms.

Hard rule: payroll and attendance behavior changes are out of scope; if a
migration reveals a behavior question, stop and record it — characterization
tests per the payroll/attendance specs gate any change.

## Parity protocol per screen

Before a migrated screen replaces its legacy presentation path:

1. Enumerate current states reachable by the old screen (loading, empty,
   error, offline, role variations).
2. Migrated screen reproduces each enumerated state or the difference is
   documented as intentional in the phase report.
3. Route parity test still passes; no path removed.
4. RTL + desktop-web verification recorded.

## Retirement rules

- Legacy widget implementations (e.g., duplicated stat-card builders) are
  deleted only after no importer remains, in a dedicated cleanup change.
- Redirects added during Phase 1 are retired only after one release cycle
  without internal navigation to old paths, with owner sign-off.
- No git history rewrite at any point.

## Program-level acceptance criteria

- [ ] All screens render exclusively from design-system tokens/components;
      grep shows zero hardcoded `Color(0x...)` outside token files.
- [ ] Route parity test green across the whole program.
- [ ] Full required checks pass: `flutter analyze`, architecture guard,
      Firestore query guard, full Flutter tests, scripts npm tests where
      touched.
- [ ] Owner walkthrough completed on mobile (RTL) and desktop web for every
      role before final handoff.
