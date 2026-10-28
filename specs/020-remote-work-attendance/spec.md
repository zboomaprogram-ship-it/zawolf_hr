# Remote Work Attendance — Feature Specification

**Feature:** `020-remote-work-attendance`  
**Date:** 2026-10-26  
**Status:** Owner approved local implementation on 2026-10-26; rollout remains separately gated  
**Requested deliverables:** specification, implementation plan, tasks and implementation using Superpowers. The owner subsequently approved implementation and requested completion of feature 020. Production rules, activation, migrations and deployment require separate approval. See [execution status](execution-status.md).

## 1. Intent and sources

Provide dashboard-configurable remote-work policies: administrators control eligibility, allowed remote days, schedules, channels, device requirements, approval chains, daily plans, any number of progress updates, summaries, reminders and review consequences. The original one-day/three-update policy is an editable starter preset, not hardcoded product behavior. Keep existing attendance and payroll authoritative. A remote day is work, not leave.

Source policy: `/Users/seg/.gemini/antigravity-ide/brain/ff18dc8c-bbf8-4283-9369-7406723416bc/remote_work_attendance_policy_plan.md` (sections 1–14). Its adjacent `remote_work_feasibility.md` is background, not evidence of implementation. This specification is the repository-owned translation of those sources and the code review in this conversation.

Read together with [attendance behavior](../attendance/attendance_absence_spec.md), [payroll behavior](../payroll/payroll_cycle_spec.md), [existing web access](../web_attendance_access/spec.md), and the repository constitution. Payroll cycles remain day 26 through day 25; execution date remains the accounting date. Existing finalized cycles are never reopened by this feature.

## 2. Current behavior and approaches

Verified by reading the current checkout on 2026-10-26:

- `scripts/attendance-gateway.js` provides deterministic attendance IDs, transactional phone binding, and retry receipts. It still accepts bounded client event times and client lateness/deduction inputs; server-authoritative remote time is new work.
- `scripts/web-attendance-access.js` provides permanent/date-range HR grants. A grant is not approved-computer evidence or a weekly schedule.
- `lib/services/attendance_service.dart` blocks check-in for approved leaves before checking a `wfh` exception. `LeaveTypePolicy` uses `remote`; Arabic subtype names can bypass exact-string routing checks.
- `LeaveService` can convert remote requests to unpaid leave during probation. Recent submission fields `isQuotaExempt` and `subtypeConfigSnapshot` are absent from the checked-in leave-create allowlist.
- Nightly processing, automatic attendance, reminders, leave reconciliation, manager-leave bypass, and monthly leave counts require remote-aware classification.
- The repository declares Hostinger the live reminder scheduler and GitHub reminders manual recovery. Live ownership still requires read-only verification before rollout.

Approaches considered:

1. Extend leave records and general web grants: smallest initial edit, but preserves incorrect absence, probation, and device semantics. Rejected.
2. Add a remote-work vertical slice beside existing attendance, with server authorization and a shared canonical attendance record: recommended design used by these drafts. Preserves existing readers and isolates rollout.
3. Replace the entire attendance system: unnecessarily broad and incompatible with incremental delivery. Rejected.

The user clarified that all remote-work business policies must be configurable inside the existing **سياسة الدوام** dashboard screen at `/hr/attendance-policy`, including hours, timings and restrictions. That requirement supersedes fixed administrative choices below: values shown are editable starter defaults. Server-enforced integrity, isolation, cryptographic validity and historical payroll protection remain implementation guarantees, not configurable bypasses.

## 3. Editable starter preset (dashboard-managed)

