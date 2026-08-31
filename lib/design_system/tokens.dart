import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Design tokens for the ZaWolf HR design system.
///
/// Single source of truth for spacing, radii, and motion. Color values stay
/// in [ZaWolfColors] (lib/theme/theme.dart); this file only references them
/// semantically. See specs/ui_redesign/01_design_system_spec.md.

class DsSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class DsRadius {
  static const double input = 8;
  static const double card = 12;
  static const double sheet = 16;
  static const BorderRadius inputBorder = BorderRadius.all(
    Radius.circular(input),
  );
  static const BorderRadius cardBorder = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius sheetBorder = BorderRadius.all(
    Radius.circular(sheet),
  );
  static const BorderRadius pillBorder = BorderRadius.all(
    Radius.circular(999),
  );
}

class DsMotion {
  /// Fast micro-interactions (hover, chips, icon color).
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions (cards, sheets, nav state).
  static const Duration standard = Duration(milliseconds: 200);

  /// Larger surfaces (bottom sheets, page-level reveals). Never exceed this.
  static const Duration slow = Duration(milliseconds: 250);

  static const Curve curve = Curves.easeOutCubic;
}

/// Typography scale. Fonts are applied through ThemeData; these tokens define
/// sizes/weights so widgets never pick arbitrary values.
class DsType {
  static const double display = 28;
  static const double h1 = 22;
  static const double h2 = 18;
  static const double body = 15;
  static const double secondary = 14;
  static const double caption = 12;
}

/// Semantic status vocabulary shared by StatusPill, dashboards, and lists.
enum DsStatus {
  present,
  late,
  absent,
  pendingAction,
  approved,
  rejected,
  neutral,
}

/// Maps a semantic status to its color token from [ZaWolfColors].
Color dsStatusColor(DsStatus status) {
  switch (status) {
    case DsStatus.present:
    case DsStatus.approved:
      return ZaWolfColors.wolfGreen;
    case DsStatus.late:
      return ZaWolfColors.warning;
    case DsStatus.absent:
    case DsStatus.rejected:
      return ZaWolfColors.error;
    case DsStatus.pendingAction:
      return ZaWolfColors.primaryCyan;
    case DsStatus.neutral:
      return ZaWolfColors.textSecondary;
  }
}
