import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../tokens.dart';

/// Count badge for nav items and notification bells. Hidden at zero.
class DsBadge extends StatelessWidget {
  const DsBadge({required this.count, this.accent, super.key});

  final int count;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent ?? ZaWolfColors.error,
        borderRadius: DsRadius.pillBorder,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: ZaWolfColors.background,
              fontSize: 10,
            ),
      ),
    );
  }
}
