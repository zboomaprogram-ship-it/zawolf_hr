# Phase 006 acceptance evidence

## Automated checks

- 2026-08-22: `flutter analyze` — passed with no issues.
- 2026-08-22: `flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart` — passed (11 tests).
- 2026-08-22: `(cd scripts && npm test)` — passed (127 tests).
- 2026-08-22: `flutter test` — passed (288 tests).
- 2026-08-22: Focused Workspace V2 tests — passed:
  - report and Company Files widgets;
  - outbox persistence and sync Cubit recovery;
  - activity/report idempotency, audit privacy, V2 resource-ID, and resilience Node tests.
- 2026-08-23: `flutter analyze` — passed with no issues after the status/retry and department-folder controls.
- 2026-08-23: Focused V2 presentation suite — passed (14 tests), including Company Files, controller access, reports, sheet editor, and RTL/accessibility coverage.
- 2026-08-23: `(cd scripts && npm test)` — passed (127 tests).
- 2026-08-23: `flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart` — passed (11 tests).
- 2026-08-23: `flutter test` — passed (290 tests).
- 2026-08-23: repository-wide revalidation after Phase 007 integration:
  `flutter analyze` passed, architecture/query guards passed (13 tests), the
  full Flutter suite passed (369 tests), and the full Node suite passed (148
  tests).

## Deliberately not recorded as complete

Non-production Google acceptance, pilot enablement, and default-route approval
require a separate controlled run and owner approval. The V2 feature flag
remains disabled by default.

## Release-gated live checks

- 2026-08-23: T033 implemented: secure server-authorized binary download and
  immediate restore action after a successful trash operation. The UI never
  exposes a Drive URL or provider error.
- 2026-08-23: T060 implemented: `/company-workspace/v2/pilot` is fail-closed,
  server-authorized for dynamic IT managers/super admins, and writes an
  append-only `workspace_pilot_changed` audit record. The controller screen
  includes a limited-audience editor and immediate rollback control.
- T085 remains a real non-production Google run: it must use test identities
  and a test root, then record the generated resource/report IDs here.
- T091 remains a limited live pilot: enable only test/pilot Firebase UIDs in
  the controller screen, then verify audit/report metrics before documenting
  the result here.
- T092 remains deliberately off until T085/T091 evidence and the owner's
  written default-route approval exist. The remote flag defaults to legacy on
  every failed request.
