import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../tokens.dart';

/// Shimmer-free skeleton placeholder (opacity pulse). Used instead of
/// spinners for list/content loading per the state contract.
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({this.height = 72, super.key});

  final double height;

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
    // Reduced-motion contract: render a static placeholder when the user
    // disables animations (specs/ui_redesign/04_screen_states_polish_spec.md).
    if (MediaQuery.disableAnimationsOf(context)) {
      return Opacity(
        opacity: 0.5,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: ZaWolfColors.surface02,
            borderRadius: DsRadius.cardBorder,
          ),
        ),
      );
    }
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: ZaWolfColors.surface02,
          borderRadius: DsRadius.cardBorder,
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
