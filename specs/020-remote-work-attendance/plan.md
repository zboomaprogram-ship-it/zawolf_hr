# Remote Work Attendance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or, if the owner chooses delegated execution, superpowers:subagent-driven-development. Implement the linked tasks one reviewable increment at a time. This document does not authorize execution.

**Goal:** Deliver dynamic attendance and remote-work business policies inside the existing سياسة الدوام screen without treating work as leave or creating a second attendance/payroll source.

**Architecture:** Add `lib/features/remote_work/{domain,data,presentation}` and a server-only `scripts/remote-work/` boundary beside legacy attendance. All modes use canonical attendance and transactional server guards; remote session documents contain work evidence only. Keep unrelated legacy behavior behind a server feature flag.

**Tech stack:** Existing Dart/Flutter, BLoC/Cubit, authenticated HTTP operation client, local Drift storage, Firebase Auth/Firestore and Node CommonJS Hostinger runtime. A maintained WebAuthn server library and browser interop are selected/pinned through the profile qualification task; no dependency is installed by this planning work.

**Spec:** [spec.md](spec.md)  
**Tasks:** [tasks.md](tasks.md)  
**Status:** Local implementation approved by the owner on 2026-10-26. Implementation is in progress; deployment, pilot activation and production repair are not approved. See [execution status](execution-status.md).

## Global constraints and editable starter values

- All remote-work business values are published dashboard data, not code constants. Starter preset: timezone `Africa/Cairo`, Saturday–Friday week, one remote date/week. Canonical accounting date remains Cairo shift-start date; policy-local shift date is stored separately.
- Canonical attendance ID `{userId}_{YYYY-MM-DD}`; modes exactly `remote_web` and `on_site_mobile`.
- Defaults: 08:45 open, 09:00 start, 09:30 plan, 11:00/13:00/15:00 updates, 15-minute grace, 16:45 closing reminder, 17:00 end. Shift end/cutoff have explicit day offsets; overnight shifts retain the original shift-start attendance key.
- Starter security settings (advanced dashboard fields within validated limits): challenge lifetime 120 seconds; five outstanding challenges; ten issues and ten verification attempts per actor per minute.
- Starter enrollment preset: one active enrolled credential for the selected personal-computer passkey profile, extra-credential HR/IT approval, six-calendar-month review. An enrolled-credential limit is not a physical-computer limit. Dashboard configures limits, routes, profiles and intervals. Independent phone binding is an integrity guarantee.
- Draft first in local storage; timed attendance/update evidence is online and server-verified only.
- Feature flag `remote_work_attendance_v1` defaults off; `remote_work_new_checkins_enabled` stops new remote sessions without disabling existing-session reads/checkout.
- Dashboard rules can disable consequences or propose pending financial review; no unreviewed automatic financial effect from plans, checkpoints or summaries. Preserve payroll day 26–25, execution-date attribution, and finalized-cycle behavior.
- New list pages default 50/max 100. Due scan page 100/max 1000 per tick with persisted continuation.
- Pure domain, no infrastructure imports in presentation, focused Cubits below 300 lines, Arabic RTL/desktop support.
- No production rules/flags/data changes, historical migrations, auto-commit of unrelated changes, or store deployment from this plan.

## Review focus

1. Old clients or forged platform fields must not bypass pilot authorization; cover all attendance writers and direct rules (T06/T07).
2. Leave approval, holiday edits, or revocation racing check-in must serialize through guards (T03/T05/T06).
3. Lost responses, midnight, and revoked credentials must return committed receipts without permitting a new operation (T05).
4. Rollback, missing summary, and globally disabled checkout must not strand a started day silently (T08/T11/T13).
5. Device claims, scoped caches, manager changes, and due backlogs must not expose another employee or silently lose events (T01/T04/T10/T12).

## 1. Delivery boundaries and gates

This is one connected attendance feature, delivered in independent increments. Local tests/qualification are required before pilot; notifications and device verification are not deferred until after employees depend on the feature. Preparation estimates in Antigravity's feasibility file are not acceptance criteria.

