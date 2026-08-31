# Phase 007 Data Model

All server timestamps are authoritative; period calculations use `Africa/Cairo`.
No production schema/rule migration happens until a reviewed vertical slice is
ready.

| Entity | Core fields and rules |
|---|---|
| `DeductionExplanation` | `deductionKey`, `employeeUid`, `effectiveDate`, `cycleKey`, Arabic reason, source, fraction/amount (role scoped), state, opaque evidence refs, correction eligibility. Stable `(source,id)` identity prevents duplicates. |
| `AttendanceCorrectionDraft` | `dedupeKey=attendanceId/correction`, original/requested same-day check-in, reason, `cycleKey`, state `draft → pending_hr → approved/rejected/cancelled`. Same pending dedupe key returns existing request. |
| `WorkOutcome` | employee/owner IDs, legacy task/KPI links, Arabic title, target/progress/evidence/due date, versioned state. Existing task/KPI history remains. |
| `OperationalVisibilitySetting` | employee ID, included/hidden mode, required reason, changed/restored audit. Never changes active status, payroll or attendance data. |
| `SalesIdentityMapping` | normalized external identity, local employee UID/code, approved/unresolved/ambiguous/retired state and review audit; only one active approved mapping. |
| `SalesFilterSnapshot` | `filterVersion`, normalized filter, source snapshot ref and safe source health counts. Cards/charts/list/export share the version. |
| `Conversation` / `Message` | member UIDs, purpose/state; sender/body/time/state. Membership checked on every action. |
| `GovernedAttachment` | opaque Workspace resource ID, MIME/size/status, audit ref; statuses pending/uploaded/failed/deleted; never a raw Drive URL. |
| `DiagnosticEvent` | release/feature/operation/safeCode/fingerprint/platform/retryable/outcome/count/first-last timestamps; no secrets, salary, body, attachment, raw response, or trace. |
| `DeveloperToolsEntitlement` | employee UID, approved in-app tool scopes, issued/expired/revoked timestamps and actors, reason, operation ID. It never contains an attendance-security override. |
| `NotificationReadState` | canonical unread count, last bulk operation ID/time/version; idempotent bulk action. |