| Topic | Proposed decision |
|---|---|
| Weekly allowance | Default one remote date in a Saturday–Friday week. Dashboard controls week start, allowance, allowed weekdays, replacement/additional exceptions and optional carryover (default off). |
| Approval | Default HR approval; dashboard edits ordered conditional manager/HR/IT/CEO/specific-user steps separately for schedules, exceptions, devices and corrections. Existing requests keep their approval snapshot. |
| Probation | Probation eligibility and minimum tenure are dashboard switches/thresholds; remote work never becomes unpaid leave. |
| Pilot security | Owner-selected profile: HR-approved registration plus passkey on personal computers for remote days; office computers are company-owned. Synced passkeys are permitted and do not establish physical-computer identity. Dashboard choices must describe their actual assurance and pass qualification before publication. A general web grant cannot replace passkey verification. |
| Daily schedule | Default 09:00–17:00, check-in opens 08:45, plan due 09:30, updates 11:00/13:00/15:00 with 15-minute grace, closing reminder 16:45. |
| Shift support | Dashboard edits start/end, timezone, cutoff and next-day offsets; overnight shifts use the shift-start business date and server-resolved instants. |
| Missing update | Default review signal only. Dashboard can configure no action, reminder, warning, escalation or proposed financial review. Financial proposals always require authorized review; missing work evidence never blocks recording checkout. |
| Sensitive data retention | No automatic deletion until an owner-approved retention period exists. Production pilot requires that decision and an accountable data owner. |
| Checkout cutoff | Dashboard selects the cutoff and day offset. Server checkout must fall within the snapshotted shift window; after cutoff use audited recovery, never client backdating. |
| Authority records | Explicit company-scoped remote capability grants; existing HR/IT role labels alone do not grant remote decision powers. |

## 4. Scope and non-goals

In scope: dashboard policy builder, draft/preview/approval/publication/version history and overrides, effective-dated schedules, weekly exceptions, approved-computer enrollment/revocation, remote commands, atomic mode locking, compatibility adapters, work sessions, scoped HR/IT/manager surfaces, notifications, review/correction, pilot monitoring, and rollback.

Not in scope: replacing payroll, automatic reopening of finalized payroll, historical backfills, continuous activity tracking, cameras/screenshots/keylogging, unreviewed automatic task scoring for salary, or a general multi-company migration. Existing unrelated attendance paths retain their behavior behind the feature boundary.

## 5. Functional requirements

### FR-01 — Company and actor authority

The server verifies Firebase identity, active user, trusted company membership, employee relationship, and operation capability. Never trust a body `companyId`, role, manager ID, platform string, employee ID, or user-agent as authorization. Each new entity and operation is company-scoped. Until multi-company identity is fully available, a resolver must map the existing deployment to one configured company and reject conflicting/missing membership; never infer arbitrary membership from a client.

Canonical attendance stays `attendance/{userId}_{YYYY-MM-DD}`. Because this is globally keyed, an actor may have only one attendance-owning company on a date. A conflicting company is rejected, not overwritten. Broad existing leave-read permissions must not be copied into remote-work APIs.

### FR-02 — Schedules and weekly exceptions

An authorized user creates an effective-dated schedule with policy-selected ISO weekdays (1=Monday…7=Sunday), shift policy, company, employee, version, approver, and reason. Approval follows the saved policy route, not a hardcoded HR-only branch. No overlapping active schedule revisions for an employee. Changes use an explicit effective instant and policy-local schedule date; canonical accounting date remains Cairo shift-start date. Exception submission windows, replacement/additional-date behavior and weekly allowance come from the resolved policy; validate them server-side rather than enforcing a fixed one-date rule.

Approved real leave, company holiday, employee weekly rest, inactive employment, and suspension override remote eligibility. Eligibility shows the effective reason to the employee. Authorized revisions use expected versions and append audit events. Concurrent edits return conflict, not last-write-wins. An already started day retains its attendance evidence and policy snapshot.

### FR-03 — Legacy compatibility and leave separation

Canonicalize `remote`, `wfh`, `عمل عن بعد`, and `يوم عمل عن بعد` at all relevant boundaries. Existing labels remain readable; new remote requests use a remote-specific collection and never mutate leave balance. Pending legacy remote requests finish their saved manager/HR/CEO route and may become dated authorizations for eligible future days.

For flagged employees on or after their activation date, approved legacy remote leaves are read as dated remote authorizations, not excused absences. Schedules and legacy authorizations share the weekly allowance; excess/conflicting authorizations require HR resolution before activation. Real leave still wins. Remove remote records from absence exemption, reminder suppression, manager-on-leave bypass, automatic on-leave creation, balance deduction, and leave counts for these prospective days. Automatic office geofence check-in may still win the day's mode, but must not create a remote session. Once remote mode is locked, auto signals cannot change it.

Never rewrite historical leaves, attendance, payroll, or stored approval trails. A remote request previously converted to unpaid (`originalLeaveType` remote alias) is a flagged HR review case, not an automatic refund or reinterpretation. Historical attendance already marked on-leave requires an audited correction before check-in; no blind overwrite.

