# Phase 007 Validation Guide

## Preconditions

Use a non-production Firebase/Hostinger environment with employee, manager, HR,
admin, hidden-account, historical request/deduction, and mapped/unmapped sales
fixtures. Keep all V2 flags off until their slice tests pass. Place the sales key
only in server environment configuration.

## Acceptance run

1. Open a previous-cycle deduction; verify Arabic reason/evidence/effective
   period. Submit the late correction twice with same operation ID; exactly one
   request exists and cycle allocation does not move.
2. Mark notifications read; every badge reaches zero. Tap an approver request
   notification and verify management context/focus ID, not employee route.
3. Hide/restore a test account; default daily attendance excludes it while
   admin/audit mode reveals it without affecting active/history.
4. Query a 25/26 boundary employee timeline; verify all types and no duplicate
   rows or indefinite loader.
5. Compare mapped/unmapped/ambiguous sales fixtures; one filter version drives
   card/chart/list/export and unresolved rows are never attributed.
6. Simulate unavailable/permission/provider failure; users see Arabic recovery
   state only and one sanitized diagnostic aggregate is reported.
7. With external provider disabled, validate assistant guidance/refusal and
   Drive attachment authorization/audit without a public link.
8. Verify RTL arrows/back, keyboard, copy/select/Ctrl+F, mobile/desktop layout,
   and forced-update retry without a loop.
9. Grant one test employee a time-limited developer-tools entitlement; verify
   the in-app diagnostics menu is shown, then expires/revokes. Simulate mock
   location and USB debugging and verify existing attendance protections are
   still enforced.

## Flagged parity and rollback

For each vertical slice, run the acceptance step first with its flag off and
capture the legacy result, then enable the same slice for one non-production
Firebase UID and compare the V2 result. Never enable multiple new slices merely
to test one workflow.

Use the Hostinger environment variable `PHASE007_FEATURE_FLAGS_JSON` as the
single rollout control. The pilot shape and immediate rollback procedure are in
`scripts/HOSTINGER_DEPLOYMENT.md`. Removing a UID or setting `enabled` to false
must restore the legacy route after refresh without a new Flutter build.

Evidence to record per slice:

- release/build and pilot UID reference (do not write email or tokens);
- flag name, start/end time, pass/fail counts, and sanitized diagnostic count;
- legacy/V2 parity result and any accepted difference;
- rollback test time and confirmation that the legacy screen returned.

## Required commands

```bash
flutter analyze
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test
(cd scripts && npm test)
```

## Local release evidence

- 2026-08-23: `flutter analyze` — passed with no issues.
- 2026-08-23: architecture and Firestore query guards — passed (13 tests).
- 2026-08-23: full Flutter suite — passed (369 tests).
- 2026-08-23: full Hostinger/Node suite — passed (148 tests).
- The Phase 007 flags remain fail-closed and disabled unless the authenticated
  actor is included in the server-owned pilot configuration.
- No production deployment, pilot enablement, or shared-secret change was made
  by this local verification run.

T064 remains release-gated: it needs a real owner-reviewed pilot for each slice,
captured parity/rollback evidence, and rotation of the previously shared sales
credential in Hostinger secret storage.

## CEO-100 direct-manager preflight

`CEO-100` may hold an HR role while also being the active direct manager for
some employees. Before any release, verify that a request whose current
`managerId` is the CEO account is visible in the CEO queue and produces one
manager-stage notification. Cover leave, permission, advance, administrative
request, and resignation flows.

The application routes these requests by the current `managerId` and keeps the
separate `pending_ceo` final stage scoped to `ceoId`. The current Firestore
rule for an advance manager decision still admits only a `manager` role (or
super-admin). If the CEO account remains an HR role, an owner-approved rules
release is required before enabling CEO approval of an assigned advance. Keep
the prior rules artifact available for immediate rollback and record the rule
release ID, pilot UID, one approved decision, one rejected decision, and the
rollback confirmation here. No rule publication is included in this code
change.