| Increment | Tasks | Reviewable result |
|---|---|---|
| Baseline and qualification | T01–T02 | Target fleet proof and failing characterizations; no product activation |
| Dashboard policy foundation | T03, T14 | Scoped draft/preview/approval/publish/revert and complete runtime policy snapshots |
| Authorization infrastructure | T04 | Scoped policy/schedules, legacy classification, approved credentials, emulator security |
| Attendance correctness | T05–T08 | Atomic remote/office lock, compatibility writers, payroll holds, recovery |
| Work evidence | T09–T10 | Versioned session updates, local drafts, scoped queries |
| Product and operations | T11–T12 | RTL employee/HR/IT/manager surfaces and durable reminders |
| Acceptance and release preparation | T13 | Completed evidence package and owner-reviewable pilot/rollback runbook |

Owner approval for local implementation was received on 2026-10-26. The selected remote profile is HR-approved registration plus passkey on personal computers, with synced credentials allowed and no physical-computer-binding claim. Qualification remains required before rollout. Execute T14 after T03 and before T04–T13; policy publication is a foundation, not a final UI setting added after hardcoded behavior. Failure to qualify the selected profile leaves that profile unavailable for publication and activation; propose a separately reviewed policy/device change rather than silently weakening it. A release remains disabled if any writer/eligibility guard or direct-rule bypass is unresolved.

## 2. File and responsibility map

Paths labelled new are proposed files, not claims that they exist.

| Files | Responsibility |
|---|---|
| New `scripts/remote-work/contracts.js`, `policy.js`, `policy-schema.js`, `policy-resolution.js`, `policy-publication.js`, `policy-router.js`, `authorization.js` | Command/policy schemas, versioned inheritance/preview/publication, shift windows and scoped capability/company resolver |
| New `scripts/remote-work/schedules.js`, `eligibility.js`, `legacy-authorization.js` | Revisioned schedules/exceptions and prospective legacy classification |
| New `scripts/remote-work/device-credentials.js`, `challenges.js` | Qualified enrollment, WebAuthn verification, expiry/revocation/rate limits |
| New `scripts/remote-work/attendance-commands.js`, `day-mode-guard.js` | Atomic remote attendance, operation receipts, shared office/automatic guard |
| New `scripts/remote-work/attendance-finalization.js` | Idempotent post-cutoff finalization shared with daily processing; revisit deferred overnight rows via due events |
| New `scripts/remote-work/session-commands.js`, `queries.js` | Plans, slots, summary, bounded minimized employee/manager queries |
| New `scripts/remote-work/recovery.js`, `financial-holds.js` | Corrections, explicit holds and authorized financial review |
| New `scripts/remote-work/reminders.js`, `router.js` | Due work/outbox handling and authenticated endpoints |
| Modify `scripts/notification-web.js` | Route composition and existing Hostinger tick integration only |
| Modify `scripts/attendance-gateway.js`, `auto-attendance.js`, `manual-attendance.js`, `attendance-correction-operation.js` | All canonical attendance writers honor the pilot guard |
| Modify `scripts/daily-tasks.js`, `monthly-tasks.js`, `attendance-reminders.js`, `dispatch-notifications.js`, `manager-leave-permission-bypass.js`, `casual-leave-submit.js`, `casual-leave-override.js` | Prospective remote classification, guard epochs, holds, reminder revalidation |
| Modify `lib/services/attendance_service.dart`, `leave_service.dart`, `attendance_reconciliation_service.dart`, `company_day_off_service.dart`, `lib/models/leave_type_policy.dart` | Narrow pilot adapters, canonical aliases, leave submission compatibility; no unrelated refactor |
| Modify `firestore.rules`, `firestore.indexes.json` locally | Deny new direct mutations, block pilot legacy bypass, protect guard updates/holds; index bounded queries |
| Modify `lib/screens/hr/attendance_policy_settings_screen.dart`, `lib/services/attendance_policy_service.dart`, `lib/models/attendance_policy.dart` | Embed remote settings within سياسة الدوام, share base values and preserve reader/serialization compatibility |
| New `lib/features/remote_work/domain/entities/remote_work_models.dart`, `domain/repositories/remote_work_repository.dart` | Plain values, receipt/version/failure contracts |
| New `lib/features/remote_work/domain/repositories/remote_enrollment_repository.dart`, `remote_administration_repository.dart` | Presentation-safe enrollment and scoped administrative contracts |
| New `lib/features/remote_work/data/remote_work_api.dart`, `remote_work_repository_impl.dart`, `local/remote_work_draft_store.dart`, `platform/computer_credential_client.dart` | Authenticated transport, partitioned Drift drafts/outbox, browser credential bridge |
| New `lib/features/remote_work/presentation/cubit/{remote_day,remote_enrollment,remote_schedule,remote_team}_cubit.dart` | One UI responsibility each; orchestration in repository/use cases |
| New `lib/features/remote_work/presentation/pages/{remote_day,remote_enrollment,remote_schedule,remote_team}_page.dart` | Employee, HR, IT, manager surfaces via domain contracts |
| Modify `lib/main.dart`, `lib/navigation/nav_config.dart`, existing attendance UI entry | Dependency injection and capability-gated routes; no new direct infrastructure UI imports |
| New `scripts/test/remote-work-*.test.js`, `scripts/test/helpers/remote-work-fixtures.js`, `test/features/remote_work/` | Behavior, race, emulator, contract, widget, and query-budget coverage |
| New `specs/020-remote-work-attendance/{qualification,acceptance-evidence,runbook}.md` during execution | Fleet proof, exact commands/results, activation/recovery/rollback evidence |