### FR-04 — Computer verification

Computer credentials are independent of `attendanceDevices` and `registeredAttendanceDeviceId`. The starter preset allows one active enrolled credential for the selected passkey profile; additional-device limits, approval/activation routes, review interval, replacement rules and evidence profile are dashboard settings. The server validates the selected supported profile and required approval snapshot before activation. The starter replacement flow revokes the old enrollment first; dashboard policy may define a reviewed replacement overlap within the active-device limit. Every transition has an audited recovery path. Requalification defaults to six calendar months or company/employment change; the interval and additional triggers are configurable.

Use WebAuthn verification on the server: challenge, origin, RP ID, user verification, credential ownership, signature, expiry, and single-use consumption. The owner-selected `hr_approved_passkey` profile permits backup-eligible/synced credentials: it verifies the HR-approved credential and user verification, not a particular physical computer. A separate physical-computer-bound profile must reject incompatible backup/sync behavior and demonstrate additional device evidence. Every supported profile must be explicitly described and qualified; the UI cannot claim physical-computer binding for a profile that lacks that evidence. A portable authenticator or user-agent is not proof of the physical laptop. Before a verification profile is available for publication, a qualification spike must demonstrate its advertised assurances on the target fleet; the approved-computer profile must prove binding to that computer. Unsupported devices remain ineligible; no fallback to browser installation IDs.

Starter challenge lifetime: 120 seconds (dashboard-editable within the supported security bounds); bind it to company, actor, operation ID, action, credential, target day, and payload hash. Starter attempt limits: five outstanding challenges per actor, ten issues and ten verification attempts per actor per minute (advanced dashboard settings within server-advertised bounds); exhausted budgets return `rate_limited`. Store public keys and necessary metadata only, never private keys, assertions, or tokens in logs. Credential counter handling must follow the selected authenticator's verified semantics; do not assume every authenticator has a strictly increasing counter.

### FR-05 — Server time, commands, and atomic day lock

Remote writes require connectivity and fresh verification. Server receipt time and the published policy timezone/shift determine local shift date, timing, lateness, shift windows and any proposed deduction. Store `localShiftDate` separately; canonical attendance/accounting date is the Africa/Cairo date of the shift-start instant, preserving current payroll boundaries. The starter preset uses Africa/Cairo so these dates coincide. Every governed remote, office, manual and automatic path resolves the same shift-start accounting date across midnight, so another path cannot create a second day lock. Overnight checkouts target that original attendance row. Materialize a deterministic `attendance_finalize` due event at the snapshotted cutoff; the worker revisits the original row after cutoff even when the nightly target-date job has moved on. Finalization is idempotent and shares the existing attendance consequence calculation; it never silently loses a deferred day. Client time is diagnostic only. New remote commands accept no authoritative coordinates, financial values, attendance timestamp, or platform claim. Body date can identify an existing session but cannot backdate check-in. A proof is bound to the server-resolved shift, including its start-date business key; midnight cannot be used to select an arbitrary earlier date.

Modes are exactly `remote_web` and `on_site_mobile`. First successful check-in atomically locks mode on canonical attendance. Remote check-in also creates one `remoteWorkSessions/{companyId}_{userId}_{date}` with the policy/schedule/credential revisions and operation receipt. Office check-in uses existing validated mobile device/geofence evidence and no remote session. A remote credential cannot be substituted with the existing mobile device string.

For enabled actors, all writers—including old clients, legacy general web grants, direct Firestore writes, automatic signals, and HR manual paths—must respect the new guard. New remote commands must be verified cryptographically; `clientPlatform: 'mobile'` alone is never evidence of office presence. Verify both single-location and multi-location server geofence paths. Legacy web-grant check-in is denied for enabled actors; other actors retain existing behavior. HR correction remains an explicit audited exception.

Remote transaction re-reads authoritative versions and mutable eligibility evidence (including an absence/holiday/leave authorization guard) before writing. Approval/configuration writers update that guard so concurrent eligibility changes cannot race check-in. Signature verification may occur before the transaction, but challenge consumption, version validation, attendance, session, receipt, and audit commit together. No external side effects inside transaction callbacks.

Each write has a stable actor/company-scoped operation ID and canonical payload hash. A retry of a committed operation returns its original receipt without another attendance event or challenge consumption, even after schedule/device revocation; it grants no new action. Reusing the ID with another payload is `operation_conflict`. Invalid/uncommitted challenges cannot be replayed. A genuine duplicate check-in with another operation returns the existing mode and attendance receipt without changing either. Deny cross-company/actor receipt lookup.

