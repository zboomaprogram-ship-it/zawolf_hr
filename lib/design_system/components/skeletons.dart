import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../tokens.dart';

/// Shimmer-free skeleton placeholder (opacity pulse). Used instead of
/// spinners for list/content loading per the state contract.
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({this.height = 72, this.width, this.borderRadius, super.key});

  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: DsMotion.slow)
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: DsMotion.curve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? DsRadius.cardBorder;
    if (MediaQuery.disableAnimationsOf(context)) {
      return Opacity(
        opacity: 0.5,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: ZaWolfColors.surface02,
            borderRadius: radius,
          ),
        ),
      );
    }
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: ZaWolfColors.surface02,
          borderRadius: radius,
        ),
      ),
    );
  }
}

/// A vertical run of skeleton cards approximating final list shape.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.itemCount = 4, this.itemHeight = 72, super.key});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: DsSpacing.md),
          child: SkeletonCard(height: itemHeight),
        ),
      ),
    );
  }
}

/// Shape-accurate employee list row skeleton (Task C010).
/// Exact height: 72px to match EmployeeRow / ListTile.
class SkeletonEmployeeRow extends StatelessWidget {
  const SkeletonEmployeeRow({super.key});

  static const double height = 72.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.md,
      ),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: DsRadius.cardBorder,
        border: Border.all(color: ZaWolfColors.surface02),
      ),
      child: const Row(
        children: [
          SkeletonCard(
            height: 44,
            width: 44,
            borderRadius: BorderRadius.all(Radius.circular(22)),
          ),
          SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonCard(height: 14, width: 130),
                SizedBox(height: DsSpacing.xs),
                SkeletonCard(height: 10, width: 85),
              ],
            ),
          ),
          SizedBox(width: DsSpacing.md),
          SkeletonCard(
            height: 22,
            width: 48,
            borderRadius: BorderRadius.all(Radius.circular(11)),
          ),
        ],
      ),
    );
  }
}

/// Shape-accurate metric/stat card skeleton (Task C010).
/// Exact height: 110px to match DsStatCard / WolfCard.
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({this.width, super.key});

  final double? width;
  static const double height = 110.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: DsRadius.cardBorder,
        border: Border.all(color: ZaWolfColors.surface02),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonCard(height: 14, width: 90),
              SkeletonCard(
                height: 28,
                width: 28,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ],
          ),
          SkeletonCard(height: 24, width: 65),
        ],
      ),
    );
  }
}

/// Shape-accurate insight/notification card skeleton (Task C010).
/// Exact height: 136px to match DsInsightCard.
class SkeletonInsightCard extends StatelessWidget {
  const SkeletonInsightCard({super.key});

  static const double height = 136.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: DsRadius.cardBorder,
        border: Border.all(color: ZaWolfColors.surface02),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SkeletonCard(
                height: 24,
                width: 24,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              SizedBox(width: DsSpacing.sm),
              SkeletonCard(height: 16, width: 140),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonCard(height: 12, width: double.infinity),
              SizedBox(height: DsSpacing.xs),
              SkeletonCard(height: 12, width: 180),
            ],
          ),
          SkeletonCard(
            height: 20,
            width: 70,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ],
      ),
    );
  }
}

/// Shape-accurate attendance day row skeleton (Task C010).
/// Exact height: 68px to match AttendanceHistoryRow.
class SkeletonAttendanceRow extends StatelessWidget {
  const SkeletonAttendanceRow({super.key});

  static const double height = 68.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: DsRadius.cardBorder,
        border: Border.all(color: ZaWolfColors.surface02),
      ),
      child: const Row(
        children: [
          SkeletonCard(
            height: 40,
            width: 40,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonCard(height: 14, width: 110),
                SizedBox(height: DsSpacing.xs),
                SkeletonCard(height: 11, width: 75),
              ],
            ),
          ),
          SizedBox(width: DsSpacing.md),
          SkeletonCard(
            height: 22,
            width: 60,
            borderRadius: BorderRadius.all(Radius.circular(11)),
          ),
        ],
      ),
    );
  }
}

/// Shape-accurate table rows skeleton for desktop web tables (Task C010).
class SkeletonTableRows extends StatelessWidget {
  const SkeletonTableRows({
    this.rowCount = 5,
    this.columnCount = 4,
    super.key,
  });

  final int rowCount;
  final int columnCount;
  static const double rowHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        rowCount,
        (rowIndex) => Container(
          height: rowHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: ZaWolfColors.surface02),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
          child: Row(
            children: List.generate(
              columnCount,
              (colIndex) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
                  child: SkeletonCard(
                    height: 14,
                    width: colIndex == 0 ? 120 : 70,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shape-accurate detail pane skeleton for master-detail right pane (Task C010).
class SkeletonDetailPane extends StatelessWidget {
  const SkeletonDetailPane({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DsSpacing.xl),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: DsRadius.cardBorder,
        border: Border.all(color: ZaWolfColors.surface02),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonCard(height: 22, width: 180),
              SkeletonCard(
                height: 24,
                width: 80,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ],
          ),
          SizedBox(height: DsSpacing.xl),
          Row(
            children: [
              Expanded(child: SkeletonCard(height: 48)),
              SizedBox(width: DsSpacing.md),
              Expanded(child: SkeletonCard(height: 48)),
            ],
          ),
          SizedBox(height: DsSpacing.lg),
          SkeletonCard(height: 80),
          SizedBox(height: DsSpacing.xl),
          SkeletonCard(height: 16, width: 120),
          SizedBox(height: DsSpacing.md),
          SkeletonCard(height: 36),
          SizedBox(height: DsSpacing.sm),
          SkeletonCard(height: 36),
        ],
      ),
    );
  }
}