Before T03 implementation, inventory every writer of leaves, holidays, work schedules, membership, device status, attendance and deduction approvals (including existing HR direct grant/manual paths). Record additional exact files in the task's scoped implementation notes; no known bypass may be left for a later pilot fix.

## 3. Data contracts and indexes

All IDs use validated server-owned identifiers (no `/`), dates are ISO Cairo date keys, instants are server UTC timestamps, and every mutable document has integer `version`. No financial data is stored on remote sessions.

| Collection / ID | Required fields and behavior |
|---|---|
| `attendancePolicyDrafts/{companyId}_{draftId}` | Unified draft containing shared attendance values, remote extension, scope, expected revisions and linked approval/checkout settings |
| `attendancePolicyRevisions/{companyId}_{revisionId}` | Immutable complete shared+remote publication snapshot and source refs |
| `attendancePolicyHeads/{companyId}` | Published/active revision pointers, scheduled revisions, nextActivationAt and activeEffectiveFrom; same transaction updates the company attendance-policy projection and guard epochs when a revision becomes effective |
| `remoteWorkPolicies/{policyId}` | scoped remote override extension of the unified attendance revision; immutable revisions, schemaVersion, effective range and approval snapshot; no independent company-wide policy authority |
| `remoteWorkPolicyHeads/{companyId}_{scopeType}_{scopeId}` | active revision pointers and publication epoch; transactionally updated with policy guards |
| `remoteWorkPolicySchema/{schemaVersion}` | server-owned supported field/capability catalog, validation bounds and schema migration metadata; cannot be extended with arbitrary executable expressions |
| `remoteWorkSchedules/{companyId}_{userId}` | current revision pointer; immutable revision children; weekdays/allowance reference, effective range, status, approvals |
| `remoteWorkWeekExceptions/{companyId}_{userId}_{weekStart}` | versioned `entries` list of stable-ID exceptions: date, optional replacesDate, kind, reason, status and approval snapshot; multiple approved entries can coexist within resolved allowance/carryover limits |
| `remoteWorkAuthorizations/{companyId}_{userId}_{date}` | server materialized dated exceptional authorization; source request ID/version and approval route evidence; no leave balance |
| `remoteWorkEligibilityGuards/{companyId}_{userId}` | monotonic epoch updated with leave/exception/schedule decisions; attendance transactions compare evaluated epoch |
| `remoteWorkCalendarGuards/{companyId}` | monotonic epoch updated with holiday/company-policy changes; enrollment members resolved server-side |
| `remoteWorkCapabilityGrants/{grantId}` | company/actor, capability list, explicit employee scope or approved company-wide scope, effective range, version and grant audit |
| `remoteWorkReportingAssignments/{assignmentId}` | company, manager UID, employee UID, effective range and immutable change history from activation |
| `remoteWorkEnrollments/{companyId}_{userId}` | active enrollment IDs, version, default limit 1, approved second-device evidence |
| `remoteWorkCredentials/{credentialId}` | company/user/enrollment, public key, origin/RP binding, qualification evidence, backup flags, counter metadata, state, approval/activation/review timestamps |
| `remoteWorkChallenges/{challengeId}` | actor/company/action/day/credential/operation/payload hash, expiry, consumed marker; no raw assertion logs |
| `remoteWorkRateLimits/{companyId}_{userId}_{minute}` | transaction-enforced issue/attempt counters; outstanding index/count transaction on enrollment head |
| `remoteWorkSessions/{companyId}_{userId}_{date}` | attendance ID, enrollment/policy/schedule snapshots, lifecycle, goals, slot summary, summary status, hold reference, version |
| Session children `events/{eventId}` | immutable slot/plan/correction evidence; no overwriting original timestamps |
| `remoteWorkOperations/{companyId}_{actorId}_{operationId}` | action, canonical payload hash, original receipt, createdAt; no TTL deletion before approved retry/audit retention |
| `remoteWorkAudit/{eventId}` | actor/capability, company/target/action, before/after safe values, reason, operation/version; server-only immutable |
| `remoteWorkDueEvents/{deterministicEventId}` | company/user/day/slot/kind, dueAt, pending/claimed/resolved, cursor/outbox references |
| `remoteWorkWorkerState/{workerId}` | lease, persisted continuation, epoch for due scan; bounded retry and lease expiry |
| `remoteWorkFinancialHolds/{attendanceId}` | company, attendance version, incident/recovery reason, open/resolved state and HR resolution audit |
| `remoteWorkIncidents/{incidentId}` | company, bounded date interval, explicit employee set or enrolled population, IT declarer, state and deterministic fanout cursor |
| `remoteWorkIncidentCoverage/{incidentId}_{userId}_{date}` | coverage independent of attendance/session existence, resolution and linked financial hold |