### FR-06 — Sessions, plans, and updates

Remote sessions reference canonical attendance; they are never a second attendance or payroll source. The first successful check-in snapshots the validated company shift windows for the day. Dashboard controls whether a plan is required, minimum/maximum goal counts (starter preset 3–5), ad hoc goals, required fields and closing-summary requirements. Goals reference authorized assigned tasks or allowed ad hoc descriptions. Dashboard configures text requirements/limits within storage bounds of 1000 characters per goal/update and 4000 per summary; task IDs must belong to the actor's authorized scope. No rich HTML.

Each enabled update has a stable policy-defined slot ID (starter preset `update_1`, `update_2`, `update_3`; dashboard supports zero or more ordered slots), due time, grace end, state, server submission time, task references, and explanation. Submissions before the due time do not satisfy the slot; submissions after the grace window are retained as late evidence. A late check-in creates prior slots as `missed_needs_review`, not falsely completed. Approved meeting/permission/field-assignment intervals overlapping a slot's due-to-grace interval mark it `excused`, with source ID/version. Default task/slot consequences are nonfinancial; only an explicitly published rule can propose a pending financial review, with source event and policy snapshot. Later approvals can reconcile the review state prospectively without altering original timestamps.

Plan/summary drafts persist locally before synchronization; users see draft/pending/conflict states. A draft is never attendance or a verified update. On reconnect, recover the operation receipt first; uncommitted timed actions require a fresh challenge. Versioned updates reject concurrent stale edits. No background/offline replay can fabricate an earlier checkpoint.

### FR-07 — Checkout and recovery

Normal remote checkout uses the snapshotted evidence profile/enrollment and locked mode, server time, and the resolved checkout policy. It may include a summary but cannot be blocked by missing goals, updates, or summary; missing content becomes review work. Accepted early-leave permissions use existing execution-date policy and pending-review semantics. The dashboard may configure checkout as required or not required using a remote override or an explicit link to the existing attendance policy. A disabled checkout policy yields `checkout_not_required`; the session then follows its configured close/review behavior without inventing checkOutTime or missing-checkout deductions.

Schedule edits, expired review dates, or disabling new check-ins do not invalidate an existing session's normal checkout. Security revocation, inactive account, wrong mode, or unavailable credential blocks ordinary commands and presents HR recovery; never reactivate a revoked credential to finish the day. HR records a correction with evidence, original/new values, reason, actor, server time, expected attendance version, and financial review hold. No silent mode switch or retrospective automatic deduction.

### FR-08 — Payroll, incidents, and corrections

Remote work alone does not consume annual/casual leave or reduce salary. Attendance lateness/missing attendance/checkout may propose existing `pending_hr` consequences only, using server-calculated policy. Existing payroll includes only approved positive deductions; preserve that behavior. Preserve execution date, payroll boundary, and finalized-cycle rules.

Daily jobs read canonical attendance and must not mark an employee absent when remote attendance exists. Service incidents and credential recovery add an explicit financial review hold before any HR approval; enforce the hold in server and direct-write rules, not only UI. HR must resolve/document the hold before a financial decision. A configured checkpoint/task rule may create only a pending financial proposal; it cannot approve a deduction. Deduplicate proposals across existing attendance and permission consequences and apply the policy daily cap before HR review. No automatic processing reopens a finalized cycle. Corrections use immutable audit events and version checks, retaining original evidence.

Proposed incident authority: a scoped IT `incident_declare` capability may open an incident; scoped HR `resolve_financial_hold` resolves its financial cases, without IT approving payroll. Incident declarations specify company, server timestamps, affected Cairo date range (at most seven days per declaration), and an explicit employee set or all remotely enrolled employees in that company. Coverage includes scheduled/authorized employees with no session and no successful attempt. Until fanout completes, financial approvals check the incident registry directly; absence of a hold document is not proof of no incident. Coverage/hold IDs are deterministic by incident/user/date. Incident population limits and declaration windows are dashboard-configurable within validated service bounds. A late incident declaration flags already approved consequences for HR investigation but does not silently reverse amounts or reopen closed cycles.

### FR-09 — Visibility and operations

