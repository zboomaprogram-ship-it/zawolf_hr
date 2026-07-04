import 'package:flutter/material.dart';
import '../theme/theme.dart';

class WolfCard extends StatelessWidget {
  final Widget child;
  final bool hasGlow;
  final bool hasBorderGlow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const WolfCard({
    super.key,
    required this.child,
    this.hasGlow = false,
    this.hasBorderGlow = false,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasBorderGlow
              ? ZaWolfColors.primaryCyan.withValues(alpha: 0.3)
              : ZaWolfColors.surface02,
          width: hasBorderGlow ? 1.5 : 1.0,
        ),
        boxShadow: hasGlow ? [ZaWolfColors.wolfGlow] : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: card,
        ),
      );
    }

    return card;
  }
}
