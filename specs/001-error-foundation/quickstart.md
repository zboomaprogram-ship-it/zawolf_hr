# Validation Guide: Shared Error Foundation

## Preconditions

1. The separate full-suite baseline repair has completed: `flutter analyze` and `flutter test` are green before implementation begins.
2. Work only on the `001-error-foundation` lifecycle.
3. Do not add Firebase, Firestore, HTTP, Flutter-widget, or persistence imports to `lib/core/errors/`.

## Baseline record — 2026-08-20

The two inherited Flutter test failures were reconciled with the existing intended behavior: missing KPI data uses available attendance/behavior scoring, and HR monitoring includes manager-stage requests while CEO includes its final stage. `flutter test` now passes all 114 tests; the architecture guard and `scripts` Node test suite also pass.

The focused maintenance pass is now complete: `flutter analyze` is clean, `flutter test` passes 124 tests, the architecture guard passes, and the `scripts` Node test suite passes 56 tests. The pass only corrected analyzer diagnostics and stale test expectations; it did not alter any business workflow. The duplicate, unreachable Workspace helpers were removed from the parent screen because the active folder browser owns that behavior.

The worktree contains pre-existing user changes to `lib/utils/user_facing_error.dart` and an unrelated trailing-whitespace issue in `docs/employee_login_accounts_ar.md`. Neither belongs to this feature and neither was modified by it.

## Focused validation

After implementation, run:

```bash
flutter test test/core/errors
flutter analyze
flutter test
cd scripts && npm test
```

Expected outcomes:

1. Each of the nine categories in [data-model.md](data-model.md) creates a structured failure with valid recovery guidance.
2. Arabic messages exist for every category and the fallback; tests assert raw provider terms, exception text, stacks, credentials, and identifiers are absent.
3. A confirmed validation/access failure reports `confirmedNotCompleted` and does not ask the user to check unknown status.
4. A simulated interrupted write reports `unknown` and only permits `checkStatusBeforeRetry`.
5. A duplicate/conflict offers no repeat action and directs the caller to the existing record.
6. Existing legacy utilities and unchanged screens retain behavior because this foundation has no adopted UI workflow yet.

## Contract review

Review [operation-outcome.md](contracts/operation-outcome.md) before the first consumer migration. The future Auth pilot must add provider mapping in Auth data code and one focused presentation Cubit; it must not add provider types to this core package.

## Deferred Auth pilot

Create a separate Spec → Plan → Tasks lifecycle before migrating the first Auth workflow. The pilot must normalize concrete Auth failures in an Auth data adapter, return `OperationResult`, render `UserSafeFailureMessage` through one presentation Cubit, retain the legacy fallback until parity tests pass, and define a rollback condition. This foundation itself does not migrate authentication or any live workflow.

## Release check

This foundation is additive and must not become a default workflow change by itself. A later feature-specific pilot must document selector, rollback condition, parity tests, and production verification before becoming active.

## Final validation — 2026-08-20

Passed:

- `dart format lib/core/errors test/core/errors test/architecture_guard_test.dart`
- `flutter analyze`
- `flutter test test/architecture_guard_test.dart test/core/errors`
- `flutter test` (124 tests)
- `cd scripts && npm test` (56 tests)

`git diff --check` still reports only the pre-existing trailing whitespace in `docs/employee_login_accounts_ar.md`. No Firestore rules, Firebase configuration, payroll/attendance implementation, routes, legacy services, or Hostinger scripts were changed by this error-foundation phase.