Employee sees own schedule, enrollment, eligibility, session, and recovery status. Manager sees only currently assigned reports in company scope; historical viewing follows authorized effective-dated relationships. HR sees its administrative scope. The default IT capability profile sees enrollment/security support metadata; additional visibility or decision capabilities require an explicit scoped dashboard grant. Role labels alone grant no task narratives or salary decisions. Super Admin visibility does not imply ordinary HR/IT decision capability; an explicit, audited break-glass capability is required for exceptional action.

Server mutations only. New collection client writes are denied; API reads return minimized data. Lists are company-scoped, paginated (default 50, maximum 100), and filtered before serialization. Access or company switch clears local session caches, drafts visible to the next identity, and subscription state; persisted drafts remain partitioned by identity/company.

Proposed authority source: new `remoteWorkCapabilityGrants` records bind company, actor, capabilities, employee scope, effective range and version. Bootstrap grants require owner-reviewed security administration, never an automatic mapping from free-text job titles. New `remoteWorkReportingAssignments` records snapshot server-resolved current manager UID relationships at activation and append effective-dated changes. Before activation, no historical relationship is invented. Managers need a current active assignment and an assignment covering the historical day to view that day's narrative; HR can authorize a documented handover when reassignment requires past access. Current user/account/membership state is rechecked on every operation.

### FR-10 — Notifications and daily operations

Hostinger owns the remote reminder scan; existing GitHub reminder workflow stays manual recovery. Confirm deployed ownership before activation. Scan at most 100 due documents per page with stable pagination, advancing until the due backlog is exhausted with a bounded per-run budget of 1000 documents. Persist continuation and use a short lease so the next tick resumes; no unbounded history scans or one full-history query per employee.

Materialize deterministic reminder IDs by company, employee, date, slot, and event kind. Enqueue notification/outbox and reminder receipt atomically. The starter notification route reminds the employee before escalation; published routes define their own ordered stages; escalate to policy-resolved authorized recipients only after the configured grace/escalation delay (starter preset: current manager 30 minutes after grace for persistent missing updates), financial/administrative decision alerts go only to a policy-resolved authorized reviewer. Revalidate completion/exception/recipient scope before delivery. Multiple schedulers or retries create one logical event. If downtime missed several reminders, send one current actionable reminder, not every obsolete event.

Manager states: scheduled, not checked in, working, approved meeting/permission, needs follow-up, finished, missing checkout/recovery, and office alternative. Preserve distinctions between slot status, session lifecycle, and attendance financial review. Default display precedence (editable among validated noncontradictory presentation states): recovery > missing checkout after configured close window > finished > office alternative > active exception > needs follow-up > working > scheduled/not checked in.

### FR-11 — Rollout, rollback, and audit

Server feature flag `remote_work_attendance_v1` defaults off and is scoped to company and actor with an activation date. Historical dates remain unchanged. Separate control `remote_work_new_checkins_enabled` stops new remote sessions while retaining existing sessions, receipts, reads, and authorized checkout. Security revocation still requires HR recovery. Keep authorization/device safeguards deployed during rollback; never route enabled session actors back through permissive legacy web writes.

Qualification and local/emulator acceptance precede the dashboard-defined pilot (starter preset: four weeks, 10–20 employees), followed by owner evaluation. The starter success target is 98% first-attempt check-in success, alongside no duplicate canonical rows, no mode switches, no cross-scope exposure, and no unreviewed financial impact. Record denominator and error categories; an HTTP success carrying rejection is not a successful check-in. No production flag, rule deployment, retention job, data repair, or store release is authorized by these documents.

### FR-12 — Dashboard policy management (primary requirement)

All administrative values in this document are starter preset data. No app release or code edit is required to change a supported business policy. The existing **سياسة الدوام** screen at `/hr/attendance-policy` provides shared attendance controls and an integrated **العمل عن بُعد** section with subsections for Eligibility & Days, Hours & Channels, Devices, Approvals, Daily Work, Notifications, Review & Financial Proposals, Privacy & Retention, and Rollout. Fields are driven by a versioned server schema/capability catalog; no hidden hardcoded one-day/three-checkpoint limits or HR-only routing.

