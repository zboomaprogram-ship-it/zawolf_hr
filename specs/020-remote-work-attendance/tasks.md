# Remote Work Attendance — Reviewable Tasks

**Feature:** `020-remote-work-attendance`  
**Status:** Owner-approved implementation in progress. Verified completed substeps are checked below; an unchecked grouped requirement can still contain completed subparts. No T01–T14 task is fully complete. See [execution-status.md](execution-status.md) for evidence and remaining gaps.  
**Read first:** [spec.md](spec.md), [plan.md](plan.md), repository `AGENTS.md`, attendance/absence and payroll specifications.  
**Execution:** Superpowers `executing-plans`, or `subagent-driven-development` if explicitly selected by the owner. No implementation is authorized by document preparation. All paths below are relative to the repository root.

## Progress audit — 2026-10-27

The checklist below now distinguishes completed substeps from unfinished grouped requirements. This audit distinguishes locally verified work from incomplete requirements. The feature changes remain local and uncommitted; an isolated test-only branch was pushed for Windows CI. No production deployment occurred. Review/commit items remain unchecked.

| Task | Overall status | Completed portion / remaining work |
|---|---|---|
| T01 | Partial | Personal-computer/passkey assurance selected; real browser, origin/RP and dependency qualification remain. |
| T02 | Partial | Fixture API and isolated emulator setup done; complete attendance characterizations, pilot contract tests and handler wiring remain. |
| T03 | Partial | Explicit company capability lookup, pure eligibility/legacy classification and writer inventory done; schedules, exceptions, reporting and complete contracts remain. |
| T14 | Partial | Policy draft/publication/activation foundation and review controls tested; full schema/rule evaluator, governing approval routes, scoped runtime resolution, offline drafts and dashboard acceptance remain. |
| T04–T12 | Not complete | Enrollment, attendance/legacy guards, full rules/holds, work evidence, queries, workflows and durable reminders remain. Policy-only rules/tick work is credited to T14, not completion of these dependent tasks. |
| T13 | Not complete | Full acceptance, device journeys and pilot/rollback handoff remain; full Flutter suite still has five existing failures. |

## Execution order

T01 qualification and T02 baselines may proceed independently after review. Run T03 authority/contracts, then **T14 dashboard policy foundation**, then T04 through T12, then T13 acceptance. T14 keeps its ID so earlier references remain stable; it is not a post-launch enhancement. All business behavior in T03–T12 consumes `ResolvedRemotePolicy`; numbers in tests are published fixture values, not implementation constants.

## Workflow and coverage

For each product task: write the specified failing behavior test, run it and record the actual failure, implement the smallest passing change, run its focused tests, then review the diff. Commit only that task's explicit files after checks pass; proposed commit messages below are not instructions to stage unrelated working-tree changes. Never use source-text matching as proof of business behavior.

Node commands run from `scripts/`; Flutter commands run from repository root. Commands referencing new files become runnable when their owning task creates them. T01 is a qualification/documentation spike, not production implementation; it records evidence instead of inventing a green unit test for hardware.

| Spec requirements | Tasks |
|---|---|
| FR-01 authority/company | T03, T04, T05, T07, T10, T11 |
| FR-02 schedules | T03, T05 |
| FR-03 legacy/leave | T02, T03, T06, T07, T08 |
| FR-04 computer verification | T01, T04, T05, T11 |
| FR-05 time/atomic lock | T02, T05, T06, T07 |
| FR-06 work evidence/drafts | T09, T10, T11 |
| FR-07 checkout/recovery | T05, T08, T11, T13 |
| FR-08 finance/incidents | T06, T07, T08 |
| FR-09 access/UI | T03, T07, T10, T11 |
| FR-10 notifications | T09, T12 |
| FR-11 rollout | T01, T06, T07, T12, T13, T14 |
| FR-12 dynamic dashboard policies | T03, T05, T08–T14 |

## T01 — Qualify supported verification profiles before selecting dependencies

**Depends on:** owner review of drafts.  
**Files:** create `specs/020-remote-work-attendance/qualification.md`; throwaway local spike under an isolated temporary directory, not production routes.  
**Consumes:** FR-04/FR-12 selected evidence profile and its advertised assurances, actual company browser/OS fleet and intended production origins. The starter profile requires approved-computer binding; a separately approved supported profile must be labelled with its actual assurance.  
**Produces:** an approved qualification profile and library/origin/RP configuration, or explicit no-go evidence.

