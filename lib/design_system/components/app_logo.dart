import 'package:flutter/material.dart';

/// Single source for the app/web logo (specs/ui_redesign/06, R5).
///
/// Uses the approved gradient wolf head asset. Until the owner drops
/// `assets/images/wolf_logo_gradient.png` into the repo, it falls back to the
/// legacy geometric artwork so builds never break. The splash screen keeps
/// its own artwork and must not use this widget.
class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 32, super.key});

  /// Square edge length in logical pixels.
  final double size;

  static const String _preferredAsset =
      'assets/images/wolf_logo_gradient.png';
  static const String _fallbackAsset = 'assets/images/wolf_head_geometric.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        _preferredAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Image.asset(
          _fallbackAsset,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
