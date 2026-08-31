import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../tokens.dart';

/// Standard dashboard/list section header with optional trailing action
/// ("عرض الكل" pattern). RTL-safe via directional padding.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: DsSpacing.xs,
        right: DsSpacing.xs,
        bottom: DsSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: DsSpacing.xs,
            height: DsSpacing.lg,
            decoration: BoxDecoration(
              color: ZaWolfColors.primaryCyan,
              borderRadius: DsRadius.pillBorder,
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.sm,
                ),
              ),
              child: Text(
                actionLabel!,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: ZaWolfColors.primaryCyan,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