| Policy group | Dashboard-editable settings |
|---|---|
| Eligibility and scope | Enabled status, company/department/team/employee targets, employment/probation/tenure conditions, dated exclusions and exceptions |
| Allowance | Week start, days per week, eligible weekdays, fixed/flexible selection, replacement/additional exceptions, carryover enablement and cap |
| Hours and channels | Link to existing work schedule or remote override, timezone, start/end and next-day offsets, check-in window, lateness grace, checkout required/cutoff, supported remote/office channels and office alternative |
| Devices | Supported verification profile, enrollment limit, extra-device exceptions, review interval, replacement/revocation and approval rules; advanced challenge TTL/rate settings within advertised safe ranges |
| Approvals and authority | Ordered, conditional routes for schedules, exceptions, policy publication, enrollment, activation and corrections; supported manager/HR/IT/CEO/capability/specific-user resolvers; scoped decision and visibility grants |
| Plans and updates | Enable/require plan or summary, goal counts, ad hoc tasks, required custom fields, zero or more stable-ID checkpoint definitions, due times/shift offsets, grace and approved-event exemption rules |
| Notifications | Enable each event, reminder lead times, repetition/caps, quiet hours, channels, recipient resolver, escalation delay/stages and catch-up behavior |
| Review and finance | No-action/warning/review/proposal rules by trigger, late/missing-attendance thresholds and amounts/day fractions, daily cap and precedence, links to shared attendance rules; every financial consequence remains pending authorized review |
| Privacy and rollout | Retention periods by data class, authorized review visibility, pilot audience/dates, pause-new-sessions, release criteria and activation notice |

There is one settings entry and one policy publication flow: **سياسة الدوام**. Shared hours, check-in/out windows, lateness grace, verification restrictions, reminders and thresholds are edited once and inherited by remote work. The integrated remote section may explicitly override a shared value for remote days, displaying **موروث من سياسة الدوام** or **تخصيص للعمل عن بُعد** and providing reset-to-inherit. Shared and remote values are saved/previewed/published together as one versioned attendance-policy aggregate, not competing editors or a separate remote-policy menu. Existing attendance settings live at `companies/{companyId}.attendancePolicy`; preserve their reader contract using a server-published projection backed by immutable revisions. Existing approval/checkout stores are version-linked/projected as necessary, with the shared resolver authoritative for governed days. Supported channels/evidence/calculation/approver types come from the server capability catalog: unsupported mechanisms are rejected with a clear reason, never silently ignored. Business extension data (checkpoint definitions, thresholds, fields and approval steps) must not require new enums or code branches per configured item. No arbitrary executable expressions/scripts in policy data.

Policy workflow: create/edit draft → server validation → preview with representative employee/date/shift → required approval route → publish with effective date/time → read-only history and comparison → revert by publishing a new revision. `manage_policy_drafts` and `publish_policy` are distinct scoped capabilities, with a starter two-person approval; a user cannot change the current policy's publication route to bypass the approval governing that very change. Retention increases/decreases and financial-rule changes appear prominently in review.

Resolution order is deterministic: company base → department → team → employee → dated exception, within the actor's authorized scope. At each scope only one active matching revision is allowed; ambiguity rejects publication. Merge scalars by explicit override, replace arrays as a whole, and distinguish inherit from disable/empty. Store the ordered source revision IDs and a hash of the complete resolved policy. Disallow overrides that grant a capability the publisher does not hold or reduce mandatory isolation/financial review protections.

Drafts never affect runtime. Publication atomically advances the policy head and relevant guard epoch; scheduling/approval commands revalidate the effective published policy. Employee-facing previews show the policy source, allowance and today's obligations. On first check-in the whole resolved policy and approval/financial/shared-policy versions are snapshotted; later edits, employee transfers and new checkpoint definitions affect future sessions only. Unstarted days and due events use effective revisions; started-day reminders retain the session's slots/settings. Security revocation and explicit service-incident controls are separate audited overrides.

All business restrictions exposed by attendance policy—including allowed weekdays, late/early windows, verification choices, permitted channels, remote eligibility, device counts, approvals and missing-action handling—are editable in that screen. No fixed 09:00/17:00 or checkpoint count is imposed by application code. Policy edits support expected-version conflicts, validation errors per field, RTL/desktop previews, offline draft state and audit history. Zero checkpoints creates no checkpoint reminders or violations; changed counts/hours/approval routes propagate from server data to forms, validation, workers and reports. Dashboard cannot disable authentication, company isolation, server time, canonical identity, atomic mode lock, audit, or required financial approval, nor silently rewrite history. Those are integrity guarantees, not business policies.

