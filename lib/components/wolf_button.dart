import 'package:flutter/material.dart';
import '../theme/theme.dart';

enum WolfButtonVariant { primary, teal, purple, danger, outline }

class WolfButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? text;
  final String? secondaryText; // For bilingual subtitles
  final WolfButtonVariant variant;
  final double height;
  final double? width;
  final bool loading;

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine decoration
    BoxDecoration decoration;
    TextStyle textStyle = theme.textTheme.titleMedium!.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    );
    TextStyle? subStyle = theme.textTheme.bodySmall!.copyWith(
      color: Colors.white.withValues(alpha: 0.8),
      fontSize: 10,
    );

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
    }

    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
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
    );
  }
}
