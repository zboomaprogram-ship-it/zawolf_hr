# Feature 020 — Execution Status

Updated 2026-10-27. **In progress; not ready for pilot activation.**

The owner approved local implementation after reviewing the specification, plan and tasks, then requested completion of feature 020. The earlier draft/unstarted labels were stale and have been corrected. Verified completed substeps are now checked directly in [tasks.md](tasks.md). Unchecked grouped requirements remain incomplete even where some of their substeps are checked; no T01–T14 task is fully complete. Source files alone are not completion evidence.

## Owner decisions

- Keep all configurable business policies in the existing **سياسة الدوام** screen.
- Remote days use personal computers; office days use company computers.
- Selected remote verification: **HR-approved registration plus passkey** (`hr_approved_passkey`). Synced passkeys are permitted. This verifies the approved credential/user verification and does not guarantee one physical computer. This supersedes the original physical-computer-binding starter choice, without waiving signature, challenge, origin/RP, company, enrollment or replay validation.
- The intended site is `https://zawolf-hr-system-60317.web.app`; the candidate RP ID is `zawolf-hr-system-60317.web.app`. Employees use Windows with Chrome or Brave. The owner cannot provide a Windows machine for testing.
- Production deployment, rule publication, pilot activation and data repair have not been performed.

## Implemented continuation

- Draft editor preserves edits made during a pending save, keeps the resulting server version, discards stale load/save results after changing drafts or closing, and blocks overlapping saves.
- Approval, publication and revert preserve command identity across an interrupted response within the current editor lifetime. Changed payloads receive a new operation ID; concurrent publication actions are blocked. Revert retries reuse the same new draft ID.
- Published/scheduled receipts include the resulting draft version. History revision IDs round-trip through the revert endpoint.
- Eligibility respects the configured weekly allowance even with approved authorizations; multi-date schedules count only dates in the selected week; an approved replacement removes the original date; malformed calendar dates reject safely.
- Local Firestore rules prevent settings clients from deleting the company projection to erase a protected attendance policy. Emulator tests exercise direct read/create/update/delete denial of server-owned policy and capability records while allowing unrelated settings updates.
- Corrected the invalid chat-image test fixture exposed by full verification. Only test bytes/MIME/name changed; chat production code was not changed.

## Latest continuation — contracts, schedules, day-mode lock, and atomic attendance (2026-10-28)

- Created `contracts.js` defining immutable command kinds (`COMMAND_KINDS`), user-safe error taxonomies (`SAFE_ERROR_CODES`), and structural command validation.
- Created `remote_work_models.dart` providing pure Dart domain entities (`ActorScope`, `RemoteCommand`, `RemoteProof`, `RemoteReceipt`, `RemoteEligibility`, `RemoteSchedule`, `WeeklyRemoteException`) without infrastructure dependencies.
- Created `schedules.js` executing `saveRemoteSchedule` within Firestore transactions, verifying actor authorization, preventing schedule overlap, monotonically advancing `remoteWorkCalendarGuards/{companyId}` epoch to invalidate stale authorization cache, and logging immutable audit/idempotent receipts. Verified with 12 tests in `remote-work-schedules.test.js`.
- Created `day-mode-guard.js` enforcing `enforceDayMode`: locks the attendance shift date to either `remote_web` or `office`, rejecting mid-day switching (`mode_locked`).
- Created `attendance-commands.js` executing atomic `check_in` and `check_out` with session creation, single-use cryptographic challenge consumption (`consumeVerifiedChallenge`), idempotent replay lookups, and audit logging. Verified with passing tests in `remote-work-attendance.test.js`.
- Created `attendance-finalization.js` exporting `finalizeRemoteShift` for atomic shift completion and missing-checkout detection.
- Created `financial-holds.js` and `recovery.js` handling IT incident declarations (`declareRemoteIncident`), automatic coverage generation, HR financial hold resolution (`resolveRemoteFinancialHold`), and audited attendance corrections (`correctRemoteDay`). Verified with passing tests in `remote-work-recovery.test.js`.
- Created `session-commands.js` executing versioned daily plans (`save_plan`), periodic update slots (`submit_update`), and summaries (`save_summary`). Verified with passing tests in `remote-work-sessions.test.js`.
- Created `queries.js` providing bounded cursor queries (`listRemoteDays`) with strict actor isolation, and pure Dart repository contract `remote_work_repository.dart`. Verified with passing tests in `remote-work-queries.test.js`.
- Generated detailed status and architectural documentation in [FULL_WORK_REPORT.md](FULL_WORK_REPORT.md). All 536 Node tests and 50 Flutter remote work/architecture tests pass cleanly.

