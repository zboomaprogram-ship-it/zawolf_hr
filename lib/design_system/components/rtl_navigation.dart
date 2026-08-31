import 'package:flutter/material.dart';

/// Uses Flutter's directional icons instead of hard-coded left/right arrows.
/// It keeps Arabic RTL and browser/native back behavior aligned.
abstract final class RtlNavigation {
  static IconData backIcon(BuildContext context) {
    return Icons.arrow_forward;
  }

  static IconData forwardIcon(BuildContext context) {
    return Icons.arrow_back;
  }

  /// Chevron pointing toward the reading start edge (right in RTL).
  static IconData chevronStart(BuildContext context) {
    return Icons.chevron_right;
  }

  /// Chevron pointing toward the reading end edge (left in RTL); the
  /// standard list-row trailing affordance.
  static IconData chevronEnd(BuildContext context) {
    return Icons.chevron_left;
  }
}
