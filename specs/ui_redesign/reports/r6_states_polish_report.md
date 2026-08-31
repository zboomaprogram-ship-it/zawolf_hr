# Phase 6–7 Report: RTL Audit, Branding, States & Polish

**Scope**: T040–T055 (`specs/ui_redesign/tasks.md`)
**Specs**: `06_priority_redesigns_spec.md`, `04_screen_states_polish_spec.md`

## Completed

| Task | Result |
|---|---|
| T040 | Employee home anatomy: always-present `MyStatusCard`, `EmployeePriorityStrip` (pending requests reused from history-section load + due-today tasks from existing `watchMyTasks` stream), quick actions reduced to radar + 3 tiles using `WolfCard` recipe, recent activity via `SectionHeader` |
| T041 | History console: status `FilterBar` chips (all/pending/approved/rejected), client-side filtering across all 7 type tabs, `SkeletonList` loading, `EmptyState` explaining post-submission flow, `StatusPill` rows; pinned FAB pre-existed |
| T043 | All approve/reject/cancel flows in `requests_mgmt` route through `ConfirmationSheet` (extended with optional required-reason input); per-row `_withRequestGuard` disables action buttons during submission; list stays mounted so filtered position is preserved |
| T044 | Sticky day captions via `SliverMainAxisGroup` + pinned `SliverPersistentHeader`; unread dot+weight, category icons, relative timestamps confirmed |
| T045 | Filter chips (all/unread/categories), swipe-to-read mobile, hover mark-read ≥980, idempotent batched mark-all confirmed |
| T046 | Read-budget documented in `r3_notifications_read_budget.md`; no new queries/listeners |
| T047 | All `Alignment.centerLeft/Right` in screens converted to `AlignmentDirectional.centerEnd/Start`; directional paddings converted (`EdgeInsetsDirectional.only(start/end)`); symmetric pairs left direction-neutral |
| T048 | `RtlNavigation.chevronStart/chevronEnd` added; trailing list chevrons converted in profile_settings, team_members, workspace browser, productivity ranking, department performance, attendance summary, domain hub, priority strip; web-shell back arrow uses `RtlNavigation.backIcon`. Spatial map controls (department map move-left/right) intentionally kept physical — they mirror a spatial canvas, not reading order |
| T049 | `lib/design_system/bidi.dart` (`dsBidi`) FSI/PDI isolation applied to strip counts, deduction amounts, notification relative times; unit-tested |
| T051 | Single-source logo: all six listed call sites already render `AppLogo`; `assets/images/wolf_logo_gradient.png` created and `web/favicon.png` updated. Note: gradient asset is currently a copy of the owner's geometric wolf art until the true cyan-gradient artwork is supplied |
| T052 | Five-state contract: skeletons/empty/error on employee requests history (including stream-error states), notifications, dashboards (Phase 5) |
| T054 | `SkeletonCard` renders static under `MediaQuery.disableAnimationsOf`; theme `focusColor` gives keyboard/web focus-visible rings |

## Recorded gaps (not silently added)

1. **T042 complete**: the web ≥980 table + side-detail-panel pattern is
   implemented via the shared `DsMasterDetailView`
   (`data_presentations.dart`) and applied to **all approval tabs**:
   leaves, permissions, advances, confirmed deductions, attendance
   corrections, and security reviews. Approval-flow parity is preserved by
   reusing the exact same detail card in both presentations.
2. **T055**: airplane-mode pass needs a physical/emulator build run; automated
   coverage exists for the offline queue service and pending-sync states, but
   the manual checklist result must be recorded by the owner.
3. **T057 retirement**: `wolf_head_geometric.png` still has two legitimate
   importers (splash per spec, AppLogo errorBuilder fallback); deletion waits
   for the release-cycle + owner sign-off rule.

## Pending-sync semantics (T053)

Request collections have no offline write queue (submission requires
connectivity by design), so there are no pending-sync request rows to style.
The only offline-capture surface is attendance, whose pending-sync state is
rendered through `CheckInStatusFeedback` on the dashboard, using the same
pending-action accent as `DsStatus.pendingAction` / `StatusPill`. No silent
loss: queued actions resurface on next launch via
`syncPendingOfflineAttendance`.