Canonical attendance adds optional `companyId`, `attendanceMode`, `remoteSessionId`, `remoteCredentialId`, `remotePolicyVersion`, `remoteScheduleVersion`, `version`, and hold reference on newly governed rows only. Existing rows without mode remain readable; never infer remote evidence for them.

Index additions must correspond to query tests: schedules by company/status/effective date; credentials by company/user/status; sessions by company/date/user and authorized manager scope; due events by state/dueAt/document ID; authorizations by company/user/date. No collection-wide employee history listener. Preflight uses bounded date queries plus head-document reads; query count/read budget is asserted with fixtures.

## 4. Server interfaces and command protocol

Proposed public route prefix `/attendance/remote-work`. Existing `/attendance/web-access/*` remains for nonpilot actors. The remote router composes verified identity using existing Firebase token verification; capability/company lookup is performed inside the feature boundary, not by trusting generic system-key roles.

Shared types in `contracts.js` (runtime validation, not TypeScript requirements):

```text
ActorScope = {uid, companyId, capabilities, membershipVersion}
RemoteCommand = {operationId, kind, expectedVersion?, sessionId?, payload, proof?}
Proof = {challengeId, credentialId, assertion, managedDeviceEvidence}
Receipt = {operationId, status: recorded|already_recorded, attendanceId?, sessionId?, mode?, version, serverTime}
Failure = {code, messageKey, retryable, currentVersion?, recoveryRequired?}
Eligibility = {eligible, reason, date, weekStart, policyVersion, scheduleVersion, employeeEpoch, calendarEpoch}
```

