import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../tokens.dart';

/// Dashboard metric card: icon + value + label, optional trend chip, optional
/// tap navigation. Replaces duplicated _buildCountCard/_buildStatCard code.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.trendLabel,
    this.trendUp,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? trendLabel;
  final bool? trendUp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasTrend = trendLabel != null && trendUp != null;
    final up = trendUp ?? false;
    final card = Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: DsRadius.cardBorder,
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: ZaWolfColors.primaryCyan, size: 20),
              const Spacer(),
              if (hasTrend)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.sm,
                    vertical: DsSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: (up
                            ? ZaWolfColors.successSoft
                            : ZaWolfColors.errorSoft)
                        .withValues(alpha: 0.5),
                    borderRadius: DsRadius.pillBorder,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        up ? Icons.trending_up : Icons.trending_down,
                        size: DsType.caption,
                        color:
                            up ? ZaWolfColors.wolfGreen : ZaWolfColors.error,
                      ),
                      const SizedBox(width: DsSpacing.xs),
                      Text(
                        trendLabel!,
                        style:
                            Theme.of(context).textTheme.labelSmall!.copyWith(
                                  color: up
                                      ? ZaWolfColors.wolfGreen
                                      : ZaWolfColors.error,
                                ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: DsRadius.cardBorder,
      child: card,
    );
  }
}
