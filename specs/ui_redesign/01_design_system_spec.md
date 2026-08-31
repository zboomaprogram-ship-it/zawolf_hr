# Phase 0 — Design System Foundation

**Status:** Draft for owner review.
**Depends on:** none.

## Purpose

Create `lib/design_system/` as the single source of visual truth so that all
51 screens stop re-implementing cards, stats, pills, and states inline. This
phase adds new code only; existing screens keep working unchanged until later
phases adopt the components.

## Scope

### 1. Tokens (`lib/design_system/tokens.dart`)

Spacing scale: 4, 8, 12, 16, 24, 32 (`DsSpacing`).

Radius scale: inputs 8, cards 12, sheets/modals 16, pills full (`DsRadius`).

Typography scale (all IBM Plex Sans Arabic, wired through `ThemeData`):

| Token | Size / weight | Use |
|---|---|---|
| display | 28 / w700 | Dashboard greeting, hero numbers |
| h1 | 22 / w700 | Screen titles |
| h2 | 18 / w600 | Section headers |
| body | 15 / w400 | Primary text |
| secondary | 14 / w400 | List subtitles |
| caption | 12 / w500 | Timestamps, labels |

Semantic color aliases added beside `ZaWolfColors` (palette values do not
change): `successSoft`, `warningSoft`, `errorSoft`, `info`, `surfaceElevated`,
`disabled`, `onDisabled`. Status-to-color mapping is centralized:

- present/approved → wolfGreen
- late/pending-review → warning
- absent/rejected → error
- pending action → primaryCyan

Motion contract: transitions 150–250 ms; transform/opacity only; lists use
skeleton placeholders instead of spinners.

### 2. Component library (`lib/design_system/components/`)

Each component has one implementation with mobile/web behavior built in:

1. `WolfButton` — extend in place: variants primary/secondary/destructive/
   ghost; heights 48 (touch) / 40 (pointer); built-in loading and disabled
   states.
2. `WolfCard` — standardize recipe: radius 12, bg surface01, border
   surface03 1px, padding 16; optional tap ripple + web hover feedback without
   layout shift.
3. `WolfInputField` — add leading icon slot, error text slot, helper text,
   consistent focused-border treatment from tokens.
4. `StatCard(icon, value, label, {trend, onTap})` — replaces duplicated
   `_buildCountCard` / `_buildStatCard` implementations.
5. `StatusPill(status)` — maps status enum to semantic color automatically.
6. `SectionHeader(title, {actionLabel, onAction})`.
7. `EmptyState({icon, title, subtitle, cta})`.
8. `ErrorState({message, onRetry})` with offline-aware copy.
9. `SkeletonList` / `SkeletonCard`.
10. `AppDataTable` — PlutoGrid wrapper pre-themed; shown at width >= 980;
    pairs with `AppListTile` rendering the same row model as a card below it.
11. `FilterBar(chips)` — horizontal chip filters for requests/attendance/tasks.
12. `PriorityStrip(items)` — tappable alert banner for dashboards.
13. `Avatar(name, {size, roleColor})` — initials avatar.
14. `ConfirmationSheet` — standardized destructive-action bottom sheet.
15. `Badge(count)` — nav/notification count badge.

### 3. Theme wiring

`lib/theme/theme.dart` gains the typography scale and Material 3
`colorScheme` completion while keeping current brand colors. No screen changes
in this phase beyond what the theme update fixes implicitly.

## Requirements

- New code lives under `lib/design_system/`; presentation-safe only; no data,
  Firebase, or Dio imports.
- No hardcoded `Color(0x...)` inside design-system files except token
  definitions themselves.
- Every component renders correct Arabic RTL layout (mirroring, numerals stay
  LTR where appropriate).
- Touch targets >= 44x44 logical px for all interactive elements.
- Components are widget-testable without Firebase.

## Acceptance criteria

- [ ] `flutter analyze` clean; architecture guard and Firestore query guard pass.
- [ ] A gallery route (debug-only) renders every component in both RTL
      contexts and desktop-web widths (1024/1440) for owner inspection.
- [ ] Existing screens show no visual regression beyond intended theme-level
      typography/radius normalization.
- [ ] Component unit/widget tests cover status mapping, button states, and
      empty/error rendering.