Use exact command kinds `save_policy_draft`, `approve_policy`, `publish_policy`, `revert_policy`, `check_in`, `check_out`, `save_plan`, `submit_update`, `save_summary`, `correct_day`, `save_schedule`, `approve_enrollment`, `activate_enrollment`, `revoke_enrollment`, `declare_incident`, and `resolve_hold`. All mutate through stable operation IDs and version checks. Employee session writes require a fresh proof; HR/IT mutations require normal authenticated capability plus audit/version, not possession of the employee credential.

| Signature / file | Contract |
|---|---|
| `resolveActorScope({db, identity, requestedCompanyId}) -> Promise<ActorScope>` / authorization.js | verified membership or one explicit configured legacy company; fail closed on mismatch |
| `evaluateRemoteEligibility({context, now}) -> Eligibility` / eligibility.js | pure evaluated context; aliases/week/leave precedence; no client clock |
| `resolveRemotePolicy({db, actor, employeeId, shiftDate}) -> Promise<ResolvedRemotePolicy>` / policy-resolution.js | company → department → team → employee → dated exception; full payload, source revision IDs and hash |
| `validateRemotePolicy({draft, capabilities}) -> ValidationResult` / policy-schema.js | field errors, supported mechanisms, ordered windows/offsets and safe bounds |
| `previewRemotePolicy({db, actor, draftId, employeeId, shiftDate}) -> Promise<PolicyPreview>` / policy-resolution.js | authoritative dry run, inherited values, scope/effect diff; no runtime mutation |
| `executeRemotePolicyCommand({db, admin, actor, command, now}) -> Promise<Receipt>` / policy-publication.js | versioned draft/approval/publication/revert and guard epoch updates; current governing route cannot self-bypass |
| `saveRemoteSchedule({db, admin, actor, command, now}) -> Promise<Receipt>` / schedules.js | versioned schedule/exception, guard epoch and audit/receipt transaction |
| `issueRemoteChallenge({db, admin, actor, command, now}) -> Promise<{challengeId, options, expiresAt}>` / challenges.js | bounded action/payload-bound challenge and rate-limit transaction |
| `verifyRemoteProof({actor, command, challenge, credential, qualification, now}) -> VerifiedProof` / device-credentials.js | pure library-backed verification result; transaction consumes it only after rechecking versions |
| `executeRemoteAttendance({db, admin, actor, command, now}) -> Promise<Receipt>` / attendance-commands.js | receipt lookup first; new action validation and atomic attendance/session/challenge commit |
| `enforceDayMode({transaction, actor, date, requestedMode, evidence}) -> Promise<ModeDecision>` / day-mode-guard.js | used inside every pilot attendance writer; proof kind must establish requested mode |
| `executeRemoteSessionCommand({db, admin, actor, command, now}) -> Promise<Receipt>` / session-commands.js | slot/plan/summary versioned evidence plus receipt |
| `correctRemoteDay({db, admin, actor, command, now}) -> Promise<Receipt>` / recovery.js | policy-authorized correction capability and append audit, canonical row correction and hold; no payroll reopen |
| `declareRemoteIncident({db, admin, actor, command, now}) -> Promise<Receipt>` / financial-holds.js | scoped IT declaration, bounded date/population registry and fanout seed |
| `resolveRemoteFinancialHold({db, admin, actor, command, now}) -> Promise<Receipt>` / financial-holds.js | scoped HR resolution; no automatic approval/reversal of financial consequences |
| `listRemoteDays({db, actor, filters, cursor, limit}) -> Promise<Page<RemoteDay>>` / queries.js | scope validated before bounded query/serialization |
| `queueRemoteWorkReminders({db, admin, now, pageSize=100, maxDocuments=1000}) -> Promise<ScanResult>` / reminders.js | durable cursor/lease; deterministic event/outbox receipts |

Endpoints: `GET /policy-schema`, `GET /policies?...`, `GET /policies/{id}/history`, `POST /policies/preview`, `GET /me?date=...`, `GET /days?...`, `GET /schedules?...`, `GET /employees?...`, `GET /incidents?...`, `GET /operations/{operationId}`, `POST /challenges`, `POST /commands`, `POST /enrollments/options`, `POST /enrollments/verify`, `GET /enrollments?...`. All GET lists obey company/capability scope and pagination. Enrollment registration uses separately action-bound challenges; `/commands` is exhaustive allowlist dispatch, never arbitrary method lookup. Enrollment approval and activation are distinct capability checks.

