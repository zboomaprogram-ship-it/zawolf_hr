# Research: Attendance and Requests Stability

## 2026-08-20 baseline findings

- Automatic attendance is explicitly opt-in and native region monitoring is
  restored after app restart on both Android and iOS.
- Android and iOS currently write an `autoAttendanceSignals` document directly
  from the background event. The Node worker is the policy authority and uses
  the canonical `${userId}_${CairoDate}` attendance document identity.
- The current worker still receives `exit` signals and contains a check-out
  branch when the separate check-out policy is enabled. Phase 004 must make the
  automatic path check-in-only before it becomes the reliable employee path.
- An employee-facing deduction has existing source, policy label, fraction,
  amount, currency, and review-status fields for attendance and permissions.
  Manual deductions may only have the recorded fraction/reason; their missing
  amount must remain explicitly unavailable rather than being calculated in UI.
- The current HR/manager request screen is one 4,000+ line stateful screen
  (`requests_mgmt.dart`) with multiple independently nested `StreamBuilder`s.
  Pending items are bounded by status queries, but confirmed deductions are
  assembled from three separate live streams (`attendance`, `permissions`, and
  `manual_deductions`). This explains partial/slow tabs when one source is
  delayed or unavailable and is the first target for the bounded visibility
  adapter in Phase 004.
- The old request search is local only after each tab has loaded. It must stay
  local to a bounded loaded page, but every tab needs an explicit error, empty,
  and retry state instead of relying on a nested listener to settle.

## Decision 1: Send automatic events through the reliable check-in boundary

**Decision**: Automatic location events use the same deterministic check-in
action, receipt, and status contract as manual check-in; they never write
attendance directly from the device.

**Rationale**: `AutomaticAttendanceService` configures native geofences and the
existing reliability feature already provides safe Arabic outcomes, bounded
retry, account-scoped pending work, and deterministic daily identity.

**Alternatives considered**: Direct native Firestore writes were rejected
because they can bypass policy/device/idempotency checks. Unlimited background
retries were rejected for quota, battery, and uncertain-outcome risk.

## Decision 2: Keep automatic attendance opt-in and manually recoverable

**Decision**: Automatic attendance is an opt-in attempt only when the OS
delivers an eligible event. Manual check-in always remains available.

**Rationale**: iOS/Android may delay or stop background events, so the product
cannot promise closed-app attendance for every device state.

## Decision 3: Use a bounded request visibility read model

**Decision**: Request tabs consume a role-, status-, and date-bounded view
model with stable stream ownership plus explicit loaded/empty/retry states.
Legacy request and deduction fields are normalized for display only.

**Rationale**: `RequestsManagementScreen` currently owns many collection and
derived streams; tab/search changes can stall and post-schema historic records
can be filtered out.

**Alternatives considered**: Reading full collections per tab was rejected for
read cost and duplicate streams. Rewriting historic documents was rejected as a
payroll-adjacent migration.

## Decision 4: Place approval and device reset authority at the gateway

**Decision**: Client requests authenticated role-checked gateway operations for
approval decisions and device reset. The authority validates revision/stage,
records audit information, and returns semantic receipts.

**Rationale**: Valid HR actions can fail through client Firestore rule/session
state. Server authority allows atomic authorization and concurrency checks.

## Decision 5: Calculate productivity from an explicit input snapshot

**Decision**: Productivity/KPI reads use an employee/team-and-period-bounded
input snapshot with complete/partial/unavailable availability state.

**Rationale**: Missing KPI/source data must not silently display as zero, and
rebuild-time broad month reads increase inconsistency and quota cost.

## Decision 6: Retain map picker with safe coordinate fallback

**Decision**: Use the existing full-screen picker where available; on map load
failure retain existing coordinates and offer an authorized reviewed-coordinate
fallback.

## Decision 7: Guard back actions at nested route boundaries

**Decision**: Nested attendance/request routes first pop in-app; dirty/pending
states ask before discard and active synchronization is not interrupted.