## 6. Acceptance scenarios

| ID | Scenario and expected result |
|---|---|
| AC-01 | Approved weekday, active qualified computer, 08:45 Cairo: exactly one attendance row and one linked remote session commit; no GPS requested. |
| AC-02 | Wrong weekday, exception exceeding the configured allowance, holiday, rest day, real leave, inactive account, wrong company: reject without attendance mutation. |
| AC-03 | Web and office check-in race: exactly one mode wins; loser sees the winning receipt; no orphan session. |
| AC-04 | Response lost after commit: same operation returns original result; changed payload conflicts; replayed assertion cannot create another action. |
| AC-05 | Client clock/date/lateMinutes/salary fields forged: authoritative date/time/financial proposal remain server-derived. |
| AC-06 | Legacy `remote`/`wfh` authorization on a prospective pilot date: attendance allowed, no on-leave exemption, no probation conversion, no leave balance mutation. Historical rows are byte-for-byte unchanged. |
| AC-07 | Remote lock exists: mobile/automatic checkout or replacement credential cannot switch it; mobile device binding remains intact. |
| AC-08 | Missed update, empty summary, or offline draft: checkout remains available; review state follows the snapshot; default no financial proposal, configured proposals remain pending review only. |
| AC-09 | Credential revoked or runtime incident mid-day: explicit recovery and financial hold; HR correction preserves original evidence; finalized payroll remains unchanged. |
| AC-10 | Flag stops new sessions after check-in: current receipt/read/verified checkout works; next remote check-in fails; no legacy bypass. |
| AC-11 | Two workers scan same due slot: one logical notification; exception/completion before dispatch suppresses stale escalation. More than 1000 due rows drain across ticks without skipping pages. |
| AC-12 | Manager/IT/cross-company forged requests: only allowed fields and relationships are visible; view-only Super Admin cannot perform ordinary decisions. |
| AC-13 | Cairo DST and another configured timezone, overnight shift, midnight, configured week boundary, days 25/26 and year rollover: server-resolved shift date/week/cycle with no fixed UTC offset. |
| AC-14 | Arabic RTL and desktop/mobile: eligibility, unsupported computer, loading, empty, offline, pending, conflict, recovery, and checkout-not-required are distinguishable. |
| AC-15 | Real leave approved concurrently with check-in: authorization guard serialization prevents a remote check-in under a stale leave decision; HR resolves a day already started through correction. |
| AC-16 | From **سياسة الدوام** (`/hr/attendance-policy`), dashboard changes allowance from 1 to 2, adds/removes weekdays and sets 0/2/5 checkpoints: forms, server validation, notifications and reports agree without code changes. |
| AC-17 | Publish new hours, approval route, device count or financial-review threshold with a future effective date: preview identifies affected employees; existing sessions keep their complete snapshot. |
| AC-18 | Department/team/employee overrides, inherit versus disable, conflicting revisions and concurrent publishers: deterministic result or explicit conflict; no partial publication or scope escalation. |
| AC-19 | Invalid overnight offsets, unsupported proof profile, missing approver, unsafe threshold or self-bypassing publication route: field-level validation rejects publication; last good revision remains active. |
| AC-20 | Revert, identity transfer and policy changes while reminders are queued: new revision applies only where effective; started-day evidence and finalized payroll remain unchanged. |
| AC-21 | Shared hours/grace/restrictions changed in **سياسة الدوام** apply consistently to office and remote paths that inherit them; explicit remote overrides are labelled and can reset to inherit. One publication versions both; no separate remote-policy navigation entry exists. |
| AC-22 | Existing attendance settings, approval/checkout readers and unrelated security/chat/advance sections remain compatible; an older settings save cannot erase remote configuration or bypass versioned publication. |

## 7. Implementation and approval gates

The owner approved this spec, [plan](plan.md), [tasks](tasks.md) and local implementation on 2026-10-26, and subsequently chose HR-approved registration plus passkey for personal computers. Browser/credential qualification and production activation gates remain open. Each implementation increment requires red/green behavior tests and an independent reviewable deliverable. Before production pilot: approve retention, company resolver, enrollment qualification evidence, published dashboard policy and its checkout/retention/device profile, scheduler ownership, security rules, and rollback runbook. No arbitrary deadline substitutes for these gates.
