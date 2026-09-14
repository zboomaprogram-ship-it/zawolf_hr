import 'package:flutter/material.dart';
import '../theme/theme.dart';

enum WolfButtonVariant {
  primary,
  teal,
  purple,
  danger,
  outline,
  secondary,
  ghost,
}

class WolfButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? text;
  final String? secondaryText; // For bilingual subtitles
  final WolfButtonVariant variant;
  final double height;
  final double? width;
  final bool loading;
  final Gradient? gradient;
  final Color? glowColor;
  final Color? textColor;
  final BorderRadiusGeometry? borderRadius;

  const WolfButton({
    super.key,
    required this.onPressed,
    this.child = const SizedBox.shrink(),
    this.text,
    this.secondaryText,
    this.variant = WolfButtonVariant.primary,
    this.height = 56,
    this.width,
    this.loading = false,
    this.gradient,
    this.glowColor,
    this.textColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine decoration
    BoxDecoration decoration;
    TextStyle textStyle = theme.textTheme.titleMedium!.copyWith(
      color: ZaWolfColors.textPrimary,
      fontWeight: FontWeight.bold,
      shadows: const [
        Shadow(
          color: Color(0x99000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ],
    );
    TextStyle? subStyle = theme.textTheme.bodySmall!.copyWith(
      color: ZaWolfColors.textPrimary.withValues(alpha: 0.9),
      fontSize: 10,
      shadows: const [
        Shadow(
          color: Color(0x99000000),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    );

    final br = borderRadius ?? BorderRadius.circular(8);

    if (gradient != null) {
      final effectiveGlow = glowColor ?? ZaWolfColors.primaryCyan;
      decoration = BoxDecoration(
        gradient: gradient,
        borderRadius: br,
        boxShadow: loading
            ? null
            : [
                BoxShadow(
                  color: effectiveGlow.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      );
      final effectiveTextColor = textColor ??
          (effectiveGlow.computeLuminance() > 0.45
              ? const Color(0xFF0F172A)
              : Colors.white);
      final hasDarkShadow = effectiveTextColor == Colors.white;
      textStyle = textStyle.copyWith(
        color: effectiveTextColor,
        shadows: hasDarkShadow
            ? const [
                Shadow(
                  color: Color(0x99000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ]
            : const [],
      );
      subStyle = subStyle.copyWith(
        color: effectiveTextColor.withValues(alpha: 0.75),
        shadows: hasDarkShadow
            ? const [
                Shadow(
                  color: Color(0x99000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ]
            : const [],
      );
    } else {
      switch (variant) {
        case WolfButtonVariant.primary:
          decoration = BoxDecoration(
            gradient: ZaWolfColors.primaryGradient,
            borderRadius: BorderRadius.circular(8),
            boxShadow: loading
                ? null
                : [
                    BoxShadow(
                      color: ZaWolfColors.primaryCyan.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          );
          break;
        case WolfButtonVariant.teal:
          decoration = BoxDecoration(
            gradient: ZaWolfColors.permissionGradient,
            borderRadius: BorderRadius.circular(8),
            boxShadow: loading
                ? null
                : [
                    BoxShadow(
                      color: ZaWolfColors.permissionTeal.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          );
          break;
        case WolfButtonVariant.purple:
          decoration = BoxDecoration(
            gradient: ZaWolfColors.dayoffGradient,
            borderRadius: BorderRadius.circular(8),
            boxShadow: loading
                ? null
                : [
                    BoxShadow(
                      color: ZaWolfColors.dayoffPurple.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          );
          break;
        case WolfButtonVariant.danger:
          decoration = BoxDecoration(
            color: ZaWolfColors.error,
            borderRadius: BorderRadius.circular(8),
            boxShadow: loading
                ? null
                : [
                    BoxShadow(
                      color: ZaWolfColors.error.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          );
          break;
        case WolfButtonVariant.outline:
          decoration = BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZaWolfColors.surface03, width: 1.2),
          );
          textStyle = textStyle.copyWith(color: ZaWolfColors.textSecondary);
          subStyle = subStyle.copyWith(color: ZaWolfColors.textMuted);
          break;
        case WolfButtonVariant.secondary:
          decoration = BoxDecoration(
            color: ZaWolfColors.surface02,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZaWolfColors.surface03, width: 1),
          );
          textStyle = textStyle.copyWith(color: ZaWolfColors.textPrimary);
          subStyle = subStyle.copyWith(color: ZaWolfColors.textMuted);
          break;
        case WolfButtonVariant.ghost:
          decoration = const BoxDecoration(color: Colors.transparent);
          textStyle =
              textStyle.copyWith(color: ZaWolfColors.primaryCyan);
          subStyle = subStyle.copyWith(
            color: ZaWolfColors.primaryCyan.withValues(alpha: 0.7),
          );
          break;
      }
      if (borderRadius != null) {
        decoration = decoration.copyWith(borderRadius: borderRadius);
      }
    }

    final enabled = !loading && onPressed != null;

    return Opacity(
      opacity: enabled || loading ? 1.0 : 0.5,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : onPressed,
            borderRadius: br is BorderRadius ? br : BorderRadius.circular(8),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: textStyle.color ?? ZaWolfColors.textPrimary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : (text != null
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(text!, style: textStyle),
                                if (secondaryText != null &&
                                    secondaryText!.isNotEmpty)
                                  Text(
                                    secondaryText!,
                                    style: subStyle.copyWith(
                                      color: subStyle.color?.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : child),
            ),
          ),
        ),
      ),
    );
  }
}