## Latest continuation — scheduled publication and review

- Added `policy-activation.js`: future revisions become effective transactionally through the existing Hostinger background/manual dispatch paths. The head, whole attendance-policy projection, calendar guard and activation audit change together. Revision snapshots stay immutable.
- Activates by effective time, including schedules published out of order, and cannot restore an older policy over a later immediate publication. Discovery is capped at ten due company heads per tick. Failed heads receive retry backoff without changing their scheduled effective time or overwriting a changed head.
- Immediate and scheduled publication replace the whole `attendancePolicy` field using an explicit root-field mask while preserving unrelated company settings. Actual emulator regressions proved recursive merging retained removed restrictions; both publication and activation now remove them.
- Approval binds normalized content and effective instant. Editing either clears old approval, publication rechecks the content hash, the publisher cannot substitute a date, and published/scheduled drafts cannot reopen.
- The editor rotates to a fresh draft after publication, synchronizes the publication draft identity, preserves saved effective time and advances its draft version after approval. New dashboard controls display/select date, time and local timezone and block approval/publication while visible edits are unsaved or an action is pending.
- Added a [writer integration inventory](writer-inventory.md). Legacy writer migration and exact action-time policy resolution remain separate unfinished work.

## Latest local continuation — qualification safeguards and contracts

- Added a company policy snapshot reader selecting immutable revisions at the supplied server time, including when activation is delayed. Scoped employee/team/date resolution and attendance integration remain unfinished.
- Enabled policy publication and activation now require a current server-owned qualification record; revoked or changed qualification fails closed. Local rules deny client access to these records. No actual profile has been qualified or written to production.
- Extended pure eligibility and added schedule/exception validation with tests; persisted commands, approval routes and attendance integration remain unfinished.
- Added an isolated pinned WebAuthn test spike. Virtual localhost tests exercise registration, assertions and rejection of invalid origin, RP, challenge, signature and user verification. The library accepts a replay when the application does not consume challenges; T04 must implement atomic single-use enforcement.
- Pushed only the isolated test workflow and spike to `codex/020-webauthn-qualification` (commit `767e324`) for [Windows CI](https://github.com/zboomaprogram-ship-it/zawolf_hr/actions/runs/40466096604); both Chrome and Brave jobs passed. Virtual authenticators cannot establish real Windows Hello behavior or production-origin qualification. The feature working tree remains uncommitted.

## Latest continuation — challenge transaction primitive

- Added a server-only challenge-consumption primitive that binds actor, company, action, operation, date, payload and credential, rejects expiry and replay, and writes consumption in the caller’s action transaction. The caller must provide a trusted cryptographic verification result and transactionally recheck credential and account state; no handler currently invokes it. Challenge issuance, cryptographic verification and attendance integration remain unfinished.
- A local Firestore emulator contention test committed exactly one of two competing action writes; rollback and binding tests also passed. The emulator run had 14 passing tests. The Node suite after adding expiry tests had 506 passing and 7 skipped emulator-only tests.
- Qualification comparison now compares the defined evidence fields without relying on map key order; a regression checks changed evidence is rejected.

## Latest continuation — production WebAuthn verifier

- Added pinned `@simplewebauthn/server@14.0.3`, a Node 22 backend engine minimum and a fail-closed runtime check. Hostinger's actual Node runtime remains unverified; the profile must stay unavailable there until compatible.
- Implemented registration/assertion option generation and server verification. Both require user verification and bind to the qualified origin/RP/profile version, credential and challenge. Multi-device backup/counter metadata is retained. Challenge consumption now requires an in-process branded result from cryptographic verification, so a client JSON boolean cannot impersonate proof.
- The production adapter passed a virtual-authenticator Chrome 150 journey on macOS and Windows Server 2022 Chrome/Brave CI: registration, assertion, backup metadata, atomic single use/replay rejection and missing-UV rejection. This does not test real hardware, Windows Hello or production origin.
- Final backend run: `npm test` **527 passed, 7 emulator-only skipped**. The Firestore emulator challenge suite passed 20 tests with branded proof, including two competing transactions with exactly one committed action; `npm audit` reports zero vulnerabilities after `npm audit fix`; source syntax and diff checks passed.

## Latest continuation — configurable challenge bounds and operation identity

- Challenge expiry now honors a snapshotted policy lifetime within the explicit server capability bound of 1–300 seconds. The schema checks the same optional field. A future issuer must derive and snapshot this value from an authoritative published policy; issuance and dashboard editing remain open.
- Added canonical operation hashing that ignores ephemeral proofs, detects meaningful action changes and rejects non-JSON, cyclic, sparse and oversized inputs. Receipt storage, action schemas and attendance command wiring remain open.
- Qualification now rejects invalid current/effective server times instead of letting invalid dates bypass expiry checks.
- Focused tests passed for the new validation and hashing behavior. The Firestore emulator challenge suite passed 20 tests including contention, and a backend suite passed before the final identity edge-case fix; the final identity test independently passed.

## Latest continuation — schedule policy validation

- Schedule validation and weekly exception resolution now consistently reject malformed eligibility policies, including non-array, duplicate or out-of-range weekdays and allowances exceeding available weekdays. Previously a malformed weekday value could throw, and some invalid configurations could reach date resolution.
- A regression reproduced the exception before the fix; the focused schedule and eligibility suite passed 24 tests afterward. These remain pure contracts, not persisted schedule commands or attendance integration.

## Latest continuation — safe policy merging

- Policy resolution and the exported merge helper reject prototype-related property names, including nested values and exception policies, before merging. A regression reproduced prototype mutation before the fix. The focused policy, snapshot and schedule suite passed 35 tests; this does not complete scoped policy resolution.

## Verification

Local checks on 2026-10-27: `npm --prefix scripts test` 488 passed, 6 skipped; `flutter analyze` passed; focused remote-work, architecture and query Flutter tests 50 passed; explicit local Firestore emulator matrix 6 passed, with additional qualified-snapshot emulator coverage passing. The isolated virtual-browser spike passed locally on macOS Chrome. These are intermediate checks, not final T13 acceptance.



Final checks for this continuation (2026-10-26):

- `flutter analyze`: **passed, no issues**.
- `flutter test test/features/remote_work test/architecture_guard_test.dart test/firestore_query_guard_test.dart --reporter expanded`: **50 passed**, including the remote editor/publication, date/time controls, dirty/busy review actions and architecture/query checks.
- `npm --prefix scripts test`: **451 passed, 5 emulator tests skipped** in the normal suite.
- Explicit loopback `demo-remote-work` Firestore emulator run of `remote-work-policy-emulator.test.js`, `remote-work-policy-rules.test.js` and `remote-work-emulator.test.js`: **5 passed**. Covers actual concurrent publication/activation, receipt replay, due discovery and progression, whole-map replacement with unrelated settings preserved, and denied direct policy/grant writes. Emulator metadata lookup warnings did not fail these tests.
- Full `flutter test --reporter expanded`: **705 passed, 5 failed**. The remaining failures are the same unchanged baseline tests: HR and Super Admin workspace visibility (`test/navigation/operational_admin_navigation_test.dart`), request search source assertion (`test/screens/hr/requests_management_screen_test.dart`), field-mission approval source assertion (`test/screens/employee/employee_field_mission_request_test.dart`), and form-autovalidation source assertion (`test/screens/employee/employee_request_form_validation_test.dart`). No full-suite success is claimed.
- `node --check scripts/notification-web.js`, `node --check scripts/remote-work/policy-activation.js` and `git diff --check`: passed. New policy Cubits remain 217/278 lines.

The prior chat fixture repair remains verified: its nine tests pass and that failure no longer occurs in the full run. Red/green evidence for each new behavior is recorded in the execution ledger; no current check is inferred from an older pass.

## Remaining implementation

T01 still needs real-device registration/assertion qualification, actual server runtime compatibility and production dependency selection/pinning, and recovery/retention decisions for the selected passkey profile. Emulator coverage is not real-device qualification.

T02/T03 and T14 are partial: further schedule/exception commands, reporting scope, full policy/schema/governing-approval coverage, scoped policy resolution, offline policy drafts and broader dashboard acceptance remain. Company-wide future activation and the review controls above are verified; they do not complete the full policy foundation. The pure resolver currently receives supplied scopes; authoritative employee/date resolution is not complete.

T04–T12 attendance commands, single-mode lock across every writer, enrollment/passkey integration, legacy/leave adapters, work evidence/local storage, recovery/financial holds, bounded scoped queries, employee/HR/IT/manager journeys and durable reminder workers remain to be delivered. T13 requires the completed acceptance matrix, qualified-device journeys, actual scheduler-ownership verification and rollback/pilot handoff.

The current continuation is on `codex/remote-work-020-continuation`. The working tree includes the earlier unfinished implementation. No unrelated changes were staged or committed. The separate test-only CI branch contains the isolated spike commit described above.
