# UI Redesign Program — Overview and Phase Index

**Status:** Draft for owner review. No implementation starts until each phase
spec is reviewed. Per repository rules, this program follows the Strangler Fig
model: new design-system code lives beside existing screens, each phase ships
as a deployable increment, and no legacy screen is deleted inside a feature
change.

## Goal

Make the mobile app and the web dashboard professional, easy to use, and
consistent by (1) introducing a shared design system, (2) regrouping features
into six domains, (3) rebuilding role dashboards around prioritized work, and
(4) enforcing loading/empty/error/offline/pending-sync states as acceptance
surfaces.

## Non-goals

- No business logic, Firestore queries, payroll cycle behavior, attendance
  behavior, permission accounting, or approval semantics change.
- No role or route-guard change. Existing routes keep working; regrouping is
  visual and navigational only.
- No brand change: dark OLED surfaces, cyan `#45F0FF` accent, wolf green,
  IBM Plex Sans Arabic remain the identity.
- No light mode in this program.

## Constraints inherited from AGENTS.md

- Presentation must not import data/Firebase/Dio; new UI code stays inside
  presentation-safe code.
- New state uses focused Cubits; no Cubit over 300 lines.
- Arabic RTL, desktop web (>=1024px), loading, empty, error, offline, and
  pending-sync states are verified per phase.
- Required checks (`flutter analyze`, guards, full tests) pass before handoff.
- Owner review gate after every phase spec and before implementation of that
  phase.

## Phases

| Phase | Spec | Scope | Depends on |
|---|---|---|---|
| P0 | `01_design_system_spec.md` | Tokens + component library beside legacy widgets | none |
| P1 | `02_navigation_ia_spec.md` | Web sidebar shell, mobile nav regrouping, domain hub screens, route redirects | P0 |
| P2 | `03_dashboards_spec.md` | HR, Manager, Team Leader, Employee dashboards rebuilt on P0/P1 parts | P0, P1 |
| P3 | `04_screen_states_polish_spec.md` | State coverage (loading/empty/error/offline/sync), RTL and touch polish across migrated screens | P0 |
| P4 | `05_rollout_migration_spec.md` | Migration order, parity checks, retirement of replaced code | all |
| P5 | `06_priority_redesigns_spec.md` | Home + Requests + Notification center redesign, full RTL/Arabic audit, unified logo (splash unchanged) | P0; integrates with P1–P2 |

Each spec defines its own acceptance criteria. A phase is done only when its
criteria pass and the required checks are green.
