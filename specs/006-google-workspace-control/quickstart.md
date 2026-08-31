# Phase 006 Acceptance Quickstart

## Prerequisites

- A non-production company root with representative department, HR, employee, and Reports folders.
- Active test identities: Super Admin, active IT Manager, HR, department manager, editor employee, view-only employee, and ungranted employee.
- A representative Sheet containing formulas, formatting, labels, checkboxes, notes, hyperlinks, multiple tabs, and a protected/unsupported sample.
- Controlled report destination folders and a known attendance/request/deduction test period.

## Validation flows

1. **Access boundary**: Grant an editor access to one department Sheet and a viewer to another file. Verify browse/search/direct-link/download/edit permissions, revoke the editor grant, and verify it takes effect.
2. **Spreadsheet operation**: Open the editor Sheet full page; paste a selected range; change values/formulas/formats; add/rename a tab; insert a row and column; use find; save and reopen. Verify only supported content changed.
3. **Drive operation**: Create a folder, upload a file, rename, copy, move, download, trash, and restore it. Retry each request after a simulated interruption and verify a single final resource/action.
4. **Audit integrity**: Verify every operation above has a single actor, timestamp, target, action, operation outcome, and safe diff in an authorized audit view/report. Record a direct owner-side file change and verify it is labelled external/unattributed.
5. **Reports**: Generate daily, weekly, monthly, and custom-period workspace activity reports plus an HR attendance/request/deduction report. Verify selected period, scope, contents, protected destination, in-app discovery, and idempotent rerun behavior.
6. **Failure states**: Simulate denied access, offline operation, temporary service outage, duplicate submission, and edit conflict. Verify Arabic safe status with no raw technical error and no duplicate mutation.
7. **Migration/rollback**: Compare current and replacement workspace results for a selected resource, enable the pilot switch for test users, then return them to the legacy route without loss of their resources or history.

## Required verification commands before handoff

```bash
flutter analyze
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test
(cd scripts && npm test)
```

The implementation phase adds focused feature tests to these commands; a failed production integration must not be hidden by a client-only passing suite.
