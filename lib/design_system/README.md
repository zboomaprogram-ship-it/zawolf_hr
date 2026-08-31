# ZaWolf Design System

Single source of visual truth for the UI redesign program. Specs:
`specs/ui_redesign/01_design_system_spec.md` (owner-approved).

## Layout

- `tokens.dart` — spacing, radii, motion, type sizes, `DsStatus` → color mapping
- `components/` — reusable widgets (StatusPill, StatCard, FilterBar, …)
- `design_system_gallery.dart` — debug-only gallery rendering everything

## Rules

- New screens import from here; never hardcode `Color(0x…)` or inline
  TextStyle sizes outside this folder.
- Colors live in `lib/theme/theme.dart` (`ZaWolfColors` + semantic aliases);
  tokens reference them, they do not duplicate values.
- Transitions: 150–250ms only (`DsMotion`). Lists load with skeletons.
- Touch targets ≥44px. RTL is default; no hardcoded left/right.
- Status colors come only from `dsStatusColor(DsStatus)` — never ad-hoc.

## Components

| Component | File |
|---|---|
| AppLogo | `components/app_logo.dart` |
| DsAvatar | `components/avatar.dart` |
| DsBadge | `components/badge.dart` |
| ConfirmationSheet | `components/confirmation_sheet.dart` |
| AppDataTable / AppListTile | `components/data_presentations.dart` |
| EmptyState / ErrorState | `components/feedback_states.dart` |
| FilterBar / FilterChipItem | `components/filter_bar.dart` |
| PriorityStrip / PriorityItem | `components/priority_strip.dart` |
| SectionHeader | `components/section_header.dart` |
| SkeletonList / SkeletonCard | `components/skeletons.dart` |
| StatCard | `components/stat_card.dart` |
| StatusPill | `components/status_pill.dart` |

Upgraded in place: `lib/components/wolf_button.dart` (variants + disabled
opacity), `wolf_card.dart` (radius 12 recipe + cursor), `wolf_input_field.dart`
(helper/error slots).

Pending: owner must drop the approved logo at
`assets/images/wolf_logo_gradient.png`; until then `AppLogo` falls back to the
legacy artwork (splash stays untouched regardless).
