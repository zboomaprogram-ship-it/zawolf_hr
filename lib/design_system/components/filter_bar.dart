import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../tokens.dart';

/// A single selectable filter chip for [FilterBar].
class FilterChipItem {
  const FilterChipItem({
    required this.id,
    required this.label,
    this.count,
  });

  final String id;
  final String label;
  final int? count;
}

/// Horizontal row of filter chips. Selected chip = filled accent pill.
/// Scrolls horizontally when chips exceed available width.
class FilterBar extends StatelessWidget {
  const FilterBar({
    required this.chips,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<FilterChipItem> chips;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.sm),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final selected = chip.id == selectedId;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(chip.id),
              borderRadius: DsRadius.pillBorder,
              child: AnimatedContainer(
                duration: DsMotion.fast,
                curve: DsMotion.curve,
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.lg,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? ZaWolfColors.primaryCyan.withValues(alpha: 0.16)
                      : ZaWolfColors.surface02,
                  borderRadius: DsRadius.pillBorder,
                  border: Border.all(
                    color: selected
                        ? ZaWolfColors.primaryCyan
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chip.label,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium!
                          .copyWith(
                            color: selected
                                ? ZaWolfColors.primaryCyan
                                : ZaWolfColors.textSecondary,
                          ),
                    ),
                    if (chip.count != null && chip.count! > 0) ...[
                      const SizedBox(width: DsSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.sm,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? ZaWolfColors.primaryCyan
                              : ZaWolfColors.surface03,
                          borderRadius: DsRadius.pillBorder,
                        ),
                        child: Text(
                          '${chip.count}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall!
                              .copyWith(
                                color: selected
                                    ? ZaWolfColors.background
                                    : ZaWolfColors.textSecondary,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