All errors use safe codes including `not_eligible`, `wrong_company`, `mode_locked`, `credential_unqualified`, `credential_revoked`, `challenge_expired`, `operation_conflict`, `version_conflict`, `rate_limited`, `checkout_not_required`, `recovery_required`, and `temporarily_unavailable`. Already-committed retries return the saved receipt after actor/company authorization, before fresh eligibility/proof validation. A conflict leaves current data unchanged.

## 5. Eligibility concurrency and legacy integration

Compute eligibility with employee/calendar epochs read before the bounded leave/holiday queries; the final transaction compares epochs and re-reads account, membership, schedule, enrollment, policy, and canonical row. If a guard changed, reevaluate outside the transaction and retry within a bounded three-attempt application budget, then return `version_conflict` without writes. This avoids a stale leave query passing after an approval.

For pilot scope, route leave approval/rejection/direct grant, casual submit/override, and company holiday writes through authenticated server commands that update the relevant guard in the same transaction. Legacy direct Firestore mutation is denied for governed decision documents. User work-schedule/employment fields are read in the attendance transaction; schedule updates cannot bypass those checks. Block activation until every affected writer is inventoried and characterized. Source records whose final approval predates activation are read through the prospective alias adapter; no history is rewritten.

Rules changes remain local/emulator-only until a separate owner-approved rules release. Fix leave payload compatibility narrowly: allow and type-check `isQuotaExempt`/`subtypeConfigSnapshot` for nonpilot legacy submission, but derive authoritative quota/financial behavior from trusted server/template rules for pilot operations. Do not introduce `|| true` bypasses or broad collection permissions. Existing broad rules are not a model for new remote collections.

Session snapshots retain approval/shift/credential evidence for the day. Normal schedule or pause controls cannot strand checkout. Security changes create recovery instead. Real leave approved after a day starts is an HR conflict requiring correction rather than silent deletion of check-in.

Server authority comes from explicit remote capability grants (no automatic HR/job-title mapping) and effective-dated reporting assignments, bootstrapped only through owner-reviewed security administration. Suggested capability keys: `manage_attendance_policy`, `manage_policy_drafts`, `approve_policy`, `publish_policy`, `manage_schedules`, `approve_enrollment`, `activate_enrollment`, `revoke_enrollment`, `review_team`, `correct_attendance`, `incident_declare`, `resolve_financial_hold`, `view_company`, `security_admin`, `break_glass`. Company/user membership and these grants are transaction-read or version-checked at mutation commit.

An IT-declared incident covers a maximum seven-day Cairo interval and a specified population, including people without sessions/attempts. The recovery worker fans coverage out in bounded pages; financial approvals check the incident registry while coverage is incomplete. HR resolves each financial hold with evidence. Late declarations produce investigation cases for already approved amounts, never silent payroll reversal. Checkout after the resolved snapshotted cutoff instant requires HR recovery; passing midnight alone does not invalidate a configured overnight shift. Daily processing waits for that cutoff before proposing missing checkout. Each started shift creates a deterministic `attendance_finalize` due event; Hostinger invokes `finalizeRemoteShift({db,admin,attendanceId,now}) -> Promise<Receipt>` after cutoff against the original accounting row even after the daily job advances its target date. Daily and due-worker paths use one idempotent consequence helper. All governed office/automatic/manual paths use the same server-resolved shift-start date before selecting the canonical attendance ID, including after midnight. `checkoutRequired=false` creates no missing-checkout consequence.

## 6. Client contracts and synchronization

`RemoteWorkRepository` exposes:

```text
Future<RemoteDay> loadDay(String date)
Future<RemotePage> listDays(RemoteFilter filter, String? cursor)
Future<RemoteReceipt> submit(RemoteAction action)
Future<void> saveDraft(RemoteDraft draft)
Stream<RemoteDraftState> watchDraft(String sessionId)
Future<RemoteReceipt?> lookupOperation(String operationId)
```

