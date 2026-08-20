# Zawolf HR / ERP Engineering Rules

These rules apply to the whole repository. The governing architecture document
is `.specify/memory/constitution.md`; this file translates it into daily working
instructions.

## Delivery model

- Use a Strangler Fig migration. Add a new vertical slice beside the live code,
  prove parity, switch deliberately, and retire old code in a later reviewed
  change.
- Do not reorganize unrelated legacy files as part of a feature change.
- Keep the application deployable after every reviewed increment.
- Stop for owner review after specification, plan, and task generation. Do not
  continue automatically into implementation.

## New feature structure

New or migrated features belong under:

```text
lib/features/<feature>/
  data/
  domain/
  presentation/
specs/<feature>/
```

- `presentation` may depend on domain contracts and presentation-safe core
  utilities. It must not import `data`, Firebase, Firestore, Dio, or concrete
  persistence/network implementations.
- `domain` must not depend on Flutter, Firebase, Firestore, Dio, or UI code.
- `data` implements interfaces owned by the domain/core boundary.
- Shared primitives belong in `lib/core/` only after at least two real consumers
  demonstrate a stable common contract.

## State and UI

- Use BLoC/Cubit for newly migrated feature state. Existing Provider and
  `setState` code remains until its feature is migrated.
- One Cubit owns one UI-state responsibility. Persistence, API calls, conflict
  resolution, and cross-feature orchestration do not belong in a Cubit.
- A Cubit over 300 lines fails the architecture guard and requires an explicit
  reviewed exception or a responsibility split.
- Arabic RTL, desktop web, loading, empty, error, offline, pending-sync, and
  conflict states are acceptance surfaces, not follow-up polish.

## Critical business behavior

- Read `specs/payroll/payroll_cycle_spec.md` before changing payroll, permission
  accounting, cycle boundaries, or deductions.
- Read `specs/attendance/attendance_absence_spec.md` before changing attendance,
  absence, leave reconciliation, automatic attendance, devices, or reminders.
- Characterize current behavior with a failing test before refactoring payroll
  or attendance behavior.
- Preserve deterministic IDs, idempotency, approval-date versus execution-date
  semantics, and retry behavior unless an approved spec explicitly changes them.
- Never change production Firestore rules, run a destructive migration, reopen
  payroll, or rewrite Git history without explicit owner approval and a rollback
  plan.

## Scheduled and integration work

- Treat GitHub Actions and the Hostinger Node runtime as one distributed system.
  Verify which runtime owns the live schedule before changing a job.
- Keep one live scheduler per responsibility; manual workflows are recovery
  paths unless the relevant spec says otherwise.
- Firestore listeners and polling queries must be bounded, reusable, and covered
  by read-budget/idempotency tests.
- Hostinger is an integration runtime, not a second source of business truth.

## Required checks

Run the relevant subset during development and the full set before handoff:

```bash
flutter analyze
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test
(cd scripts && npm test)
```

## Review checklist

- [ ] A reviewed feature spec exists under `specs/<feature>/`.
- [ ] Presentation has no direct infrastructure/data dependency.
- [ ] New state uses focused Cubits and no Cubit exceeds 300 lines.
- [ ] Payroll/attendance behavior has characterization coverage when affected.
- [ ] Offline/sync/conflict behavior and idempotency are explicit when affected.
- [ ] Scheduled-job ownership and Firestore read impact were checked.
- [ ] Arabic RTL and desktop web states were verified.
- [ ] Irreversible operations are absent or explicitly approved with rollback.
- [ ] Analyze, Flutter tests, architecture guards, and relevant Node tests pass.