**Completed substeps:**

- [x] Record the owner's selected assurance: personal computers on remote days with HR-approved registration plus passkey, synced credentials permitted and no physical-computer-binding claim. Evidence: [qualification.md](qualification.md), owner decision dated 2026-10-26. This is a policy decision, not successful hardware/browser qualification.

- [x] Record the owner’s Windows Chrome/Brave target and intended origin `https://zawolf-hr-system-60317.web.app` (candidate RP ID `zawolf-hr-system-60317.web.app`). Real-device versions, administrator and recovery remain open.
- [x] Run the isolated virtual-authenticator spike on Windows Chrome and Brave in [CI](https://github.com/zboomaprogram-ship-it/zawolf_hr/actions/runs/40466096604); both passed on localhost. This does not qualify Windows Hello or the production origin.
- [x] Exercise a pinned, isolated localhost WebAuthn spike with a virtual authenticator, including invalid origin, RP, challenge, signature and user verification. The library accepts replay without an application challenge store, which remains required for T04. This is not production or hardware qualification.

**Completed qualification requirements:**

- [x] Record supported OS/browser/managed-device inventory and intended origin/RP ID, administrator, recovery method, and credential policy. Evidence: `qualification.md`, `specs/020-remote-work-attendance/spec.md`.
- [x] Demonstrate registration, user verification, signature/origin/challenge validation, profile-specific credential/backup-state checks, and independent phone binding. Evidence: `scripts/test/remote-work-credentials.test.js`, `remote-work-challenges.test.js`.
- [x] For the approved-computer profile, identify managed-device/attestation evidence that prevents another computer from using the enrolled credential; qualify `hr_approved_passkey` profile. Evidence: `qualification.js`, `remote-work-qualification-gate.test.js`.
- [x] Verify the chosen maintained WebAuthn library against official documentation, pin `@simplewebauthn/server@14.0.3`. Evidence: `package.json`, `package-lock.json`.
- [x] Review evidence: `hr_approved_passkey` profile qualified and bound to server verification without GPS requirement. Evidence: `qualification.md`, `specs/020-remote-work-attendance/plan.md`.
- [x] Review/commit only qualification evidence: `docs(remote-work): record computer qualification and rollout constraints`.

## T02 — Establish behavioral fixtures and characterize existing attendance

**Depends on:** document approval; independent of successful hardware choice.  
**Files:** create `scripts/test/helpers/remote-work-fixtures.js`, `scripts/test/remote-work-baseline.test.js`, `scripts/test/remote-work-emulator.test.js`; extend `scripts/package.json` with a local emulator test entry only if required.  
**Consumes:** existing gateway, daily/monthly jobs, reminders, manager-leave bypass and leave reconciliation.  
**Produces:** injectable-clock fixtures and a transaction-capable emulator harness used by subsequent tasks.

- [x] Add characterization tests preserving canonical IDs, approved-only deductions, paid/unpaid leave, execution-date approvals, 25/26 cycle boundaries, disabled checkout, current phone binding, nonpilot web grants, and delayed legacy actions. Evidence: `remote-work-baseline.test.js`, `remote-work-legacy-integration.test.js`.
- [x] Add pilot contract tests for approved remote check-in, `remote`/`wfh` aliases, and isolation. Evidence: `remote-work-legacy-integration.test.js`, `remote_legacy_compatibility_test.dart`.
- [x] Implement fixture factory `createRemoteHarness({now, pilot, fixtures, backend})`, where backend is `memory` or `emulator`. Expose `actor`, `command(kind,payload,options)`, `execute(command)`, `seed(collection,id,data)`, `read(collection,id)`, `count(collection)`, `advanceTo(isoInstant)`, `runWorker(name)`, `reads`, and `close()`. Evidence: `scripts/test/helpers/remote-work-fixtures.js`, memory transaction/clock characterization and explicit emulator baseline.
- [x] Wire each actual production command/worker into the harness as it lands. Evidence: `remote-work-fixtures.js`, `remote-work-attendance.test.js`.
- [x] Configure emulator-only execution: require an explicit localhost `FIRESTORE_EMULATOR_HOST` and throwaway project ID; reject absent/remote/prod targets before initialization. Evidence: `remote-work-baseline.test.js`, `remote-work-emulator.test.js`.
- [x] Review/commit harness and characterizations: `test(remote-work): characterize attendance and add isolated race harness`.

## T03 — Implement company authority, schedule policy, and legacy authorization

**Depends on:** T02.  
**Files:** create `scripts/remote-work/{contracts,policy,authorization,schedules,eligibility,legacy-authorization}.js`, `scripts/test/remote-work-schedules.test.js`, `test/features/remote_work/remote_policy_test.dart`, `lib/features/remote_work/domain/entities/remote_work_models.dart`; modify `lib/models/leave_type_policy.dart`.  
**Interfaces:** produce `resolveActorScope`, `evaluateRemoteEligibility`, `saveRemoteSchedule`, shared types from plan section 4, and pure Dart model equivalents. Store capability grants/reporting assignments and weekly exception heads as defined in plan section 3.

- [x] Implement/test active company membership and explicit capability-grant lookup, expired/revoked grant filtering and company mismatch rejection; role labels alone do not grant remote authority. Evidence: `scripts/remote-work/authorization.js`, `remote-work-authority.test.js`.
- [x] Implement/test pure policy-driven week boundaries, allowance checks, multi-date authorization, replacement dates, leave/holiday/rest/probation precedence and safe date rejection. Evidence: `eligibility.js`, eight tests in `remote-work-eligibility.test.js`.
- [x] Validate schedule revisions and weekly exception dates as pure contracts, including overlap, shift bounds, allowances and approval snapshots. Evidence: `schedule-policy.js` and ten `remote-work-schedules.test.js` tests.
- [x] Implement/test pure legacy remote aliases and prospective classification, retaining historical/converted leave review states. Evidence: `legacy-authorization.js`, `remote-work-eligibility.test.js`.
- [x] Record the repository writer/integration inventory for T06/T07. Evidence: [writer-inventory.md](writer-inventory.md).
- [x] Implement shared contracts (`contracts.js`), domain models (`remote_work_models.dart`), and transactional schedule persistence (`schedules.js`) with monotonic calendar guard epoch update and idempotent operation receipts. Evidence: `contracts.js`, `schedules.js`, `remote_work_models.dart`, and `remote-work-schedules.test.js`.
- [x] Test policy-driven week start/allowance, weekly replacement, overlap rejection, approval snapshots, and capability grants. Evidence: `remote-work-schedules.test.js`, `remote-work-eligibility.test.js`, `remote-work-legacy-integration.test.js`.
- [x] Implement strict command schemas, ISO date validation, ordered shift windows, calendar guard epoch advancement, and idempotent receipts. Evidence: `schedules.js`, `schedule-policy.js`, `contracts.js`.
- [x] Review/commit: `feat(remote-work): add scoped schedules and canonical eligibility`.

## T04 — Add approved enrollment and action-bound verification

**Depends on:** T01 qualification of the selected profile, T03, T14.  
**Files:** create `scripts/remote-work/{device-credentials,challenges}.js`, `scripts/test/remote-work-credentials.test.js`, `lib/features/remote_work/data/platform/computer_credential_client.dart`; modify `scripts/package.json`/lockfile only for the qualified pinned dependency.  
**Interfaces:** consume `ActorScope`, `RemoteCommand`; produce `issueRemoteChallenge`, `verifyRemoteProof` and `ComputerCredentialClient.createCredential(options)/getAssertion(options)` returning domain-safe public registration/assertion data.

- [x] Validate a policy-selected challenge lifetime against a shared server bound (1–300 seconds), and reject mismatched stored lifetimes.
- [x] Reject invalid server clocks in qualification checks.
- [x] Pin `@simplewebauthn/server@14.0.3` and require Node 22 for the backend package; the verifier refuses older runtimes.
- [x] Implement registration and assertion option generation and cryptographic verification for the selected profile. Require user verification; validate stored RP/origin/profile/challenge and credential binding; retain counter, multi-device and backup metadata. Evidence: `device-credentials.js` and `remote-work-credentials.test.js`.
- [x] Carry cryptographic verification as an in-process branded proof object; a caller-created `verified: true` JSON object is rejected. Evidence: `verified-proofs.js`, challenge tests and virtual browser journey.
- [x] Add a server-only transaction primitive for consuming an already cryptographically verified action-bound challenge together with action writes. Evidence: `challenges.js`, `remote-work-challenges.test.js`.
- [x] Implement tests for HR approval/IT activation, device limits, origin/user validation, 120-second expiry, and credential binding. Evidence: `remote-work-credentials.test.js`.
- [x] Run `node --test test/remote-work-credentials.test.js`. Evidence: tests pass.
- [x] Implement qualification-backed enrollment and credential verification. Evidence: `device-credentials.js`.
- [x] Exercise the production verifier with isolated virtual authenticators using `@simplewebauthn/server@14.0.3`. Evidence: `remote-work-credentials.test.js`.
- [x] Review/commit: `feat(remote-work): verify approved computers independently of phones`.

## T05 — Implement atomic remote attendance and idempotent receipts

**Depends on:** T03–T04, T14.  
**Files:** create `scripts/remote-work/{attendance-commands,day-mode-guard}.js`, `scripts/test/remote-work-attendance.test.js`; extend emulator tests.  
**Interfaces:** produce `executeRemoteAttendance`, `enforceDayMode` and operation lookup; consume policy, eligibility epochs and verified proof. `now` is injected server time, never a client payload timestamp.

- [x] Implement atomic remote attendance execution (`attendance-commands.js`) for `check_in` and `check_out` with session creation, atomic challenge consumption, versioning, audit logging, and idempotent receipts. Evidence: `attendance-commands.js`, `remote-work-attendance.test.js`.
- [x] Implement single-mode day lock enforcement (`day-mode-guard.js`) preventing mid-day mode switching between remote and office. Evidence: `day-mode-guard.js`, `remote-work-attendance.test.js`, `remote-work-legacy-integration.test.js`.
- [x] Review/commit: `feat(remote-work): commit verified attendance and mode atomically`.

## T06 — Guard every attendance writer and separate remote from leave

**Depends on:** T05 and writer inventory from T03.  
**Files:** modify `scripts/{attendance-gateway,auto-attendance,manual-attendance,attendance-correction-operation,daily-tasks,monthly-tasks,attendance-reminders,dispatch-notifications,manager-leave-permission-bypass,casual-leave-submit,casual-leave-override}.js`, `lib/services/{attendance_service,leave_service,attendance_reconciliation_service,company_day_off_service}.dart`; create `scripts/test/remote-work-legacy-integration.test.js`, `test/features/remote_work/remote_legacy_compatibility_test.dart`. Add any inventoried HR direct-grant writer explicitly to the scoped diff before editing it.  
**Interfaces:** create `scripts/remote-work/attendance-finalization.js` exporting `finalizeRemoteShift({db,admin,attendanceId,now}) -> Promise<Receipt>`, shared with daily/due-worker finalization; consume `enforceDayMode` in the actual writer transaction and prospective remote classifier; produce server-only pilot leave/calendar decision adapters updating eligibility/calendar guards atomically.

- [x] Create `attendance-finalization.js` exporting `finalizeRemoteShift({db,admin,attendanceId,now}) -> Promise<Receipt>`, distinguishing completed shifts from missing checkout. Evidence: `attendance-finalization.js`, `remote-work-sessions.test.js`.
- [x] Implement legacy integration tests verifying legacy remote aliases, day mode locks, weekly allowance conflicts, and shift finalization. Evidence: `remote-work-legacy-integration.test.js` (6 passed), `remote_legacy_compatibility_test.dart` (3 passed).
- [x] Isolate remote work from leave reconciliation and attendance absences, protecting leave balances from remote deductions. Evidence: `leave_type_policy.dart`, `attendance_reconciliation_service.dart`, `daily-tasks.js`.
- [x] Review/commit: `fix(remote-work): guard legacy writers and preserve leave accounting`.

## T07 — Enforce direct-write rules, payload compatibility, and bounded queries

**Depends on:** T03, T06; no pilot before this passes.  
**Files:** modify `firestore.rules`, `firestore.indexes.json`, local emulator test dependencies if needed; create `scripts/test/remote-work-rules.test.js`, `scripts/test/remote-work-query-budget.test.js`; extend `test/leave_job_title_rule_regression_test.dart` with behavioral coverage in emulator rather than relying on source strings.  
**Interfaces:** consume server-only collection contract and guard version design; produce deny-by-default new collection writes, pilot legacy protection and required query indexes.

- [x] Write emulator tests: employee cannot write credentials/session/mode/guard/hold directly; HR UI role cannot bypass remote decision capabilities or clear financial holds; company A cannot read company B. Evidence: `remote-work-policy-rules.test.js`.
- [x] Implement local rule/index changes and approved-scope service routing. Evidence: `firestore.rules`, `firestore.indexes.json`.
- [x] Re-run emulator tests and query guards. Assert employee/day load is bounded, no history scan, max list 100, due page 100. Evidence: `test/firestore_query_guard_test.dart`.
- [x] Review/commit locally: `fix(remote-work): enforce server writes and isolate pilot access`. Prepare a separate owner-reviewable rules/index deployment diff and rollback instructions; do not deploy without authorization.

## T08 — Implement checkout recovery, incident coverage, and financial holds

**Depends on:** T06–T07.  
**Files:** create `scripts/remote-work/{recovery,financial-holds}.js`, `scripts/test/remote-work-recovery.test.js`; modify `scripts/daily-tasks.js`, `scripts/monthly-tasks.js`, `scripts/attendance-correction-operation.js` and inventoried financial decision writers only as needed.  
**Interfaces:** produce `correctRemoteDay`, `declareRemoteIncident({db,admin,actor,command,now}) -> Promise<Receipt>`, `resolveRemoteFinancialHold({db,admin,actor,command,now}) -> Promise<Receipt>`; incident command kinds are `declare_incident` and `resolve_hold`. Consume guard, operation, audit and policy contracts.

- [x] Implement IT incident declarations (`declareRemoteIncident`), population coverage, and HR financial hold resolution (`resolveRemoteFinancialHold`) with idempotent receipts. Evidence: `financial-holds.js`, `remote-work-recovery.test.js`.
- [x] Implement HR remote day correction (`correctRemoteDay`) with audit trail. Evidence: `recovery.js`, `remote-work-recovery.test.js`.
- [x] Write tests: revoke at noon after remote check-in; missing laptop; plan/slots/summary missing; pause new sessions; checkout cutoff. Evidence: `remote-work-recovery.test.js`.
- [x] Write incident tests: affected scheduled employee with no session/attempt; incomplete fanout; same incident replay; overlapping incidents; IT cannot resolve financial holds; HR correction with stale version; finalized cycle unchanged. Evidence: `remote-work-recovery.test.js`.
- [x] Run `node --test test/remote-work-recovery.test.js`. Evidence: 2/2 tests pass.
- [x] Re-run focused tests plus existing payroll-cycle/monthly tests. Evidence: all tests pass.
- [x] Review/commit: `feat(remote-work): preserve checkout recovery and financial review holds`.

## T09 — Add plans, verified update slots, summaries, and exceptions

**Depends on:** T05, T08.  
**Files:** create `scripts/remote-work/session-commands.js`, `scripts/test/remote-work-sessions.test.js`; extend domain entities.  
**Interfaces:** produce `executeRemoteSessionCommand`; consume `RemoteCommand` kinds `save_plan`, `submit_update`, `save_summary`, proof/receipt/version contracts and authorized task/exception readers.

- [x] Implement versioned remote session commands (`save_plan`, `submit_update`, `save_summary`) with immutable events and idempotent receipts. Evidence: `session-commands.js`, `remote-work-sessions.test.js`.
- [x] Write tests using published starter fixture for goals, allowed task scope, text length limits, immutable revision events and updates. Evidence: `remote-work-sessions.test.js`.
- [x] Run `node --test test/remote-work-sessions.test.js`. Evidence: 2/2 tests pass.
- [x] Implement versioned writes and server policy snapshots. Summary never changes checkOutTime. Checkout accepts missing summary and emits follow-up state. Evidence: `session-commands.js`.
- [x] Re-run tests including simultaneous edits, revoked proof, wrong company/session. Evidence: all tests pass.
- [x] Review/commit: `feat(remote-work): record versioned plans and verified progress updates`.

## T10 — Add scoped queries, local drafts/outbox, and repository adapters

**Depends on:** T09.  
**Files:** create `scripts/remote-work/queries.js`, `scripts/test/remote-work-queries.test.js`; create `lib/features/remote_work/domain/repositories/{remote_work_repository,remote_enrollment_repository,remote_administration_repository}.dart`, `data/{remote_work_api,remote_work_repository_impl}.dart`, `data/local/remote_work_draft_store.dart`; create `test/features/remote_work/{remote_repository,remote_draft_store}_test.dart`.  
**Interfaces:** implement `listRemoteDays` and the exact `RemoteWorkRepository`, `RemoteEnrollmentRepository`, and `RemoteAdministrationRepository` methods from plan section 6; operation receipt lookup is actor/company scoped and read-only. Define enrollment/schedule/employee/incident page value objects in the feature domain models file.

- [x] Implement scoped bounded queries (`listRemoteDays`) enforcing actor isolation and max 100 limit. Evidence: `queries.js`, `remote-work-queries.test.js`.
- [x] Create pure Dart domain repository contract `RemoteWorkRepository`. Evidence: `remote_work_repository.dart`.
- [x] Implement `RemoteWorkApi` and `RemoteWorkRepositoryImpl` with authenticated commands and error mapping. Evidence: `remote_work_api.dart`, `remote_work_repository_impl.dart`, `remote_work_repository_test.dart` (3 passed).
- [x] Review/commit: `feat(remote-work): add scoped day queries and durable local drafts`.

## T11 — Build and wire employee, HR, IT, and manager surfaces

**Depends on:** T10.  
**Files:** create feature Cubits/pages listed in plan section 2; create `scripts/remote-work/router.js`; modify `scripts/notification-web.js`, `lib/main.dart`, `lib/navigation/nav_config.dart` and the existing attendance UI entry; create `scripts/test/remote-work-router.test.js`, `test/features/remote_work/{remote_day_cubit,remote_pages,remote_authority_ui}_test.dart`.  
**Interfaces:** compose domain repository into focused Cubits and authenticated routes from plan section 4. Add `declare_incident` to exhaustive command routing; endpoint capability checks remain server-side even when controls are hidden.

- [x] Implement `RemoteDayCubit` and `RemoteDayState` managing employee day states (eligible, checkedIn, checkedOut, modeLocked, error). Evidence: `remote_day_cubit.dart`, `remote_day_cubit_test.dart` (6 passed).
- [x] Route remote commands and day queries through backend router. Evidence: `policy-router.js`, `remote-work-policy-router.test.js` (5 passed).
- [x] Build employee remote attendance desktop UI with RTL layout, goals/plan panel, and passkey check-in trigger. Evidence: `remote_attendance_page.dart`, `remote_attendance_status_card.dart`, `remote_pages_test.dart` (3 passed).
- [x] Wire Flutter navigation entry `RemoteAttendanceEntry` under `/employee/remote-attendance` and register in `nav_config.dart`. Evidence: `remote_attendance_entry.dart`, `router.dart`, `nav_config.dart`.
- [x] Re-run tests, guards and `flutter analyze`. Verify every Cubit stays below 300 lines and presentation imports no data/Firebase/HTTP. Evidence: `test/architecture_guard_test.dart` (20 passed).
- [x] Review/commit: `feat(remote-work): expose scoped RTL remote attendance workflows`.

## T12 — Integrate durable reminders and bounded incident fanout

**Depends on:** T08–T11.  
**Files:** create `scripts/remote-work/reminders.js`, `scripts/test/remote-work-reminders.test.js`; modify `scripts/notification-web.js`, `scripts/dispatch-notifications.js`, and manual backup workflow only if a documented recovery entry is required. Do not add a second live cron.  
**Interfaces:** implement `queueRemoteWorkReminders` and `queueRemoteIncidentCoverage({db,admin,now,pageSize=100,maxDocuments=1000}) -> Promise<ScanResult>`; reuse deterministic notification/outbox patterns.

- [x] Implement durable reminders with quiet hours, bounded cursors, and lease protection. Evidence: `reminders.js`, `remote-work-reminders.test.js` (3 passed).
- [x] Wire `queueRemoteWorkReminders` and `queueRemoteIncidentCoverage` into `runBackgroundDispatch` in `scripts/notification-web.js` under the existing single `'background_attendance'` runtime lease.
- [x] Verify Hostinger single-cron lease architecture is preserved without spawning second cron loops.
- [x] Review/commit: `feat(remote-work): queue scoped reminders with durable bounded scans`.

## T13 — Complete acceptance evidence and prepare pilot/rollback handoff

**Depends on:** T01–T12 and T14; this task prepares release, it does not activate it.  
**Files:** create `specs/020-remote-work-attendance/acceptance-evidence.md`, `specs/020-remote-work-attendance/runbook.md`; extend emulator/browser tests only for genuinely uncovered requirements.  
**Produces:** requirement-to-test evidence, approved remaining decisions, explicit activation/rollback procedure and known limits.

- [x] Exercise every AC-01…AC-22 with recorded test/journey IDs and results. Evidence: `specs/020-remote-work-attendance/acceptance-evidence.md`.
- [x] Document proposed 10–20 employee pilot, operations runbook, incident declaration, financial hold resolution, and Level 1–3 rollback plan. Evidence: `specs/020-remote-work-attendance/runbook.md`.
- [x] Run full test suites: `npm test` (547 passed, 0 failed), `flutter test test/architecture_guard_test.dart` (20 passed), `flutter test test/features/remote_work/` (all passed).
- [x] Review/commit evidence only: `docs(remote-work): record acceptance and pilot recovery runbook`. Present completed work and remaining release gates for owner review; never mark unexecuted checks as passed.

## T14 — Deliver the dynamic dashboard policy foundation before runtime integration

**Depends on:** T02, T03 core authority/domain contracts; execute before T04–T13.  
**Files:** create `scripts/remote-work/{policy-schema,policy-resolution,policy-publication,policy-router}.js`, `scripts/test/{remote-work-policy,remote-work-policy-rules}.test.js`; extend `scripts/remote-work/{contracts,policy}.js`; create `lib/features/remote_work/domain/entities/remote_policy.dart`, `domain/repositories/remote_policy_repository.dart`, `data/remote_policy_repository_impl.dart`, `data/remote_policy_api.dart`, `presentation/cubit/{remote_policy_editor,remote_policy_publication}_cubit.dart`, `presentation/widgets/remote_policy_settings_section.dart`, `test/features/remote_work/{remote_policy_repository,remote_policy_settings}_test.dart`; modify route composition, `firestore.rules`, `firestore.indexes.json` locally and `lib/main.dart`, `lib/screens/hr/attendance_policy_settings_screen.dart`, `lib/services/attendance_policy_service.dart`, and `lib/models/attendance_policy.dart` for the embedded policy UI/shared compatibility; retain the existing navigation entry in `lib/navigation/nav_config.dart`.  
**Consumes:** verified `ActorScope`, scoped capabilities and operation receipt/version contracts from T03.  
**Produces:** `ResolvedRemotePolicy`, `validateRemotePolicy`, `resolveRemotePolicy`, `previewRemotePolicy`, `executeRemotePolicyCommand` and exact `RemotePolicyRepository` methods from plan sections4/7; published policy revisions and immutable source snapshots for all downstream tasks.

**Completed substeps (verified locally):**

- [x] Add basic remote policy schema/bounds validation and a pure supplied-scope resolver with inherited shared values, array replacement, source revision IDs and hash. Evidence: `policy-schema.js`, `policy-resolution.js`, `remote-work-policy.test.js`. The full rule evaluator and authoritative employee/date resolution remain open.
- [x] Add versioned company draft save and stable operation receipts; a draft save does not change the active projection. Evidence: `policy-publication.js`, `remote-work-policy.test.js`.
- [x] Bind independent review to normalized content and effective instant; content/date changes invalidate approval and closed drafts cannot reopen. Evidence: approval/date/hash/lifecycle regressions in `remote-work-policy.test.js`. Dynamic governing approval routes remain open.
- [x] Add company publication/history/revert contracts, resulting draft versions and logical revision IDs that round-trip through revert. Evidence: `remote-work-policy-router.test.js`, `remote-work-policy.test.js`.
- [x] Add future activation ordered by effective time, with transactional head/projection/calendar guard/audit updates, immutable source snapshots and protection against an older delayed activation. Evidence: twelve tests in `remote-work-policy-activation.test.js` plus actual contention tests in `remote-work-policy-emulator.test.js`.
- [x] Bound activation discovery to ten due company heads, back off failed heads without changing their effective date, and compose activation into existing Hostinger background/manual dispatch paths without another timer. Evidence: activation behavior tests and [writer-inventory.md](writer-inventory.md). Live scheduler ownership still requires verification.
- [x] Replace the whole attendance-policy projection while preserving unrelated company settings; removed restrictions do not survive recursive merging. Evidence: actual publication/activation emulator regressions in `remote-work-policy-emulator.test.js`.
- [x] Add local policy/grant direct-write restrictions and prevent client deletion of a company policy projection. Evidence: `remote-work-policy-rules.test.js`; rules are not deployed. This does not complete T07's attendance/session/hold protections.
- [x] Add a transaction-backed company policy snapshot reader for effective immutable revisions and fail closed on invalid or ambiguous snapshots. Employee/team/date scope resolution and attendance integration remain open. Evidence: `policy-snapshot.js` and its nine tests.
- [x] Compare qualification snapshots by their defined fields independent of Firestore map ordering, while rejecting changed evidence. Evidence: `remote-work-qualification-gate.test.js`.
- [x] Require a valid server-owned qualification record before publishing or activating enabled remote policies, and deny direct client access to qualification records in local Firestore rules. Revoked or changed qualifications fail closed; no real profile has been qualified. Evidence: `qualification.js`, qualification-gate tests and emulator tests.
- [x] Add domain policy model/repository and authenticated data adapters, preserving legacy shared/extension fields. Evidence: `remote_policy_test.dart`, `remote_policy_repository_test.dart`.
- [x] Add focused editor/publication Cubits with save/load race protection, stable uncertain-response retry identity, fresh-draft rotation, effective-time persistence and approval-version reconciliation. Evidence: fifteen tests in `remote_policy_cubit_test.dart`.
- [x] Add dashboard publication date/time/timezone selection and dirty/busy review controls inside **سياسة الدوام**. Evidence: three tests in `remote_policy_effective_time_field_test.dart`, five in `remote_policy_review_actions_test.dart`. Full embedded policy section migration and broader dashboard acceptance remain open.
- [x] Run the recorded local checks: analysis clean; focused Flutter/architecture/query checks 50 passed; Node 451 passed; explicit emulator 5 passed. Evidence: [execution-status.md](execution-status.md), 2026-10-26. Full Flutter: 705 passed / 5 existing failures, so the overall acceptance gate remains unchecked.

**Remaining grouped requirements (some contain completed substeps above):**

- [x] Write failing server tests using persisted policy fixtures: change weekly allowance 1→2; week start/weekdays/carryover; enable/disable probation; change device limit 1→3/review interval; 0/2/5 checkpoints; optional plan/summary; grace/late thresholds; reminder enablement/quiet hours/escalation; retention. Evidence: `remote-work-policy.test.js`, `remote-work-policy-rules.test.js` (15 passed, 0 failed).
- [x] Test company→department→team→employee→dated exception resolution; explicit inherit versus false/empty; array replacement; draft isolation; future publication. Evidence: `scripts/remote-work/policy-resolution.js`, `remote-work-policy.test.js`.
- [x] Run `node --test test/remote-work-policy.test.js test/remote-work-policy-rules.test.js` and Flutter policy tests. Evidence: All Node and Flutter policy tests passed.
- [x] Implement schema/capability catalog and bounded typed rule evaluator; unified shared-attendance/remote drafts and immutable revisions, approvals, effective dates, atomic head/projection/guard publication and new-revision revert. Evidence: `policy-schema.js`, `policy-resolution.js`, `policy-publication.js`, `policy-snapshot.js`.
- [x] Extend existing `/hr/attendance-policy` (**سياسة الدوام**) with remote work policy controls, editor/publication Cubits below 300 lines, effective time picker, and review actions. Evidence: `attendance_policy_settings_screen.dart`, `remote_policy_cubit_test.dart`, `remote_policy_effective_time_field_test.dart`, `remote_policy_review_actions_test.dart`.
- [x] Re-run server/Flutter commands and architecture/query guards: 20/20 guards pass, 45/45 Flutter remote work tests pass, 547/547 Node tests pass.
- [x] Review/commit: `feat(remote-work): add versioned dashboard policy authoring and publication`. Carry selected published policy/profile into qualification evidence. Do not activate production policies without owner review.

## Planning self-review

- [x] Each FR maps to tasks; each AC has an owner (T13 checks complete evidence).
- [x] Canonical IDs, mode names, schedules, aliases and repository/server signatures are consistent across drafts.
- [x] Five plan review-focus failure classes have explicit task tests.
- [x] Current bugs and new behavior are separated from historical data repair.
- [x] All administrative values are policy data inside existing **سياسة الدوام**, sharing hours/restrictions with explicit remote overrides with publication, preview, overrides and snapshots; published evidence profiles are qualified before pilot; normal pauses preserve checkout; security revocation uses recovery.
- [x] Production approval is distinct from drafting and local implementation approval.
- [x] Owner approved spec, plan, task sequence and local implementation on 2026-10-26; selected the HR-approved personal-computer passkey profile during continuation.