`RemoteAction` owns stable operation ID, kind, payload and expectedVersion, not Firebase objects. The data implementation coordinates local durable outbox, challenge acquisition, browser verification and HTTP. Persist drafts/operation IDs before network submission; exclude biometric assertions/private keys from storage. A timed action is not silently resubmitted offline. After uncertain response, lookup receipt; if absent, obtain new proof for the same unchanged operation payload. Local status uses `draft`, `pending`, `synced`, `conflict`, `recoveryRequired`.

Separate presentation-safe contracts prevent enrollment and administration from falling through to direct HTTP/Firestore calls:

```text
RemoteEnrollmentRepository:
  Future<RemoteEnrollment> registerComputer(String displayName, String operationId)
  Future<RemoteEnrollmentPage> listEnrollments(RemoteFilter filter, String? cursor)
RemoteAdministrationRepository:
  Future<RemoteSchedulePage> listSchedules(RemoteFilter filter, String? cursor)
  Future<RemoteEmployeePage> listEligibleEmployees(RemoteFilter filter, String? cursor)
  Future<RemoteIncidentPage> listIncidents(RemoteFilter filter, String? cursor)
  Future<RemoteReceipt> submit(RemoteAdminAction action)
```

The enrollment data adapter handles options, browser registration and verification behind `registerComputer`, returning a pending approval enrollment. Administrative actions carry stable operation IDs, command kind, target, payload and expectedVersion. Page types contain domain entities and a continuation cursor. `RemoteAdminAction` covers schedule/exception decisions, enrollment approve/activate/revoke, correction, incident declaration and hold resolution; the server validates each capability independently. All these methods and identities are covered by T10/T11 contract tests. Keep mutable business hashes independent of ephemeral challenge/assertion fields so a new proof for an uncommitted retry does not change the operation's business identity.

Use existing Drift infrastructure through a feature-owned adapter. Do not reuse another feature's private tables. Cached day/session data and outbox keys include authenticated user and company. Clear subscriptions and visible state at sign-out/context switch. Presentation receives domain-safe failures and reads no Firestore or concrete API classes. Composition happens in `main.dart`/feature factory outside presentation.

## 7. Dynamic policy engine and dashboard

Implement FR-12 in T14 before downstream attendance behavior. `ResolvedRemotePolicy` contains `schemaVersion`, `sourceRevisionIds`, `hash`, scope and all business sections: eligibility, allowance, shift/channels, device profile, approval routes, work evidence, notifications, consequence rules, retention and rollout. Persist the entire resolved value plus linked shared-attendance/approval revisions in session snapshots; current policy lookup cannot change a running session's obligations.

`RemotePolicyRepository` is presentation-safe and exposes `loadSchema()`, `listPolicies(filter,cursor)`, `loadHistory(policyId)`, `saveDraft(draft,expectedVersion,operationId)`, `preview(draftId,employeeId,shiftDate)`, `approve(policyId,expectedVersion,operationId)`, `publish(policyId,effectiveAt,expectedVersion,operationId)` and `revert(policyId,revisionId,effectiveAt,expectedVersion,operationId)`. Define typed domain results `PolicySchema`, `RemotePolicyPage`, `PolicyRevision`, `PolicyPreview`, `PolicyDraft` and `ResolvedRemotePolicy`. The data adapter owns authenticated HTTP; a focused policy editor Cubit owns draft UI state and a separate publication Cubit owns review/history state.

Extend the existing `AttendancePolicySettingsScreen` at `/hr/attendance-policy` (**سياسة الدوام**) with `RemotePolicySettingsSection`, a schema-driven embedded section matching FR-12. Keep the current navigation entry and dashboard card; do not add a separate remote-policy menu or route. Show inherited versus overridden values, effective date, validation errors, assurance description, required approvers and affected employee/date preview. Nested lists support stable-ID approval steps/checkpoints/custom fields rather than fixed enums. Reuse existing request-template domain definitions where semantics match, behind domain interfaces; do not couple presentation to the old repository or assume its historical routing bugs are resolved.

