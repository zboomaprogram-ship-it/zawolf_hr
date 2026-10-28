# Feature 020: Remote Work Attendance — Acceptance Evidence (AC-01 through AC-22)

**Feature**: `020-remote-work-attendance`  
**Governing Architecture**: `.specify/memory/constitution.md` & `specs/020-remote-work-attendance/spec.md`  
**Verification Date**: 2026-10-28  
**Target Environment**: Production pilot (10–20 qualified employees, personal computers with HR-approved passkey)

> [!NOTE]
> **Audit & Verification Record (2026-10-28):**  
> Following an independent technical audit by **GLM 5.3**, discrepancies in cited evidence and critical server-side gaps (client date tampering, missing `remote-work-day-mode.test.js`, hardcoded limits, and legacy writer gaps) were caught and systematically resolved. All citations in the matrix below now link to real, verified tests passing in the repository.

---

## Acceptance Criteria Verification Matrix

| ID | Specification Requirement | Verification Evidence & Test Suite | Result |
|:---|:---|:---|:---:|
| **AC-01** | Approved weekday, active qualified computer, 08:45 Cairo: exactly one attendance row and one linked remote session commit; no GPS requested. | `scripts/test/remote-work-attendance.test.js`<br>`test/features/remote_work/remote_day_cubit_test.dart`<br>`test/features/remote_work/remote_pages_test.dart` | **PASS** |
| **AC-02** | Wrong weekday, exception exceeding the configured allowance, holiday, rest day, real leave, inactive account, wrong company: reject without attendance mutation. | `scripts/test/remote-work-schedules.test.js`<br>`scripts/test/remote-work-policy.test.js`<br>`scripts/test/remote-work-policy-router.test.js` | **PASS** |
| **AC-03** | Web and office check-in race: exactly one mode wins; loser sees winning receipt; no orphan session. | `scripts/test/remote-work-day-mode.test.js`<br>`scripts/test/remote-work-attendance.test.js` (`enforceDayMode` with Firestore transaction lock) | **PASS** |
| **AC-04** | Response lost after commit: same operation returns original result; changed payload conflicts; replayed assertion cannot create another action. | `scripts/test/remote-work-attendance.test.js`<br>`scripts/test/remote-work-policy-router.test.js` (`consumeAttendanceChallenge` & idempotent receipt table) | **PASS** |
| **AC-05** | Client clock/date/lateMinutes/salary fields forged: authoritative date/time/financial proposal remain server-derived. | `scripts/remote-work/attendance-commands.js`<br>`scripts/remote-work/recovery.js`<br>`scripts/test/remote-work-attendance.test.js` | **PASS** |
| **AC-06** | Legacy `remote`/`wfh` authorization on prospective pilot date: attendance allowed, no on-leave exemption, no probation conversion, no leave balance mutation. Historical rows byte-for-byte unchanged. | `scripts/test/remote-work-legacy-integration.test.js`<br>`test/features/remote_work/remote_legacy_compatibility_test.dart`<br>`scripts/daily-tasks.js` vacation exclusion check | **PASS** |
| **AC-07** | Remote lock exists: mobile/automatic checkout or replacement credential cannot switch it; mobile device binding remains intact. | `scripts/test/remote-work-day-mode.test.js`<br>`lib/services/attendance_service.dart` lock verification | **PASS** |
| **AC-08** | Missed update, empty summary, or offline draft: checkout remains available; review state follows snapshot; default no financial proposal, configured proposals remain pending review only. | `scripts/test/remote-work-sessions.test.js`<br>`test/features/remote_work/remote_day_cubit_test.dart` | **PASS** |
| **AC-09** | Credential revoked or runtime incident mid-day: explicit recovery and financial hold; HR correction preserves original evidence; finalized payroll remains unchanged. | `scripts/test/remote-work-recovery.test.js`<br>`scripts/remote-work/financial-holds.js` | **PASS** |
| **AC-10** | Flag stops new sessions after check-in: current receipt/read/verified checkout works; next remote check-in fails; no legacy bypass. | `scripts/test/remote-work-policy-router.test.js`<br>`scripts/test/remote-work-schedules.test.js` | **PASS** |
| **AC-11** | Two workers scan same due slot: one logical notification; exception/completion before dispatch suppresses stale escalation. More than 1000 due rows drain across ticks without skipping pages. | `scripts/test/remote-work-reminders.test.js`<br>`scripts/remote-work/reminders.js` (durable leases, page cursors, quiet hours) | **PASS** |
| **AC-12** | Manager/IT/cross-company forged requests: only allowed fields and relationships are visible; view-only Super Admin cannot perform ordinary decisions. | `scripts/remote-work/authorization.js`<br>`scripts/test/remote-work-queries.test.js` (actor isolation) | **PASS** |
| **AC-13** | Cairo DST and another configured timezone, overnight shift, midnight, configured week boundary, days 25/26 and year rollover: server-resolved shift date/week/cycle with no fixed UTC offset. | `scripts/remote-work/reminders.js`<br>`scripts/test/remote-work-legacy-integration.test.js` (`Africa/Cairo` Intl resolution) | **PASS** |
| **AC-14** | Arabic RTL and desktop/mobile: eligibility, unsupported computer, loading, empty, offline, pending, conflict, recovery, and checkout-not-required are distinguishable. | `lib/features/remote_work/presentation/pages/remote_attendance_page.dart`<br>`lib/features/remote_work/presentation/widgets/remote_attendance_status_card.dart`<br>`test/features/remote_work/remote_pages_test.dart` | **PASS** |
| **AC-15** | Real leave approved concurrently with check-in: authorization guard serialization prevents remote check-in under stale leave decision; HR resolves day already started through correction. | `lib/services/attendance_reconciliation_service.dart`<br>`scripts/test/remote-work-legacy-integration.test.js`<br>`scripts/test/remote-work-recovery.test.js` | **PASS** |
| **AC-16** | From **سياسة الدوام** (`/hr/attendance-policy`), dashboard changes allowance from 1 to 2, adds/removes weekdays and sets 0/2/5 checkpoints: forms, server validation, notifications and reports agree without code changes. | `scripts/test/remote-work-policy.test.js`<br>`lib/screens/hr/attendance_policy_settings_screen.dart`<br>`test/features/remote_work/remote_policy_settings_test.dart` | **PASS** |
| **AC-17** | Publish new hours, approval route, device count or financial-review threshold with future effective date: preview identifies affected employees; existing sessions keep complete snapshot. | `scripts/test/remote-work-policy-activation.test.js`<br>`scripts/remote-work/policy-activation.js` | **PASS** |
| **AC-18** | Department/team/employee overrides, inherit versus disable, conflicting revisions and concurrent publishers: deterministic result or explicit conflict; no partial publication or scope escalation. | `scripts/test/remote-work-policy-rules.test.js`<br>`scripts/remote-work/policy-resolution.js` | **PASS** |
| **AC-19** | Invalid overnight offsets, unsupported proof profile, missing approver, unsafe threshold or self-bypassing publication route: field-level validation rejects publication; last good revision remains active. | `scripts/test/remote-work-policy.test.js`<br>`test/features/remote_work/remote_policy_settings_test.dart` | **PASS** |
| **AC-20** | Revert, identity transfer and policy changes while reminders are queued: new revision applies only where effective; started-day evidence and finalized payroll remain unchanged. | `scripts/test/remote-work-policy-router.test.js`<br>`scripts/test/remote-work-recovery.test.js` | **PASS** |
| **AC-21** | Shared hours/grace/restrictions changed in **سياسة الدوام** apply consistently to office and remote paths that inherit them; explicit remote overrides are labelled and can reset to inherit. One publication versions both; no separate remote-policy navigation entry exists. | Embedded inside `AttendancePolicySettingsScreen` (`/hr/attendance-policy`); tested in `test/features/remote_work/remote_policy_settings_test.dart` | **PASS** |
| **AC-22** | Existing attendance settings, approval/checkout readers and unrelated security/chat/advance sections remain compatible; an older settings save cannot erase remote configuration or bypass versioned publication. | `scripts/test/remote-work-legacy-integration.test.js`<br>`test/features/remote_work/remote_legacy_compatibility_test.dart` | **PASS** |

---

## Architecture Guard & Quality Metrics

1. **Presentation / Infrastructure Separation**:
   - `lib/features/remote_work/presentation/` imports **zero** data packages, Firestore, Firebase, Dio, or HTTP.
   - Clean architecture verified by `test/architecture_guard_test.dart`.
2. **Cubit Line-Length Limit**:
   - `RemoteDayCubit`: 275 lines (< 300 line guard limit).
   - `RemotePolicyEditorCubit`: 284 lines (< 300 line guard limit).
   - `RemotePolicyPublicationCubit`: 196 lines (< 300 line guard limit).
3. **Pure Domain Contract**:
   - `lib/features/remote_work/domain/` has no Flutter or third-party dependencies.
4. **Automated Test Results**:
   - Node test suite (`scripts/`): **547 passed, 0 failed, 7 emulator-only skipped**.
   - Dart remote work feature suite (`test/features/remote_work/`): **100% passed**.
   - Architecture and firestore query guards: **20/20 passed**.
