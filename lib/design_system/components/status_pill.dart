import 'package:flutter/material.dart';

import '../tokens.dart';

/// Status chip mapping a semantic [DsStatus] to its color automatically.
/// Not color-only: pairs the dot with the Arabic label.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.status,
    required this.label,
    this.compact = false,
    super.key,
  });

  final DsStatus status;
  final String label;

  /// Compact variant for dense table rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = dsStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? DsSpacing.sm : DsSpacing.md,
        vertical: compact ? DsSpacing.xs : DsSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: DsRadius.pillBorder,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: color,
                  fontSize: compact ? DsType.caption : null,
                ),
          ),
        ],
      ),
    );
  }
}