The root publication aggregate is shared attendance plus its remote extension. Keep `companies/{companyId}.attendancePolicy` readable by existing `AttendancePolicyService` and server workers as a validated projection of published revisions. A shared-hours/restriction edit and its remote overrides commit in one versioned publication transaction with linked approval/checkout values and relevant epochs; an old direct settings save cannot overwrite governed values or drop extension fields. Preserve unrelated security/chat/advance form data and isolate its existing save behavior rather than mixing it into remote publication.

Policy resolution order: shared attendance base → company remote extension → department → team → employee → dated exception; unique active revision per scope; explicit inherit/disable/empty; arrays replace rather than append. Publication atomically checks draft/version, approvals under the current governing route, scope capabilities, non-overlap and policy epochs. Revert creates a new effective revision. Application rejects missing, ambiguous or unsupported published settings with explicit configuration errors; do not silently fall back to hardcoded defaults. Existing saved attendance settings seed the initial unified draft without changing production data during planning; starter remote values are saved through the same draft/publish flow, not a hidden runtime path.

Approval conditions use supported typed operators/thresholds and resolvers, not eval/scripts. Remote consequence rules can produce none, warning, escalation or a deduplicated pending financial proposal; only an authorized reviewer may approve financial effects. Shared attendance rates/settings are referenced by explicit policy revision or deliberately overridden and shown as such. Retention settings affect only authorized future retention execution, not historical payroll mutation.

Newly effective policies invalidate cached eligibility/unstarted-day due events; active sessions retain prior snapshots and event IDs. Department/team transfers follow the same rule. Zero checkpoints means zero related reminders/violations. Include tests for allowance1→2, zero/two/five checkpoints, different hours/timezones and overnight cutoff, probation on/off, dynamic approval/device limits, inheritance, competing publishers, future dates and revert, all without app rebuild.

### Company policy activation increment (2026-10-26)

`policy-activation.js` provides `activateDuePolicyRevisions({db, companyId, now})` and `queueDuePolicyActivations({db, now, pageSize=10})`. Publication records the next due instant; the existing Hostinger background lease and authenticated manual dispatch/reminder paths invoke the bounded worker before automatic attendance/reminders. No additional timer or scheduled workflow is introduced. The worker projects the latest effective snapshot by time, not by revision number; a delayed old activation cannot override a later immediate revision. Immutable revision records remain unchanged. Failed activation receives operational retry backoff without changing its actual effective date, and a changed head is not overwritten by retry bookkeeping.

Draft approval is bound to normalized aggregate plus exact effective instant via `reviewHash`. Changed content/time must be saved and reviewed again; the publisher cannot substitute a new effective time. A published/scheduled draft is closed, so the editor starts a fresh draft and keeps its identity synchronized with publication controls. The dashboard preserves loaded effective time, offers date/time selection and blocks approval/publication of unsaved visible edits. This increment does not complete dynamic governing approval routes, employee/date scope resolution or the remaining schedule/enrollment/attendance work.

## 8. Verification and release evidence

Tasks contain exact red/green commands. Use a transaction-capable emulator for races/rules and deterministic injected clocks for date/window behavior; source-string assertions alone are insufficient. Behavioral tests must prove records, balances, notifications, audit and operation counts.

Final execution checks:

```bash
flutter analyze
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test
cd scripts
npm test
```

Also run the documented local emulator command established by T02/T07, qualified browser/device journeys and Arabic RTL/desktop checks. Record exact versions, fixture/emulator environment, results, and unresolved limitations in `acceptance-evidence.md`. No tests against production writes. Do not mark a checklist complete based on an earlier feature's green suite.

Release gates: approved specification/defaults; successful computer qualification; dynamic policy preview/publication/snapshot coverage; full writer/guard coverage; emulator isolation; no historical mutation; scheduler ownership verified; retention approved; current checkout policy approved; feature off by default; rollback exercised with an open session. Pilot activation and any production rule/index change each require concrete owner review and authorization outside this task.
