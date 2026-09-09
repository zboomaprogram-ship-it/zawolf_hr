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

  final Color? borderColor;
  final double? borderWidth;
  final Color? shadowColor;
  final List<BoxShadow>? customShadows;

  const WolfCard({
    super.key,
    required this.child,
    this.hasGlow = false,
    this.hasBorderGlow = false,
    this.borderColor,
    this.borderWidth,
    this.shadowColor,
    this.customShadows,
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
        color: ZaWolfColors.surface01.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ??
              (hasBorderGlow
                  ? ZaWolfColors.primaryCyan.withValues(alpha: 0.38)
                  : ZaWolfColors.surface03),
          width: borderWidth ?? (hasBorderGlow || borderColor != null ? 1.2 : 1.0),
        ),
        boxShadow: customShadows ??
            (shadowColor != null
                ? [
                    BoxShadow(
                      color: shadowColor!.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : (hasGlow
                    ? [ZaWolfColors.wolfGlow]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ])),
      ),
      child: child,
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: card,
          ),
        ),
      );
    }

    return card;
  }
}
