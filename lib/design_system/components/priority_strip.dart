import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'rtl_navigation.dart';
import '../bidi.dart';
import '../tokens.dart';

/// One tappable alert on the dashboard priority strip.
class PriorityItem {
  const PriorityItem({
    required this.label,
    required this.count,
    required this.icon,
    this.onTap,
    this.accent,
  });

  final String label;
  final int count;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? accent;

  bool get isVisible => count > 0 && onTap != null;
}

/// Dashboard alert banner rendering up to [maxItems] tappable alerts.
/// Hidden entirely when no item qualifies (zero counts or missing taps).
class PriorityStrip extends StatelessWidget {
  const PriorityStrip({required this.items, this.maxItems = 3, super.key});

  final List<PriorityItem> items;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final visible =
        items.where((item) => item.isVisible).take(maxItems).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      children: List.generate(visible.length, (index) {
        final item = visible[index];
        final color = item.accent ?? ZaWolfColors.primaryCyan;
        return Padding(
          padding: const EdgeInsets.only(bottom: DsSpacing.sm),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: item.onTap,
              borderRadius: DsRadius.cardBorder,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.lg,
                  vertical: DsSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: DsRadius.cardBorder,
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, color: color, size: 20),
                    const SizedBox(width: DsSpacing.md),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${dsBidi(item.count)} ',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium!.copyWith(color: color),
                            ),
                            TextSpan(
                              text: item.label,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Icon(
                      RtlNavigation.chevronStart(context),
                      color: ZaWolfColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
