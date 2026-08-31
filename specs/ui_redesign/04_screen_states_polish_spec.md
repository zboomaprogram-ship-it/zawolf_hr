# Phase 3 — Screen States and Interaction Polish

**Status:** Draft for owner review.
**Depends on:** Phase 0 (components); applies to screens migrated in Phases
1–2 first, then remaining screens in Phase 4 order.

## Purpose

Make loading, empty, error, offline, pending-sync, RTL, and touch ergonomics
uniform acceptance surfaces across the app instead of per-screen improvisation.

## State contract (every data-backed list/detail surface)

| State | Required rendering |
|---|---|
| Loading | `SkeletonList`/`SkeletonCard` matching final layout shape; no spinners for lists |
| Empty | `EmptyState` with Arabic copy explaining what will appear here |
| Error | `ErrorState` with retry; error text never exposes provider/Firebase internals |
| Offline | connectivity-aware banner or `ErrorState` offline copy; retry re-checks connectivity |
| Pending sync / conflict | `StatusPill` on affected rows; no silent data loss; consistent with existing sync feature behavior |

## Interaction rules

- Touch targets >= 44x44 logical px.
- Buttons disable during their own async operation (`WolfButton` loading).
- Destructive actions route through `ConfirmationSheet`.
- Transitions 150–250 ms, transform/opacity only; respect platform reduced-
  motion where available.
- Filter chips via `FilterBar`; selected state uses accent color + filled pill.

## RTL and localization rules

- All new strings Arabic-first; English labels kept only in nav items that
  already carry both.
- Icons mirror with layout direction; numeric values remain LTR.
- No truncated Arabic titles at mobile width; long names ellipsize after one
  line with tooltip on web.

## Web-specific rules

- Tables: sticky header, horizontal scroll allowed inside table container
  only — never page-level horizontal scroll.
- Hover feedback via color/border change without layout shift.
- Focus-visible rings on all interactive elements for keyboard navigation.

## Requirements

- The state contract is enforced by a lint/guard extension where feasible;
  otherwise by checklist in review.
- Existing `attendance_checkin`, `request_visibility`, `company_workspace`,
  and `checkout_policy` behaviors are untouched; this phase changes
  presentation wrappers only.

## Acceptance criteria

- [ ] Every screen migrated so far renders all five states correctly,
      verified per screen in phase report.
- [ ] Offline airplane-mode pass completed on mobile build.
- [ ] RTL pass completed; desktop-web pass at 1024/1440 completed.
- [ ] Required checks pass.
